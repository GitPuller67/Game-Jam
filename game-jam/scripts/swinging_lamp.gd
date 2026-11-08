extends Node2D
## Ceiling lamp swinging on a chain. This node sits at the ceiling pivot.
## time_scale lets the baby's power speed it up / slow it down.

@export var length := 70.0
@export var amplitude_deg := 28.0
@export var period := 2.6
@export var time_scale := 1.0

var t := 0.0
@onready var chain: Line2D = $Chain
@onready var lamp: Node2D = $Lamp


func _process(delta: float) -> void:
	t += delta * time_scale
	var a := deg_to_rad(amplitude_deg) * sin(TAU * t / period)
	var tip := Vector2(sin(a), cos(a)) * length
	lamp.position = tip
	lamp.rotation = -a
	chain.points = PackedVector2Array([Vector2.ZERO, tip])
