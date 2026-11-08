class_name Baby
extends CharacterBody2D

## The baby rides on the father's chest and looks toward the bubble.
##
## babylooking.png holds four 14x23 frames, all drawn facing right:
## looking top-right, bottom-right, bottom-left, top-left.
## Each frame, the baby picks the one that points at the bubble, then moves to
## where it sits on the father's chest in his current animation frame.


# --- Signals ---
signal ability_used(ability_name: String)


# --- Enums ---
enum Look { TOP_RIGHT, BOTTOM_RIGHT, BOTTOM_LEFT, TOP_LEFT }


# --- Constants ---
## Where each frame sits in babylooking.png, in Look order.
const LOOK_REGIONS: Array[Rect2] = [
	Rect2(6, 180, 14, 23),
	Rect2(23, 180, 14, 23),
	Rect2(39, 180, 14, 23),
	Rect2(55, 180, 14, 23),
]
const BABY_SIZE := Vector2(14, 23)

## Top-left corner of the baby inside each of the father's 35x51 frames
## (facing right), per animation, in frame order. Measured from baby.png,
## which was drawn to sit on the chest of every frame in player.png.
const CHEST_POSITIONS: Dictionary[StringName, Array] = {
	&"default": [Vector2(9, 16), Vector2(9, 17), Vector2(9, 16)],
	&"run": [Vector2(9, 16), Vector2(9, 17), Vector2(9, 15), Vector2(9, 17), Vector2(9, 15)],
	&"jump": [Vector2(9, 15)], # the father's jump reuses his last run frame
	&"slide": [Vector2(8, 21), Vector2(8, 25), Vector2(8, 25)],
	&"crouch": [Vector2(9, 20), Vector2(9, 24), Vector2(9, 25)],
}


# --- Exported variables ---
## The father's sprite. The baby follows its animation, frame and flip.
@export var father_sprite: AnimatedSprite2D

@export_group("Looking")
## How far (px) the bubble must cross the baby's head before the baby switches
## between left/right or up/down. Stops flickering when it's right on the line.
@export var switch_margin: float = 2.0

@export_group("Abilities")
@export var ability_cooldown: float = 1.0


# --- Regular variables ---
var can_use_ability: bool = true
var look: Look = Look.TOP_RIGHT
## Which side of the head the bubble is on, in screen space.
var _bubble_right: bool = true
var _bubble_above: bool = true


# --- @onready variables ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var ability_timer: Timer = $AbilityTimer
@onready var bubble: Bubble = $Bubble


# --- Built-in functions ---
func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	var flipped := father_sprite != null and father_sprite.flip_h
	sprite.flip_h = flipped
	sprite.position = _get_chest_position(flipped)
	look = _get_look(flipped)
	sprite.region_rect = LOOK_REGIONS[look]


func _unhandled_input(event: InputEvent) -> void:
	pass


# --- Looking ---
## Picks the frame that points at the bubble. The frames are drawn facing right,
## so when the father faces left (sprite flipped) left and right swap.
func _get_look(flipped: bool) -> Look:
	var head := sprite.global_position + BABY_SIZE * Vector2(0.5, 0.3)
	var to_bubble := bubble.global_position - head
	if absf(to_bubble.x) > switch_margin:
		_bubble_right = to_bubble.x > 0.0
	if absf(to_bubble.y) > switch_margin:
		_bubble_above = to_bubble.y < 0.0

	var look_right := _bubble_right != flipped
	if _bubble_above:
		return Look.TOP_RIGHT if look_right else Look.TOP_LEFT
	return Look.BOTTOM_RIGHT if look_right else Look.BOTTOM_LEFT


# --- Following the father ---
## Places the baby's top-left corner on the father's chest for his current frame.
func _get_chest_position(flipped: bool) -> Vector2:
	if father_sprite == null:
		return -BABY_SIZE / 2.0
	var anim := father_sprite.animation
	var positions: Array = CHEST_POSITIONS.get(anim, CHEST_POSITIONS[&"default"])
	var chest: Vector2 = positions[clampi(father_sprite.frame, 0, positions.size() - 1)]

	# The father's sprite is centered on his node, so his frame's top-left is at -size/2.
	var frame_size := Vector2(35, 51)
	var texture := father_sprite.sprite_frames.get_frame_texture(anim, father_sprite.frame)
	if texture:
		frame_size = texture.get_size()
	if flipped:
		chest.x = frame_size.x - chest.x - BABY_SIZE.x
	# Convert from the father sprite's parent space into the baby's own space.
	return father_sprite.position - position + father_sprite.offset - frame_size / 2.0 + chest


# --- Abilities ---
func use_ability(ability_name: String) -> void:
	pass


func is_ability_ready() -> bool:
	return false


# --- Timer callbacks ---
func _on_ability_timer_timeout() -> void:
	pass
