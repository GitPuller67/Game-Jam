class_name Rewinder
extends Node
## Records a node's state every physics frame and plays it back in reverse while rewinding.
## Used by the baby's rewind power (hold Y with the bubble over something).
##
## SNAPSHOT mode: stores `properties` (e.g. global_position, velocity, t) for the last `seconds`
##   and pops them back off while rewinding. The target is frozen meanwhile by setting
##   `freeze_property` (usually time_scale) to 0, then restored when the rewind stops.
## REVERSE mode: for things that already know how to run backwards (an AnimationPlayer loop):
##   sets `freeze_property` to -reverse_speed while rewinding, nothing is recorded.

enum Mode { SNAPSHOT, REVERSE }

@export var target: Node
@export var properties: PackedStringArray = []
@export var mode: Mode = Mode.SNAPSHOT
## How much history to keep.
@export var seconds := 5.0
## Snapshots replayed per physics frame (2 = rewinds twice as fast as it was recorded).
@export var rewind_rate := 2
## Set to 0 while rewinding (SNAPSHOT) or to -reverse_speed x normal (REVERSE). Empty = don't touch.
@export var freeze_property := &"time_scale"
@export var reverse_speed := 2.0

var rewinding := false
var _history: Array = []
var _saved_freeze: Variant = null


func _physics_process(_delta: float) -> void:
	if mode != Mode.SNAPSHOT or not is_instance_valid(target):
		return
	if rewinding:
		for i in rewind_rate:
			if _history.is_empty():
				return          # reached the oldest snapshot: hold there until released
			var snap: Array = _history.pop_back()
			for k in properties.size():
				target.set_indexed(NodePath(properties[k]), snap[k])
	else:
		var snap := []
		for p in properties:
			snap.append(target.get_indexed(NodePath(p)))
		_history.append(snap)
		if _history.size() > int(seconds * Engine.physics_ticks_per_second):
			_history.pop_front()


## True while rewinding with nothing left to play back (it's back where recording started).
func is_exhausted() -> bool:
	return rewinding and _history.is_empty()


func start() -> void:
	if rewinding or not is_instance_valid(target):
		return
	rewinding = true
	if freeze_property != &"" and String(freeze_property) in target:
		_saved_freeze = target.get(freeze_property)
		if mode == Mode.SNAPSHOT:
			target.set(freeze_property, 0.0)
		else:
			target.set(freeze_property, -reverse_speed * absf(float(_saved_freeze)))


func stop() -> void:
	if not rewinding:
		return
	rewinding = false
	if _saved_freeze != null and is_instance_valid(target):
		target.set(freeze_property, _saved_freeze)
	_saved_freeze = null
