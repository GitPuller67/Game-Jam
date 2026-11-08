extends Node2D
## Lift in its shaft. The Car is an AnimatableBody2D, so anything standing on it rides along.
## floors = car floor heights (local y). Call go_to_floor(i), or leave auto_cycle on for the demo.

signal arrived(floor_index: int)

@export var floors := PackedFloat32Array([0.0, -192.0])
@export var travel_time := 3.0
@export var wait_time := 2.0
@export var auto_cycle := true
@export var time_scale := 1.0
@export var counterweight_sum := -446.0   # counterweight top = this - car top (they move opposite)
@export var car_height := 76.0           # car floor -> roof hitch
@export var hitch_x := 32.0             # where the cable joins the car roof

var target := 0
var from_y := 0.0
var t := 0.0
var moving := false
var wait := 0.0
var last_y := 0.0

@onready var car: AnimatableBody2D = $Car
@onready var pulley: Node2D = $Pulley
@onready var counterweight: Node2D = $Counterweight
@onready var cable_car: Line2D = $CableCar
@onready var cable_cw: Line2D = $CableCounterweight


func _ready() -> void:
	car.position.y = floors[0]
	last_y = car.position.y
	wait = wait_time
	_update_parts()


func go_to_floor(i: int) -> void:
	if i < 0 or i >= floors.size():
		return
	target = i
	from_y = car.position.y
	t = 0.0
	moving = true


func _physics_process(delta: float) -> void:
	var d := delta * time_scale
	if moving:
		t = minf(t + d / travel_time, 1.0)
		car.position.y = lerpf(from_y, floors[target], 0.5 - 0.5 * cos(PI * t))
		if t >= 1.0:
			moving = false
			wait = wait_time
			arrived.emit(target)
	elif auto_cycle:
		wait -= d
		if wait <= 0.0:
			go_to_floor((target + 1) % floors.size())
	_update_parts()


func _update_parts() -> void:
	var dy := car.position.y - last_y
	last_y = car.position.y
	pulley.rotation -= dy / 11.0
	var car_top := car.position.y - car_height
	counterweight.position.y = counterweight_sum - car_top
	cable_car.points = PackedVector2Array([pulley.position + Vector2(-11, 0), Vector2(hitch_x, car_top)])
	cable_cw.points = PackedVector2Array([pulley.position + Vector2(11, 0), counterweight.position + Vector2(5, 0)])
