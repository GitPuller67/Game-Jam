extends Node2D

## The father's arms. The arm on the side the player is aiming at pivots on its
## shoulder to point at the aim; the other arm hangs down. When the aim crosses
## the father's midpoint, the arms swap.
##
## The body uses player_armless.png (player.png with the drawn-in forearms
## removed), and each arm is player_arm.png drawn pointing right with the
## shoulder pivot at pixel (2, 2).


# --- Constants ---
## Top row of the shirt in each of the father's 35x51 frames, per animation, in
## frame order. The shoulders sit SHOULDER_DROP pixels below it.
const TORSO_TOP: Dictionary[StringName, Array] = {
	&"default": [17, 18, 17],
	&"run": [17, 18, 16, 18, 16],
	&"jump": [16], # the father's jump reuses his last run frame
	&"slide": [22, 26, 26],
	&"crouch": [21, 25, 26],
}
## The shirt is drawn 1px further left in the slide frames.
const TORSO_SHIFT: Dictionary[StringName, float] = { &"slide": -1.0 }
const SHOULDER_DROP: float = 3.5
## Shoulder x inside the frame when facing right (pixel centers).
const FRONT_SHOULDER_X: float = 20.5
const BACK_SHOULDER_X: float = 5.5
const DEFAULT_FRAME_SIZE := Vector2(35, 51)


# --- Exported variables ---
@export var father_sprite: AnimatedSprite2D
## Angle of the arm that isn't aiming (radians, 0 = right, PI/2 = straight down).
@export var hang_angle: float = PI / 2
## How far (as a fraction of a full sideways aim) the aim must cross the
## midpoint before the hands swap. Stops flickering when aiming straight up/down.
@export_range(0.0, 0.5) var switch_threshold: float = 0.1


# --- Regular variables ---
var aiming_right: bool = true


# --- @onready variables ---
@onready var father: Father = owner
@onready var front_arm: Sprite2D = $FrontArm
@onready var back_arm: Sprite2D = $BackArm


# --- Built-in functions ---
func _process(_delta: float) -> void:
	var flipped := father_sprite.flip_h
	front_arm.position = _shoulder_position(FRONT_SHOULDER_X, flipped)
	back_arm.position = _shoulder_position(BACK_SHOULDER_X, flipped)

	# Which side of the father's midpoint the aim is on.
	var aim_x := cos(father.current_aim_angle)
	if absf(aim_x) > switch_threshold:
		aiming_right = aim_x > 0.0

	# Facing right, the front shoulder is on the right; facing left, it's the back one.
	var front_is_right := not flipped
	var aiming_arm := front_arm if aiming_right == front_is_right else back_arm
	var hanging_arm := back_arm if aiming_arm == front_arm else front_arm

	var angle := _aim_angle_from(aiming_arm.global_position)
	aiming_arm.global_rotation = angle
	aiming_arm.flip_v = cos(angle) < 0.0 # keep the light side of the arm on top

	hanging_arm.rotation = hang_angle
	hanging_arm.flip_v = flipped


# --- Helpers ---
## The direction the arm should point from its shoulder. With the mouse, aim at
## the cursor itself so the arm points right at it even up close.
func _aim_angle_from(shoulder: Vector2) -> float:
	if father.is_using_controller:
		return father.current_aim_angle
	var to_mouse := get_global_mouse_position() - shoulder
	if to_mouse.length() < 1.0:
		return father.current_aim_angle
	return to_mouse.angle()


## A shoulder's position for the father's current frame, in this node's space.
func _shoulder_position(shoulder_x: float, flipped: bool) -> Vector2:
	var anim := father_sprite.animation
	var tops: Array = TORSO_TOP.get(anim, TORSO_TOP[&"default"])
	var top: float = tops[clampi(father_sprite.frame, 0, tops.size() - 1)]
	var point := Vector2(shoulder_x + TORSO_SHIFT.get(anim, 0.0), top + SHOULDER_DROP)

	# The father's sprite is centered on his node, so his frame's top-left is at -size/2.
	var frame_size := DEFAULT_FRAME_SIZE
	var texture := father_sprite.sprite_frames.get_frame_texture(anim, father_sprite.frame)
	if texture:
		frame_size = texture.get_size()
	if flipped:
		point.x = frame_size.x - point.x
	return father_sprite.position - position + father_sprite.offset - frame_size / 2.0 + point
