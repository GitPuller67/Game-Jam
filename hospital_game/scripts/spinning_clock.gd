extends Node2D
## Wall clock whose hands spin (degrees per second). Negative = backwards.
## wobble > 0 makes the speed surge and stall, so time looks "wrong".

@export var second_speed := 360.0
@export var minute_speed := 60.0
@export var hour_speed := 5.0
@export var wobble := 0.0
@export var time_scale := 1.0

var t := 0.0
@onready var hour_hand: Node2D = $Hour
@onready var minute_hand: Node2D = $Minute
@onready var second_hand: Node2D = $Second


func _process(delta: float) -> void:
	var d := delta * time_scale
	t += d
	var k := 1.0 + wobble * sin(t * 1.7) * sin(t * 0.43)
	second_hand.rotation_degrees += second_speed * k * d
	minute_hand.rotation_degrees += minute_speed * k * d
	hour_hand.rotation_degrees += hour_speed * k * d
