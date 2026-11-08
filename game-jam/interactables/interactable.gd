class_name Interactable
extends Area2D
## Base class for anything the baby's bubble can affect (bullets, keypads, slowable props, ...).
##
## The bubble calls these functions on whatever it is hovering over. Every one does
## nothing by default, so each interactable only overrides the ones that make sense
## for it (a bullet can be slowed down but not sped up, for example).


## The baby pressed Y on controller 2 while the bubble is over this (keypads, switches...).
func press() -> void:
	pass


## The baby started holding the right stick LEFT while the bubble is over this.
func slow_down_time() -> void:
	pass


## The baby started holding the right stick RIGHT while the bubble is over this.
func speed_up_time() -> void:
	pass


## Time control ended for this: the stick was let go, or this left the bubble.
## Undo whatever slow_down_time() / speed_up_time() changed.
func reset_time() -> void:
	pass
