extends Node2D

## The father's aiming arm. The father always turns to face where he's aiming,
## so his front arm pivots on its shoulder to point at the aim and holds a
## scalpel sideways in its fist. The back arm is left as drawn in his animations.
##
## The body uses player_armless.png (player.png with the front forearm
## removed), and the aiming arm is player_arm.png drawn pointing right with the
## shoulder pivot at pixel (2, 2). When he's out of ammo the aiming arm is
## hidden and the body switches back to player.png, so the front arm goes back
## to its drawn animation.


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
const DEFAULT_FRAME_SIZE := Vector2(35, 51)


# --- Exported variables ---
@export var father_sprite: AnimatedSprite2D
## The body sheet without the front forearm, and the original with it.
@export var armless_sheet: Texture2D = preload("res://assets/spritesheets/player_armless.png")
@export var full_sheet: Texture2D = preload("res://assets/spritesheets/player.png")

@export_group("Held scalpel")
## Distance from the shoulder pivot to the hand along the arm.
@export var hand_distance: float = 11.0
## The scalpel is held sideways (blade up, edge forward) by its handle; this is
## how far the scalpel's center sits above the fist.
@export var grip_offset: float = 4.0
## Seconds the hand stays empty after a throw before the next scalpel appears.
@export var rearm_time: float = 0.15


# --- Regular variables ---
var _rearm_left: float = 0.0
var _armed_frames: SpriteFrames
var _unarmed_frames: SpriteFrames


# --- @onready variables ---
@onready var father: Father = owner
@onready var front_arm: Sprite2D = $FrontArm
@onready var held_scalpel: Sprite2D = $HeldScalpel


# --- Built-in functions ---
func _ready() -> void:
	father.shot.connect(func() -> void: _rearm_left = rearm_time)
	_armed_frames = father_sprite.sprite_frames
	_unarmed_frames = _with_sheet_swapped(_armed_frames, armless_sheet, full_sheet)


func _process(delta: float) -> void:
	var armed := father.current_ammo > 0
	_set_body_frames(_armed_frames if armed else _unarmed_frames)
	front_arm.visible = armed

	var flipped := father_sprite.flip_h
	front_arm.position = _shoulder_position(FRONT_SHOULDER_X, flipped)

	# The father turns to face his aim (see Father._face_aim), so the front arm aims.
	var angle := _aim_angle_from(front_arm.global_position)
	front_arm.global_rotation = angle
	front_arm.flip_v = flipped # keep the light side of the arm on top

	_update_held_scalpel(front_arm, angle, flipped, delta)


# --- Helpers ---
## A copy of the father's animations with every frame cut from `from` re-cut from `to`.
func _with_sheet_swapped(frames: SpriteFrames, from: Texture2D, to: Texture2D) -> SpriteFrames:
	var copy := frames.duplicate() as SpriteFrames
	for anim in copy.get_animation_names():
		for i in copy.get_frame_count(anim):
			var atlas := copy.get_frame_texture(anim, i) as AtlasTexture
			if atlas and atlas.atlas == from:
				var swapped := atlas.duplicate() as AtlasTexture
				swapped.atlas = to
				copy.set_frame(anim, i, swapped, copy.get_frame_duration(anim, i))
	return copy


## Switches the father's animations without restarting the one that's playing.
func _set_body_frames(frames: SpriteFrames) -> void:
	if father_sprite.sprite_frames == frames:
		return
	var anim := father_sprite.animation
	var frame := father_sprite.frame
	var progress := father_sprite.frame_progress
	var playing := father_sprite.is_playing()
	father_sprite.sprite_frames = frames
	father_sprite.animation = anim
	if playing:
		father_sprite.play(anim)
	father_sprite.set_frame_and_progress(frame, progress)


## Puts a scalpel sideways in the aiming hand (perpendicular to the arm, blade
## up, cutting edge forward) and moves the father's Muzzle onto it so thrown
## scalpels leave from the hand.
func _update_held_scalpel(arm: Sprite2D, angle: float, flipped: bool, delta: float) -> void:
	var hand := arm.global_position + Vector2.from_angle(angle) * hand_distance
	# Facing left everything is mirrored, so "up" is the other perpendicular.
	var scalpel_angle := angle + (PI / 2 if flipped else -PI / 2)
	held_scalpel.global_rotation = scalpel_angle
	held_scalpel.flip_v = flipped
	held_scalpel.global_position = hand + Vector2.from_angle(scalpel_angle) * grip_offset
	held_scalpel.z_index = arm.z_index
	father.muzzle.global_position = held_scalpel.global_position

	_rearm_left = maxf(_rearm_left - delta, 0.0)
	held_scalpel.visible = father.current_ammo > 0 and _rearm_left == 0.0


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
