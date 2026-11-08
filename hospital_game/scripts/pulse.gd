extends Node2D
## Gently pulses alpha (and optionally scale) - glows, warning lights, etc.

@export var min_alpha := 0.35
@export var max_alpha := 0.9
@export var period := 1.6
@export var scale_amount := 0.0

var t := 0.0
var base_scale := Vector2.ONE


func _ready() -> void:
	t = randf() * period
	base_scale = scale


func _process(delta: float) -> void:
	t += delta
	var k := 0.5 + 0.5 * sin(TAU * t / period)
	modulate.a = lerpf(min_alpha, max_alpha, k)
	if scale_amount != 0.0:
		scale = base_scale * (1.0 + scale_amount * k)
