class_name KeypadDoctor
extends Node2D
## Room 1's door code. A doctor (a real, shielded Enemy) walks up to the keypad, types the code
## without noticing the Father, goes through the exit door and waits on the other side.
##
## The whole walk is a timeline (`t` seconds in). The baby can rewind him (hold Y with the bubble
## over him): `t` runs backwards, so he walks back the way he came, the door opens for him again
## and the code pops back into the keypad digit by digit in reverse - the order the keypad wants.
## Typing it forwards only flashes the keypad: the digits can only be read by rewinding him.
##
## Once a rewind has shown the whole code, letting go makes him notice the Father and attack
## (normal Enemy AI; his shield needs a sped-up scalpel). A rewind that stops early (Y let go, or
## the baby ran out of energy) just lets him carry on, so the code can't be lost. He also turns on the Father if a scalpel hits him or his shield, if the Father
## gets through the door, or when the door is opened with the code (turn_hostile()).

signal turned_hostile(doctor: Enemy)

enum State { WAITING, PLAYING, HOSTILE }

@export var code := "4719"
@export var keypad: Node2D
## The exit door (a sliding door: open() / close() / is_open).
@export var door: Node2D
@export var enemy_scene: PackedScene = preload("res://characters/enemy/enemy.tscn")
## Where he starts (x), looking at the baby pod.
@export var start_x := 708.0
## Where he stands to type.
@export var keypad_x := 728.0
## Where he waits on the far side of the door.
@export var beyond_x := 836.0
@export var walk_speed := 40.0
@export var key_interval := 0.75
## How much faster than real time the rewind plays. Fast enough that rewinding him all the way
## from behind the door (~6.8 s of walking) fits in one bar of baby energy.
@export var rewind_speed := 3.0
## How long the rewound code stays above the keypad after the rewind ends.
@export var digits_linger := 4.0
## He sets off once he's been on screen (or the Father is within start_distance) this long,
## so the player sees him do it.
@export var start_delay := 0.8
@export var start_distance := 260.0
## Hold him by the pod until begin() is called (the level does this when the intro ends).
@export var wait_for_begin := false

const DIGIT_TINT := Color(0.6, 1.2, 0.9, 1.0)
const SLOW_TINT := Color(0.7, 0.85, 1.25)
const FAST_TINT := Color(1.25, 0.95, 0.7)
const REWIND_TINT := Color(1.1, 0.75, 1.35)

var doctor: Enemy
var state := State.WAITING
## Seconds into his walk (0 = by the pod, _t_end = waiting past the door).
var t := 0.0
var rewinding := false
## Bubble slow / speed-up while he's walking (1 = normal).
var time_factor := 1.0

var _father: Node2D
var _handle: DoctorHandle
var _lcd: Texture2D
var _digits: Array[Sprite2D] = []    # the code as it's revealed by a rewind, left to right
var _floor_y := 0.0
var _seen_for := 0.0
var _begun := false
var _door_x := 0.0
# timeline
var _walk_in := Vector2.ZERO     # start, end time of the walk to the keypad
var _keys: Array[float] = []     # when each digit is pressed
var _t_ok := 0.0                 # keypad flashes green
var _t_door_open := 0.0
var _t_door_close := 0.0
var _walk_out := Vector2.ZERO    # start, end time of the walk through the door
var _t_end := 0.0


func _ready() -> void:
	_lcd = load("res://assets/gen/lcd_digits.png")
	_father = get_tree().get_first_node_in_group("father") as Node2D
	if _father == null:
		_father = get_tree().current_scene.find_child("Father", true, false) as Node2D
	_door_x = door.global_position.x
	var door_shape := door.get_node("Body/Shape") as CollisionShape2D
	_floor_y = (door_shape.global_transform * door_shape.shape.get_rect()).end.y
	_build_timeline()

	doctor = enemy_scene.instantiate() as Enemy
	doctor.name = "KeypadDoctor"
	doctor.scripted = true
	add_child(doctor)
	doctor.provoked.connect(turn_hostile)
	var body := doctor.get_node("CollisionShape2D") as CollisionShape2D
	var feet := (body.transform * body.shape.get_rect()).end.y
	doctor.global_position = Vector2(start_x, _floor_y - feet)

	# what the bubble grabs to rewind / slow him while he's walking
	_handle = DoctorHandle.new()
	_handle.cutscene = self
	_handle.position = Vector2(0, -12)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20, 48)
	cs.shape = r
	_handle.add_child(cs)
	doctor.add_child(_handle)
	_apply()


