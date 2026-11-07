class_name Bubble
extends Area2D

signal interacted(target: Node2D)

@export var stick_speed: float = 150.0

var hovered: Array[Node2D] = []
var using_mouse: bool = true

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
	if event.is_action_pressed("bubble_interact"):
		interact()


func _process(delta: float) -> void:
	var dir := Input.get_vector("bubble_left", "bubble_right", "bubble_up", "bubble_down")
	if dir != Vector2.ZERO:
		using_mouse = false
		global_position += dir * stick_speed * delta
	elif using_mouse:
		global_position = get_global_mouse_position()

	# Keep the bubble on screen (the camera follows the father)
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	global_position = global_position.clamp(view.position, view.end)

	animated_sprite.play("hover" if not hovered.is_empty() else "default")


func interact() -> void:
	if hovered.is_empty():
		return
	var target: Node2D = hovered.back()
	if target.has_method("interact"):
		target.interact()
	interacted.emit(target)


func _on_target_entered(node: Node2D) -> void:
	if node.is_in_group("interactable"):
		hovered.append(node)


func _on_target_exited(node: Node2D) -> void:
	hovered.erase(node)
