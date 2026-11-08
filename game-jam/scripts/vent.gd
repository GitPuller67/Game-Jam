extends Node2D
## Vent cover in the duct mouth. open() rattles it, then it swings down on its bottom hinge.

signal opened

@export var start_open := false
var is_open := false
@onready var panel: Sprite2D = $Panel
@onready var shape: CollisionShape2D = $Block/Shape
## Once open, the lid lies flat and you can stand on it (jump up through it from below).
var ledge_shape: CollisionShape2D
## Once flat, the lid drops this far so its top is level with the duct floor.
const LID_DROP := 11.0


func _ready() -> void:
	var ledge := StaticBody2D.new()
	ledge.name = "Ledge"
	add_child(ledge)
	ledge_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(62, 8)
	ledge_shape.shape = r
	ledge_shape.position = Vector2(-32, 4)       # the lid lies flush with the duct floor: a bridge from the last chunk
	ledge_shape.one_way_collision = true         # you can still jump up through it from underneath
	ledge_shape.disabled = true
	ledge.add_child(ledge_shape)
	if start_open:
		is_open = true
		panel.rotation_degrees = -90.0
		panel.position.y += LID_DROP
		shape.disabled = true
		ledge_shape.disabled = false


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
	tw.tween_property(panel, "position:y", panel.position.y + LID_DROP, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_finish_open)


func _finish_open() -> void:
	shape.set_deferred("disabled", true)
	ledge_shape.set_deferred("disabled", false)
	opened.emit()
