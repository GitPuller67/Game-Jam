extends AnimatedSprite2D
## Background figure that paces between min_x and max_x (local to its parent),
## pausing at each end. Used for the scientists behind the observation glass.

@export var min_x := 0.0
@export var max_x := 64.0
@export var speed := 12.0
@export var pause_time := 1.0
@export var start_dir := 1.0

var dir := 1.0
var wait := 0.0


func _ready() -> void:
	dir = signf(start_dir) if start_dir != 0.0 else 1.0
	play("walk")


func _process(delta: float) -> void:
	if wait > 0.0:
		wait -= delta
		if wait <= 0.0:
			play("walk")
		return
	position.x += dir * speed * delta
	flip_h = dir < 0.0
	if position.x > max_x or position.x < min_x:
		position.x = clampf(position.x, min_x, max_x)
		dir = -dir
		wait = pause_time
		stop()
		frame = 0


func vanish(duration := 0.6) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_callback(hide)
