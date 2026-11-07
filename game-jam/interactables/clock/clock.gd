class_name Clock
extends Area2D
## A clock the baby can interact with by moving the bubble over it and pressing A / clicking.
## The bubble finds it through the "interactable" group and calls interact().

## Emitted when the baby interacts with the clock. Connect this to whatever should happen.
signal clock_used


func interact() -> void:
	print("Clock used")
	clock_used.emit()

	# Quick pulse so you can see the interaction worked.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08)
