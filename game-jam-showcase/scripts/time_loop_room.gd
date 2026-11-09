extends Node2D
## Room 6: everything replays on a seamless 10-second loop (animation "loop" on $LoopPlayer).
## Change loop_speed to speed up / slow down / reverse the whole room (the clock mechanic).
## door_is_open() tells you whether the exit is currently passable.
##
## The room steps the loop's time itself and seeks the AnimationPlayer to it every frame,
## so ALL keys (including on/off ones like the food appearing) are right in both directions -
## an AnimationPlayer playing backwards on its own skips those.

@export var loop_speed := 1.0

var loop_t := 0.0
var _door_was_open := false
@onready var player: AnimationPlayer = $LoopPlayer
@onready var door_shape: CollisionShape2D = $ExitDoor/Body/Shape


func _ready() -> void:
	player.play("loop")
	player.speed_scale = 0.0          # we drive the time ourselves
	player.seek(loop_t, true)


func _process(delta: float) -> void:
	var length := player.current_animation_length
	if length <= 0.0:
		return
	var step := delta * loop_speed
	loop_t = fposmod(loop_t + step, length)
	if step < 0.0:
		# Going backwards: on/off keys are only applied correctly when moving forwards,
		# so jump to the start and come forwards to the new time.
		player.seek(0.0, true)
	player.seek(loop_t, true)
	_check_door()


## When the door shuts on someone who is still in the doorway, it shoves them back into the room
## (otherwise the physics would pop them out on the far side and the timing wouldn't matter).
func _check_door() -> void:
	var open := door_shape.disabled
	if _door_was_open and not open:
		var rect := door_shape.shape as RectangleShape2D
		var cx := door_shape.global_position.x
		var half := rect.size.x / 2.0 + 14.0          # door half width + a body's half width
		for body in get_tree().get_nodes_in_group("door_blockable"):
			var b := body as Node2D
			if b and absf(b.global_position.x - cx) < half and absf(b.global_position.y - door_shape.global_position.y) < rect.size.y / 2.0 + 30.0:
				b.global_position.x = cx - half - 1.0
	_door_was_open = open


func loop_time() -> float:
	return loop_t


func door_is_open() -> bool:
	return ($ExitDoor/Body/Shape as CollisionShape2D).disabled
