extends Node2D
## Room 6: everything replays on a 10-second loop driven by $LoopPlayer (animation "loop").
## Change loop_speed to speed up / slow down / reverse the whole room (the clock mechanic).
## door_is_open() tells you whether the exit is currently passable.

@export var loop_speed := 1.0:
	set(v):
		loop_speed = v
		if is_node_ready():
			player.speed_scale = v

@onready var player: AnimationPlayer = $LoopPlayer


func _ready() -> void:
	player.speed_scale = loop_speed
	player.play("loop")


func loop_time() -> float:
	return player.current_animation_position


func door_is_open() -> bool:
	return ($ExitDoor/Body/Shape as CollisionShape2D).disabled
