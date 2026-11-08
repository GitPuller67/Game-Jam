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


## Dynamic time control: called every frame while the right stick is held, with how much to
## scale time by (below 1 = slower, above 1 = faster; further stick push = further from 1).
## By default it falls back to the simple slow / speed / reset functions above.
func set_time_factor(factor: float) -> void:
	if factor < 1.0:
		slow_down_time()
	elif factor > 1.0:
		speed_up_time()
	else:
		reset_time()


## True if holding Y over this rewinds it.
func can_rewind() -> bool:
	return false


## The baby started holding Y while the bubble is over this.
func start_rewind() -> void:
	pass


## Y was let go, or this left the bubble.
func stop_rewind() -> void:
	pass
