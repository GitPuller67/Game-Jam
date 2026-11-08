extends Node2D
## The scientists watching from the booth. Call vanish_all() when the baby is taken.

func vanish_all() -> void:
	for c in get_children():
		if c.has_method("vanish"):
			c.call("vanish")
