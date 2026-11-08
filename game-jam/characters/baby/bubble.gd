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
	area_entered.connect(_on_target_entered)
	area_exited.connect(_on_target_exited)
	body_entered.connect(_on_target_entered)
	body_exited.connect(_on_target_exited)
	global_position = get_global_mouse_position()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		using_mouse = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("bubble_press"):
		for target in hovered:
			if is_instance_valid(target):
				target.press()


func _process(delta: float) -> void:
	_move(delta)
	_update_time_control()
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
func _update_time_control() -> void:
	_update_rewind()

	var axis := Input.get_axis("bubble_slow_time", "bubble_speed_time")
	if absf(axis) < time_deadzone:
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
func _update_rewind() -> void:
	if not Input.is_action_pressed("bubble_rewind_time"):
		_stop_all_rewind()
		return
	for target in hovered:
		if is_instance_valid(target) and not rewinding.has(target) and target.can_rewind():
			if time_affected.has(target):
				time_affected.erase(target)
				target.reset_time()
			rewinding.append(target)
			target.start_rewind()
	# Lock onto the rewinding thing nearest the bubble.
	if not is_instance_valid(rewind_anchor) or not rewinding.has(rewind_anchor):
		rewind_anchor = null
		var best := INF
		for target in rewinding:
			if is_instance_valid(target):
				var d := global_position.distance_squared_to(target.global_position)
				if d < best:
					best = d
					rewind_anchor = target


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