func _build_timeline() -> void:
	var at := 0.8                                     # turns from the pod to go
	_walk_in = Vector2(at, at + absf(keypad_x - start_x) / walk_speed)
	at = _walk_in.y + 0.5
	_keys.clear()
	for i in code.length():
		_keys.append(at + i * key_interval)
	_t_ok = _keys.back() + 0.8
	_t_door_open = _t_ok + 0.5
	var door_time: float = door.get("duration") if door.get("duration") != null else 0.5
	_walk_out.x = _t_door_open + door_time
	_walk_out.y = _walk_out.x + (beyond_x - keypad_x) / walk_speed
	# the door shuts once he's clear of it
	_t_door_close = _walk_out.x + (_door_x + 16.0 + 14.0 - keypad_x) / walk_speed
	_t_end = _walk_out.y


func _physics_process(delta: float) -> void:
	if state == State.HOSTILE or not is_instance_valid(doctor):
		return
	# He sees the Father once he's through the door.
	if is_instance_valid(_father) and _father.global_position.x > _door_x + 16.0:
		turn_hostile()
		return
	if state == State.WAITING:
		if wait_for_begin and not _begun:
			return
		if _on_screen() or (is_instance_valid(_father) and _father.global_position.distance_to(doctor.global_position) < start_distance):
			_seen_for += delta
		if _seen_for < start_delay:
			return
		state = State.PLAYING
	var rate := -rewind_speed if rewinding else time_factor
	var new_t := clampf(t + delta * rate, 0.0, _t_end)
	_fire_events(t, new_t)
	t = new_t
	doctor.animated_sprite.speed_scale = rate
	_apply()


## Lets him set off (see wait_for_begin); he still waits until he's been on screen start_delay.
func begin() -> void:
	_begun = true


func _on_screen() -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return true
	var view := get_viewport().get_visible_rect().size / cam.zoom
	var rect := Rect2(cam.get_screen_center_position() - view / 2.0, view)
	return rect.has_point(doctor.global_position)


## Places and animates him for the current `t`, and opens / shuts the door to match.
func _apply() -> void:
	var x := start_x
	var facing_right := false        # looking at the pod
	var walking := false
	if t >= _walk_out.x:
		x = lerpf(keypad_x, beyond_x, clampf(inverse_lerp(_walk_out.x, _walk_out.y, t), 0.0, 1.0))
		facing_right = true
		walking = t < _walk_out.y
	elif t >= _walk_in.x:
		x = lerpf(start_x, keypad_x, clampf(inverse_lerp(_walk_in.x, _walk_in.y, t), 0.0, 1.0))
		facing_right = keypad_x >= start_x
		walking = t < _walk_in.y
	doctor.global_position.x = x
	doctor.animated_sprite.flip_h = not facing_right
	var anim := &"walk" if walking else &"idle"
	if doctor.animated_sprite.animation != anim:
		doctor.animated_sprite.play(anim)

	var want_open := t >= _t_door_open and t < _t_door_close
	if want_open != bool(door.get("is_open")):
		door.call("open" if want_open else "close")


## Keypad presses and the green "accepted" flash happen as `t` passes them, either way.
func _fire_events(from: float, to: float) -> void:
	for i in _keys.size():
		var k := _keys[i]
		if from < k and k <= to:
			_flash(Color(1.8, 1.8, 1.4), 0.2)   # a key press; the digit stays hidden
		elif to < k and k <= from:
			_untype(code[i])
	if (from < _t_ok and _t_ok <= to) or (to < _t_ok and _t_ok <= from):
		_flash(Color(0.6, 1.6, 0.8), 0.4)


func _flash(color: Color, back: float) -> void:
	if keypad == null:
		return
	var k := create_tween()
	k.tween_property(keypad, "modulate", color, 0.05)
	k.tween_property(keypad, "modulate", Color.WHITE, back)


