class_name BubbleButton
extends Interactable
## Anything the baby can "press" with the bubble (keypads, switches...).
## The baby presses Y with the bubble over it, and the bubble calls press().

signal pressed
## Emitted while the baby holds Y (rewind) over it, if rewindable is on.
signal rewind_started
signal rewind_stopped

## Holding Y over it "rewinds" it (e.g. Room 1's keypad replays the code being typed).
@export var rewindable := false
## How much of the baby's rewind energy holding Y here costs (1 = normal).
@export var rewind_drain_scale := 0.3

@export var one_shot := true
var used := false


func _ready() -> void:
	add_to_group("interactable")
	monitoring = false


func press() -> void:
	if one_shot and used:
		return
	used = true
	pressed.emit()


func can_rewind() -> bool:
	return rewindable


func start_rewind() -> void:
	rewind_started.emit()


func stop_rewind() -> void:
	rewind_stopped.emit()
