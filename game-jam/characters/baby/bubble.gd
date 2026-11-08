class_name Bubble
extends Area2D
## The baby's bubble. Moved with the mouse or controller 2's left stick.
## - Right stick LEFT / RIGHT: slows down / speeds up every interactable in the bubble. It's
##   dynamic: the further the stick is pushed, the stronger the effect (set_time_factor()).
## - Press Y: press() on every interactable in the bubble (keypads, switches...).
## - Hold Y: rewinds every interactable in the bubble that can be rewound (the Father too).
## Interactables that leave the bubble, or are in it when the stick is let go, get reset_time().

enum TimeMode { NORMAL, SLOW, FAST }

## Top speed with the stick pushed all the way (px/s).
@export var stick_speed: float = 380.0
## How quickly it gets up to speed / stops (px/s^2).
@export var stick_acceleration: float = 2400.0
## >1 gives finer control with small stick movements, full speed at full tilt.
@export var stick_curve: float = 1.6
var _stick_velocity := Vector2.ZERO

var hovered: Array[Interactable] = []
var using_mouse: bool = true
var time_mode: TimeMode = TimeMode.NORMAL
## Interactables currently being slowed down / sped up by the bubble.
var time_affected: Array[Interactable] = []
## Interactables currently being rewound (Y held).
var rewinding: Array[Interactable] = []
## While Y is held the bubble locks onto this (the thing being rewound) and follows it.
var rewind_anchor: Interactable = null
## Y has to be held this long before rewinding starts (so a quick tap only presses keypads).
@export var rewind_hold_delay: float = 0.15
var _rewind_hold := 0.0
var _press_pending := false
var _rewound_this_hold := false

@export_group("Energy")
## The baby's energy (HUD "Baby energy" bar). Time powers use it up; it refills when they're not in use.
@export var max_energy: float = 100.0
## Per second while slowing / speeding something (scaled by how far the stick is pushed).
@export var time_drain: float = 22.0
## Per second while rewinding.
@export var rewind_drain: float = 30.0
@export var energy_regen: float = 18.0
## Seconds after the last use before it starts refilling.
@export var regen_delay: float = 0.6
## After running dry, powers stay off until it has refilled to this much.
@export var restart_energy: float = 25.0
signal energy_changed(energy: float, max_energy: float)
var energy: float = 100.0
var exhausted := false
var _regen_wait := 0.0

@export_group("Time control")
## Time factor with the stick pushed fully left (0.15 = 15% speed).
@export var min_time_factor: float = 0.15
## Time factor with the stick pushed fully right.
@export var max_time_factor: float = 2.5
## Stick movement below this is ignored.
@export var time_deadzone: float = 0.08
## Current factor (1 = normal), for UI / debugging.
var time_factor: float = 1.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	energy = max_energy
	area_entered.connect(_on_target_entered)
	area_exited.connect(_on_target_exited)
	body_entered.connect(_on_target_entered)
	body_exited.connect(_on_target_exited)
	global_position = get_global_mouse_position()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		using_mouse = true


func _unhandled_input(event: InputEvent) -> void:
	# Y is both "press" (tap) and "rewind" (hold), so press() fires when Y is let go,
	# and only if the hold didn't turn into a rewind.
	if event.is_action_pressed("bubble_press"):
		_press_pending = true
		_rewound_this_hold = false
	elif event.is_action_released("bubble_press") and _press_pending:
		_press_pending = false
		if not _rewound_this_hold:
			for target in hovered:
				if is_instance_valid(target):
					target.press()


func _process(delta: float) -> void:
	_move(delta)
	_update_time_control(delta)
	_update_energy(delta)
	animated_sprite.play("hover" if not hovered.is_empty() else "default")


func _move(delta: float) -> void:
	# Rewinding: stay locked onto what's being rewound until Y is let go.
	if is_instance_valid(rewind_anchor):
		global_position = rewind_anchor.global_position
		_stick_velocity = Vector2.ZERO
		return

	# Speed follows how far the stick is pushed (dynamic), with a little acceleration.
	var dir := Input.get_vector("bubble_left", "bubble_right", "bubble_up", "bubble_down")
	var target_velocity := Vector2.ZERO
	if dir != Vector2.ZERO:
		using_mouse = false
		target_velocity = dir.normalized() * stick_speed * pow(minf(dir.length(), 1.0), stick_curve)
	_stick_velocity = _stick_velocity.move_toward(target_velocity, stick_acceleration * delta)
	if not using_mouse:
		global_position += _stick_velocity * delta
	else:
		global_position = get_global_mouse_position()

	# Keep the bubble on screen (the camera follows the father)
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	global_position = global_position.clamp(view.position, view.end)


