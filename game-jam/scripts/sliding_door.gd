extends Node2D
## A door that slides out of the way (default: up into the wall) and stops blocking.
## Children: Door (the sprite) and Body/Shape (its collision).

@export var open_offset := Vector2(0, -44)
@export var duration := 0.5
@export var start_open := false

var is_open := false
@onready var door: Node2D = $Door
@onready var shape: CollisionShape2D = $Body/Shape
@onready var closed_pos: Vector2 = door.position


func _ready() -> void:
	if start_open:
		open(true)


func open(instant := false) -> void:
	is_open = true
	shape.set_deferred("disabled", true)
	if instant:
		door.position = closed_pos + open_offset
	else:
		create_tween().tween_property(door, "position", closed_pos + open_offset, duration).set_trans(Tween.TRANS_QUAD)


func close(instant := false) -> void:
	is_open = false
	shape.set_deferred("disabled", false)
	if instant:
		door.position = closed_pos
	else:
		create_tween().tween_property(door, "position", closed_pos, duration).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func toggle() -> void:
	if is_open:
		close()
	else:
		open()
