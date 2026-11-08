extends Node2D
## Room 5 floating object: drifts, sways/spins and occasionally glitches.
## Has a child Area2D "Hazard" (group "hazard") the player controller can react to.

@export var drift := Vector2(10, 14)       # how far it wanders from its start point
@export var speed := Vector2(0.12, 0.09)   # wander cycles per second
@export var spin := 0.0                    # continuous rotation, deg/s
@export var sway_deg := 10.0               # back-and-forth tilt
@export var glitch := true
@export var time_scale := 1.0

var base := Vector2.ZERO
var t := 0.0
var phase := 0.0
var glitch_timer := 0.0
var glitch_offset := Vector2.ZERO


func _ready() -> void:
	base = position
	phase = randf() * TAU
	t = randf() * 20.0
	glitch_timer = randf_range(2.0, 7.0)


func _process(delta: float) -> void:
	var d := delta * time_scale
	t += d
	position = base + glitch_offset + Vector2(sin(t * speed.x * TAU + phase) * drift.x, sin(t * speed.y * TAU + phase * 1.7) * drift.y)
	rotation_degrees = sway_deg * sin(t * 0.6 + phase) + spin * t
	if glitch:
		glitch_timer -= delta
		if glitch_timer <= 0.0:
			_glitch()


func _glitch() -> void:
	glitch_timer = randf_range(3.0, 9.0)
	glitch_offset = Vector2(randf_range(-4, 4), randf_range(-3, 3))
	modulate = Color(1.4, 0.7, 1.5, 0.55)
	await get_tree().create_timer(0.07).timeout
	glitch_offset = Vector2.ZERO
	modulate = Color.WHITE
	await get_tree().create_timer(0.05).timeout
	modulate = Color(0.6, 1.3, 1.3, 0.8)
	await get_tree().create_timer(0.05).timeout
	modulate = Color.WHITE
