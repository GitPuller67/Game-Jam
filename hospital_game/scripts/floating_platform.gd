extends AnimatableBody2D
## Floating chunk: rises `lift` px when it breaks free, then bobs up and down.
## Players standing on it ride along. time_scale slows / freezes it.

@export var lift := 3.0
@export var amplitude := 2.0
@export var period := 1.4
@export var phase := 0.0
@export var time_scale := 1.0
@export var active := false

var base_y := 0.0
var t := 0.0
var age := 0.0


func _ready() -> void:
	base_y = position.y


func start() -> void:
	active = true
	age = 0.0


func _physics_process(delta: float) -> void:
	if not active:
		return
	var d := delta * time_scale
	t += d
	age += d
	var l := lift * clampf(age / 0.4, 0.0, 1.0)
	var amp := amplitude * clampf((age - 0.4) / 0.6, 0.0, 1.0)
	position.y = base_y - l - amp * sin(TAU * t / period + phase)
