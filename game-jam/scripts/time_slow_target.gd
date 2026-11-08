class_name TimeSlowTarget
extends Interactable
## Something the baby can control the time of with the bubble over it:
##  - right stick LEFT / RIGHT: slows it down / speeds it up - how far the stick is pushed sets how much.
##    The bubble calls set_time_factor() every frame, then reset_time() when the stick is let go
##    or this leaves the bubble.
##  - hold Y: rewinds it (needs at least one Rewinder, added with add_rewind()).
## Each target node gets `property` (e.g. time_scale) multiplied by the factor.

signal slowed
signal restored

@export var targets: Array[Node] = []
@export var property := &"time_scale"
## Used by slow_down_time() / speed_up_time() (fixed amounts, for anything that still calls them).
@export var slow_factor := 0.25
@export var speed_factor := 2.0
## Unused since slowing became hold-to-slow; kept so existing levels that set it still load.
@export var slow_duration := 4.0
## Tinted while affected so the player can see it working (blue = slow, orange = fast, purple = rewind).
@export var tint_node: CanvasItem

var is_slowed := false
var is_rewinding := false
var _normal := {}
var _rewinders: Array[Rewinder] = []

const SLOW_TINT := Color(0.7, 0.85, 1.25)
const FAST_TINT := Color(1.25, 0.95, 0.7)
const REWIND_TINT := Color(1.1, 0.75, 1.35)


func _ready() -> void:
	add_to_group("interactable")
	monitoring = false   # the bubble does the detecting


# --- Time speed ---
func set_time_factor(factor: float) -> void:
	if is_rewinding:
		return
	if not is_slowed:
		is_slowed = true
		for t in targets:
			if is_instance_valid(t):
				_normal[t] = t.get(property)
		slowed.emit()
	for t in targets:
		if is_instance_valid(t) and _normal.has(t):
			t.set(property, float(_normal[t]) * factor)
	if tint_node:
		if factor < 1.0:
			tint_node.modulate = Color.WHITE.lerp(SLOW_TINT, clampf((1.0 - factor) / 0.75, 0.0, 1.0))
		else:
			tint_node.modulate = Color.WHITE.lerp(FAST_TINT, clampf(factor - 1.0, 0.0, 1.0))


func slow_down_time() -> void:
	set_time_factor(slow_factor)


func speed_up_time() -> void:
	set_time_factor(speed_factor)


func reset_time() -> void:
	if not is_slowed:
		return
	for t in targets:
		if is_instance_valid(t) and _normal.has(t):
			t.set(property, _normal[t])
	_normal.clear()
	if tint_node:
		tint_node.modulate = Color.WHITE
	is_slowed = false
	restored.emit()


# --- Rewind ---
func can_rewind() -> bool:
	return not _rewinders.is_empty()


func start_rewind() -> void:
	if _rewinders.is_empty() or is_rewinding:
		return
	reset_time()
	is_rewinding = true
	for r in _rewinders:
		r.start()
	if tint_node:
		tint_node.modulate = REWIND_TINT


func stop_rewind() -> void:
	if not is_rewinding:
		return
	is_rewinding = false
	for r in _rewinders:
		r.stop()
	if tint_node:
		tint_node.modulate = Color.WHITE


## Records `props` on `node` so it can be rewound. `freeze` is set to 0 while rewinding
## (&"" for none). REVERSE mode instead runs `freeze` backwards (e.g. an animation loop's speed).
func add_rewind(node: Node, props: PackedStringArray, freeze := &"time_scale", mode := Rewinder.Mode.SNAPSHOT) -> Rewinder:
	var r := Rewinder.new()
	r.name = "Rewinder%d" % _rewinders.size()
	r.target = node
	r.properties = props
	r.freeze_property = freeze
	r.mode = mode
	add_child(r)
	_rewinders.append(r)
	return r


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
