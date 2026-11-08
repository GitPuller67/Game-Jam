class_name Bubble
extends Area2D
## The baby's bubble. Moved with the mouse or controller 2's left stick.
## - Hold right stick LEFT: slow_down_time() on every interactable in the bubble.
## - Hold right stick RIGHT: speed_up_time() on every interactable in the bubble.
## - Press Y: press() on every interactable in the bubble (keypads, switches...).
## Interactables that leave the bubble, or are in it when the stick is let go, get reset_time().

enum TimeMode { NORMAL, SLOW, FAST }

@export var stick_speed: float = 150.0

var hovered: Array[Interactable] = []
var using_mouse: bool = true
var time_mode: TimeMode = TimeMode.NORMAL
## Interactables currently being slowed down / sped up by the bubble.
var time_affected: Array[Interactable] = []

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
	var dir := Input.get_vector("bubble_left", "bubble_right", "bubble_up", "bubble_down")
	if dir != Vector2.ZERO:
		using_mouse = false
		global_position += dir * stick_speed * delta
	elif using_mouse:
		global_position = get_global_mouse_position()

	# Keep the bubble on screen (the camera follows the father)
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	global_position = global_position.clamp(view.position, view.end)


# --- Time control ---
func _update_time_control() -> void:
	var axis := Input.get_axis("bubble_slow_time", "bubble_speed_time")
	var new_mode := TimeMode.NORMAL
	if axis < 0.0:
		new_mode = TimeMode.SLOW
	elif axis > 0.0:
		new_mode = TimeMode.FAST

	# Stick released or flipped direction: put everything back to normal first.
	if new_mode != time_mode:
		_reset_all_time()
		time_mode = new_mode

	if time_mode == TimeMode.NORMAL:
		return

	# Apply to anything in the bubble that isn't affected yet (e.g. a bullet that just flew in).
	for target in hovered:
		if not time_affected.has(target):
			time_affected.append(target)
			if time_mode == TimeMode.SLOW:
				target.slow_down_time()
			else:
				target.speed_up_time()


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
	# Left the bubble: it goes back to normal speed.
	if time_affected.has(target):
		time_affected.erase(target)
		target.reset_time()
