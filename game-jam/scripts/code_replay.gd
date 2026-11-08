class_name CodeReplay
extends Node2D
## Room 1: a flickering "time echo" of a scientist walks up to the keypad and types the door code.
## Each digit pops up above the keypad. It only plays while the baby holds rewind (Y) on the keypad:
## play_replay() starts it (looping), hide_replay() fades it out, stop() ends it for good (door solved).
## The player has to type what they saw, but backwards (see KeypadUI).

@export var code := "4719"
@export var keypad: CanvasItem
## Where the echo stands (feet), next to the keypad.
@export var stand_at := Vector2(724, 0)
@export var gap_between_loops := 1.0
@export var key_interval := 0.75

var _ghost: Sprite2D
var _running := false
var _done := false
var _run_id := 0
var _lcd: Texture2D
var _fade: Tween


func _ready() -> void:
	_lcd = load("res://assets/gen/lcd_digits.png")
	_ghost = Sprite2D.new()
	_ghost.texture = load("res://assets/spritesheets/scientist.png")
	_ghost.region_enabled = true
	_ghost.region_rect = Rect2(0, 0, 48, 51)
	_ghost.position = stand_at + Vector2(0, -25.5)
	_ghost.modulate = Color(0.55, 0.85, 1.3, 0.0)
	_ghost.z_index = 4
	add_child(_ghost)


func play_replay() -> void:
	if _done or _running:
		return
	_running = true
	_run_id += 1
	_loop(_run_id)


func hide_replay() -> void:
	_running = false
	_run_id += 1
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_ghost, "modulate:a", 0.0, 0.3)


func stop() -> void:
	_done = true
	hide_replay()


func _process(_delta: float) -> void:
	# replay flicker: the echo jitters and its alpha stutters like old footage
	if _ghost.modulate.a > 0.05:
		_ghost.offset.x = 1.0 if randf() < 0.06 else 0.0
		if randf() < 0.05:
			_ghost.modulate.a = randf_range(0.25, 0.5)


func _loop(id: int) -> void:
	while _running and id == _run_id and is_inside_tree():
		_ghost.region_rect = Rect2(0, 0, 48, 51)
		_ghost.position = stand_at + Vector2(-50, -25.5)
		if _fade:
			_fade.kill()
		_fade = create_tween()
		_fade.tween_property(_ghost, "modulate:a", 0.55, 0.5)
		_fade.parallel().tween_property(_ghost, "position:x", stand_at.x, 1.2)
		await _fade.finished
		if id != _run_id:
			return
		for ch in code:
			if id != _run_id:
				return
			await get_tree().create_timer(key_interval, false).timeout
			_type(ch)
		await get_tree().create_timer(0.8, false).timeout
		if id != _run_id:
			return
		if keypad:
			var ok := create_tween()
			ok.tween_property(keypad, "modulate", Color(0.6, 1.6, 0.8), 0.1)
			ok.tween_property(keypad, "modulate", Color.WHITE, 0.4)
		_fade = create_tween()
		_fade.tween_property(_ghost, "modulate:a", 0.0, 0.6)
		await _fade.finished
		if id != _run_id:
			return
		await get_tree().create_timer(gap_between_loops, false).timeout


func _type(ch: String) -> void:
	# the echo "presses" (alternate idle frame) and the keypad lights up
	_ghost.region_rect = Rect2(48 * (1 + randi() % 2), 0, 48, 51)
	if keypad:
		var k := create_tween()
		k.tween_property(keypad, "modulate", Color(1.8, 1.8, 1.4), 0.05)
		k.tween_property(keypad, "modulate", Color.WHITE, 0.2)
	var d := Sprite2D.new()
	var a := AtlasTexture.new()
	a.atlas = _lcd
	a.region = Rect2(int(ch) * 10, 0, 10, 16)
	d.texture = a
	d.z_index = 30
	d.modulate = Color(0.6, 1.2, 0.9, 1.0)
	var start := Vector2(753, -66)
	if keypad is Node2D:
		start = (keypad as Node2D).position + Vector2(5, -24)
	d.position = start
	add_child(d)
	var tw := create_tween()
	tw.tween_property(d, "position:y", start.y - 16.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(d, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.tween_callback(d.queue_free)