## Rewinding a key press: the digit drops into the next slot of a row above the keypad, so the
## row builds up as the code backwards (e.g. 9, 91, 917, 9174).
func _untype(ch: String) -> void:
	_flash(Color(1.8, 1.8, 1.4), 0.2)
	var slot := _digits.size()
	if slot >= code.length():
		return
	var d := Sprite2D.new()
	var a := AtlasTexture.new()
	a.atlas = _lcd
	a.region = Rect2(int(ch) * 10, 0, 10, 16)
	d.texture = a
	d.z_index = 30
	d.modulate = DIGIT_TINT
	add_child(d)
	_digits.append(d)
	var spot := keypad.global_position + Vector2(5 + (slot - (code.length() - 1) / 2.0) * 11.0, -24)
	d.global_position = spot - Vector2(0, 8)
	d.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(d, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(d, "global_position:y", spot.y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Fades the revealed row out (after `delay` seconds).
func _clear_digits(delay := 0.0) -> void:
	var row := _digits.duplicate()
	_digits.clear()
	for d in row:
		if not is_instance_valid(d):
			continue
		var tw := create_tween()
		tw.tween_property(d, "modulate:a", 0.0, 0.6).set_delay(delay)
		tw.tween_callback(d.queue_free)


# --- Time control while he's walking (called through DoctorHandle) ---
func can_rewind() -> bool:
	return state != State.HOSTILE and t > 0.0


func start_rewind() -> void:
	if not can_rewind():
		return
	rewinding = true
	_clear_digits()   # a fresh rewind shows the code from the start
	doctor.animated_sprite.modulate = REWIND_TINT


## The rewind is over. If it showed the whole code he notices the Father; otherwise he carries on.
func stop_rewind() -> void:
	if not rewinding:
		return
	rewinding = false
	_clear_digits(digits_linger)
	if t <= _keys[0]:
		turn_hostile()
	else:
		doctor.animated_sprite.modulate = Color.WHITE


func set_time_factor(factor: float) -> void:
	time_factor = factor
	if factor < 1.0:
		doctor.animated_sprite.modulate = Color.WHITE.lerp(SLOW_TINT, clampf((1.0 - factor) / 0.75, 0.0, 1.0))
	else:
		doctor.animated_sprite.modulate = Color.WHITE.lerp(FAST_TINT, clampf(factor - 1.0, 0.0, 1.0))


## He spots the Father and becomes a normal enemy (stays wherever he is).
func turn_hostile() -> void:
	if state == State.HOSTILE or not is_instance_valid(doctor):
		return
	state = State.HOSTILE
	if rewinding:   # interrupted mid-rewind (hit, or the Father got through the door)
		rewinding = false
		_clear_digits(digits_linger)
	if is_instance_valid(_handle):
		_handle.queue_free()
	doctor.animated_sprite.speed_scale = 1.0
	doctor.spawn_x = doctor.global_position.x
	doctor.velocity = Vector2.ZERO
	doctor.scripted = false
	if _father is Father:
		doctor.target = _father
	doctor.throw_timer = 0.7
	doctor.cooldown_timer = 0.7
	# startled: a quick red flash
	var s := create_tween()
	s.tween_property(doctor.animated_sprite, "modulate", Color(1.8, 0.5, 0.5), 0.08)
	s.tween_property(doctor.animated_sprite, "modulate", Color.WHITE, 0.25)
	# deferred: this can run inside a physics callback (a scalpel hitting him)
	turned_hostile.emit.call_deferred(doctor)


## What the bubble sees on the doctor while he's walking: forwards rewind / slow / speed to the cutscene.
class DoctorHandle extends Interactable:
	var cutscene: KeypadDoctor

	func _ready() -> void:
		add_to_group("interactable")
		monitoring = false

	func can_rewind() -> bool:
		return cutscene.can_rewind()

	func start_rewind() -> void:
		cutscene.start_rewind()

	func stop_rewind() -> void:
		cutscene.stop_rewind()

	func set_time_factor(factor: float) -> void:
		cutscene.set_time_factor(factor)

	func reset_time() -> void:
		cutscene.set_time_factor(1.0)
