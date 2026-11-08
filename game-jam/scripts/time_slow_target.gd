class_name TimeSlowTarget
extends Area2D
## Something the baby can slow down: hover the bubble over it and press interact.
## The bubble finds it through the "interactable" group and calls interact().
## Each target node gets `property` (e.g. time_scale) lowered to slow_factor for slow_duration seconds.

signal slowed
signal restored

@export var targets: Array[Node] = []
@export var property := &"time_scale"
@export var slow_factor := 0.25
@export var slow_duration := 4.0
## Tinted blue while slowed so the player can see it worked.
@export var tint_node: CanvasItem

var is_slowed := false
var _normal := {}


func _ready() -> void:
	add_to_group("interactable")
	monitoring = false   # the bubble does the detecting


func interact() -> void:
	if is_slowed:
		return
	is_slowed = true
	for t in targets:
		if is_instance_valid(t):
			_normal[t] = t.get(property)
			t.set(property, float(_normal[t]) * slow_factor)
	if tint_node:
		tint_node.modulate = Color(0.7, 0.85, 1.25)
	slowed.emit()
	await get_tree().create_timer(slow_duration).timeout
	for t in targets:
		if is_instance_valid(t):
			t.set(property, _normal[t])
	if tint_node:
		tint_node.modulate = Color.WHITE
	is_slowed = false
	restored.emit()


## Helper for building targets from code.
static func make(parent: Node, shape: Shape2D, offset: Vector2, what: Array[Node], tint: CanvasItem = null, prop := &"time_scale") -> TimeSlowTarget:
	var a := TimeSlowTarget.new()
	a.name = "TimeSlowTarget"
	a.targets = what
	a.property = prop
	a.tint_node = tint
	a.position = offset
	var cs := CollisionShape2D.new()
	cs.shape = shape
	a.add_child(cs)
	parent.add_child(a)
	return a
