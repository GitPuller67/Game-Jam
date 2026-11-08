extends Node2D
## Vent cover in the duct mouth. open() rattles it, then it swings down on its bottom hinge.

signal opened

@export var start_open := false
var is_open := false
@onready var panel: Sprite2D = $Panel
@onready var shape: CollisionShape2D = $Block/Shape


func _ready() -> void:
	if start_open:
		is_open = true
		panel.rotation_degrees = -90.0
		shape.disabled = true


func open() -> void:
	if is_open:
		return
	is_open = true
	var x0 := panel.position.x
	var tw := create_tween()
	for i in 6:
		tw.tween_property(panel, "position:x", x0 + (1.0 if i % 2 == 0 else -1.0), 0.05)
	tw.tween_property(panel, "position:x", x0, 0.05)
	tw.tween_interval(0.25)
	tw.tween_property(panel, "rotation_degrees", -100.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(panel, "rotation_degrees", -80.0, 0.15)
	tw.tween_property(panel, "rotation_degrees", -90.0, 0.12)
	tw.tween_callback(_finish_open)


func _finish_open() -> void:
	shape.set_deferred("disabled", true)
	opened.emit()
