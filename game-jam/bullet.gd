class_name Bullet
extends Interactable
## A bullet the baby can slow down by hovering the bubble over it and holding the
## right stick left. Speeding bullets up makes no sense, so speed_up_time() isn't overridden.

@export var speed: float = 800.0
## How fast the bullet moves while slowed (0.5 = half speed).
@export var slowed_multiplier: float = 0.5
## Tint applied while slowed so the player can see it working.
@export var slowed_tint: Color = Color(0.6, 0.85, 1.0)

var time_scale: float = 1.0


func _physics_process(delta: float) -> void:
	position += transform.x * speed * time_scale * delta


func slow_down_time() -> void:
	time_scale = slowed_multiplier
	modulate = slowed_tint


func reset_time() -> void:
	time_scale = 1.0
	modulate = Color.WHITE