# --- Time control ---
func _update_time_control(delta: float) -> void:
	_update_rewind(delta)

	var axis := Input.get_axis("bubble_slow_time", "bubble_speed_time")
	if exhausted or absf(axis) < time_deadzone:
		if time_mode != TimeMode.NORMAL:
			_reset_all_time()
			time_mode = TimeMode.NORMAL
		time_factor = 1.0
		return

	# How far the stick is pushed sets how strong it is: full left = min_time_factor,
	# full right = max_time_factor, smoothly in between.
	var amount := inverse_lerp(time_deadzone, 1.0, absf(axis))
	if axis < 0.0:
		time_mode = TimeMode.SLOW
		time_factor = pow(min_time_factor, amount)
	else:
		time_mode = TimeMode.FAST
		time_factor = pow(max_time_factor, amount)

	for target in hovered:
		if not is_instance_valid(target) or rewinding.has(target):
			continue
		if not time_affected.has(target):
			time_affected.append(target)
		target.set_time_factor(time_factor)


# --- Rewind (hold Y) ---
func _update_rewind(delta: float) -> void:
	if exhausted or not Input.is_action_pressed("bubble_rewind_time"):
		_rewind_hold = 0.0
		_stop_all_rewind()
		return
	_rewind_hold += delta
	if _rewind_hold < rewind_hold_delay or not rewinding.is_empty():
		return   # already locked onto something: nothing else joins until Y is let go
	# Pick ONE thing to rewind: the nearest non-player thing in the bubble; the Father only if
	# he's the only rewindable thing there (so walking into the bubble doesn't rewind him too).
	var pick: Interactable = null
	var player: Interactable = null
	var best := INF
	for target in hovered:
		if not is_instance_valid(target) or not target.can_rewind():
			continue
		if target.has_meta(&"is_player"):
			player = target
			continue
		var d := global_position.distance_squared_to(target.global_position)
		if d < best:
			best = d
			pick = target
	if pick == null:
		pick = player
	if pick == null:
		return
	if time_affected.has(pick):
		time_affected.erase(pick)
		pick.reset_time()
	rewinding.append(pick)
	rewind_anchor = pick
	_rewound_this_hold = true
	pick.start_rewind()


func _stop_all_rewind() -> void:
	for target in rewinding:
		if is_instance_valid(target):
			target.stop_rewind()
	rewinding.clear()
	rewind_anchor = null


func _reset_all_time() -> void:
	for target in time_affected:
		if is_instance_valid(target):
			target.reset_time()
	time_affected.clear()


# --- Overlap tracking ---
func _on_target_entered(node: Node2D) -> void:
	var target := node as Interactable
	if target and not hovered.has(target):
		hovered.append(target)


func _on_target_exited(node: Node2D) -> void:
	var target := node as Interactable
	if target == null:
		return
	hovered.erase(target)
	# Still holding Y: keep rewinding it even if it slips out of the bubble.
	if rewinding.has(target) and not Input.is_action_pressed("bubble_rewind_time"):
		rewinding.erase(target)
		target.stop_rewind()
	# Left the bubble: it goes back to normal speed.
	if time_affected.has(target):
		time_affected.erase(target)
		target.reset_time()


# --- Energy ---
func _update_energy(delta: float) -> void:
	var before := energy
	var drain := 0.0
	if not rewinding.is_empty():
		drain = rewind_drain
		if is_instance_valid(rewind_anchor) and "rewind_drain_scale" in rewind_anchor:
			drain *= float(rewind_anchor.get("rewind_drain_scale"))
	elif not time_affected.is_empty():
		# stronger effects cost more: how far time is pushed from normal
		var strength := absf(log(time_factor)) / log(1.0 / min_time_factor) if time_factor < 1.0 \
			else log(time_factor) / log(max_time_factor)
		drain = time_drain * clampf(0.35 + 0.65 * strength, 0.35, 1.0)
	if drain > 0.0:
		energy = maxf(energy - drain * delta, 0.0)
		_regen_wait = regen_delay
		if energy <= 0.0 and not exhausted:
			exhausted = true
			_reset_all_time()
			_stop_all_rewind()
			time_mode = TimeMode.NORMAL
			time_factor = 1.0
	else:
		_regen_wait -= delta
		if _regen_wait <= 0.0:
			energy = minf(energy + energy_regen * delta, max_energy)
	if exhausted and energy >= restart_energy:
		exhausted = false
	modulate = Color(0.6, 0.6, 0.65, 0.7) if exhausted else Color.WHITE
	if energy != before:
		energy_changed.emit(energy, max_energy)


## Adds energy (the Father soothing the baby).
func add_energy(amount: float) -> void:
	var before := energy
	energy = minf(energy + amount, max_energy)
	if energy != before:
		energy_changed.emit(energy, max_energy)
