class_name BubbleButton
extends Area2D
## Anything the baby can "press" with the bubble (keypads, switches...).
## The bubble finds it through the "interactable" group and calls interact().

signal pressed

@export var one_shot := true
var used := false


func _ready() -> void:
	add_to_group("interactable")
	monitoring = false


func interact() -> void:
	if one_shot and used:
		return
	used = true
	pressed.emit()
