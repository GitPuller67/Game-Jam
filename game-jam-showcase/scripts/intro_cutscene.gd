class_name IntroCutscene
extends Node
## The opening. The screen fades in as the Father walks into Room 1; he heads over to the baby pod
## (which opens as he gets there), bends down, lifts the baby out of the crib and holds it to his
## chest. Then the player takes over and `finished` fires (the level starts the keypad doctor).
## The player's input is ignored throughout (Father.cutscene), and the baby's bubble is off.

signal finished

@export var father: Father
## The crib in the pod (its sprite's top-left is its position; 48x48).
@export var crib: Sprite2D
## Where he walks in from, and how fast (a fraction of his normal speed).
@export var start_x := 24.0
@export var walk_speed := 0.8
## Where he stops, in front of the baby.
@export var stop_x := 620.0
@export var fade_time := 1.2

## Where the baby sits in the crib (from the crib's top-left): its head peeks over the rail.
const BABY_IN_CRIB := Vector2(26, 7)

var _baby_in_crib: Sprite2D
var _fade: ColorRect
var _bubble: Node2D


func _ready() -> void:
	father.cutscene = true
	father.cutscene_walk = 0.0
	father.global_position.x = start_x
	father.baby.sprite.visible = false
	_bubble = father.baby.bubble
	_bubble.visible = false
	_bubble.process_mode = Node.PROCESS_MODE_DISABLED

	# the baby waiting in the crib (drawn before the crib, so it's behind the bars)
	_baby_in_crib = Sprite2D.new()
	_baby_in_crib.name = "BabyInCrib"
	_baby_in_crib.texture = father.baby.sprite.texture
	_baby_in_crib.region_enabled = true
	_baby_in_crib.region_rect = Baby.LOOK_REGIONS[Baby.Look.TOP_LEFT]   # looking out at the room
	_baby_in_crib.centered = false
	_baby_in_crib.position = crib.position + BABY_IN_CRIB
	crib.add_sibling(_baby_in_crib)
	crib.get_parent().move_child(_baby_in_crib, crib.get_index())

	var layer := CanvasLayer.new()
	layer.layer = 5   # over the game and HUD, under the main menu
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

	_play()


func _play() -> void:
	# wait for the main menu's Play
	while get_tree().paused:
		await get_tree().process_frame
	create_tween().tween_property(_fade, "color:a", 0.0, fade_time)

	# walk in and over to the pod (it opens on its own as he gets near)
	father.cutscene_walk = walk_speed
	while father.global_position.x < stop_x:
		await get_tree().physics_frame
	father.cutscene_walk = 0.0
	await _wait(0.5)

	# bend down, lift the baby out of the crib up to his chest
	father.cutscene_crouch = true
	await _wait(0.3)
	var lift := create_tween()
	var from := _baby_in_crib.global_position
	_baby_in_crib.z_index = 6   # over the crib and the Father while it's carried
	lift.tween_method(func(k: float) -> void:
		# aim at where the baby sits on his chest right now (it moves as he stands)
		var to := father.baby.sprite.global_position
		_baby_in_crib.flip_h = father.baby.sprite.flip_h
		_baby_in_crib.global_position = from.lerp(to, k) + Vector2(0, -6.0 * sin(PI * k)),
		0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await lift.finished
	_baby_in_crib.queue_free()
	father.baby.sprite.visible = true
	father.cutscene_crouch = false
	await _wait(0.7)

	# over to the player
	_bubble.process_mode = Node.PROCESS_MODE_INHERIT
	_bubble.visible = true
	father.cutscene = false
	finished.emit()
	queue_free()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
