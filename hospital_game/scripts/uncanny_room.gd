extends Node2D
## Room 5 atmosphere: the tint "breathes" and the sickly lights stutter.

@export var breathe_period := 5.0
var t := 0.0
@onready var tint: CanvasItem = $Tint
@onready var lights: Node = $Lights


func _process(delta: float) -> void:
	t += delta
	var k := 0.5 + 0.5 * sin(TAU * t / breathe_period)
	tint.modulate = Color(1, 1, 1, lerpf(0.8, 1.0, k))
	for l in lights.get_children():
		var pl := l as PointLight2D
		if pl:
			if randf() < 0.04:
				pl.energy = randf_range(0.0, 0.25)
			else:
				pl.energy = lerpf(pl.energy, 0.7, 0.1)
