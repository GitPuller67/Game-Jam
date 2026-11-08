class_name EndScreen
extends CanvasLayer
## "To be continued..." screen shown when the Father gets through Room 6's exit.
## Fades to black, types the title out, then waits for A / Y / Enter / Space / a click to restart.
## Restarting reloads the level and skips the main menu (skip_menu_once).

## Set before reloading so the level starts straight away instead of showing the main menu again.
static var skip_menu_once := false

@export var title := "TO BE CONTINUED..."
@export var prompt := "Press  A  to restart"

var _ready_for_input := false
var _fade: ColorRect
var _title: Label
var _prompt: Label


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.02, 0.05, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)

	_title = _label(48, Color(0.92, 0.95, 1.0))
	_title.anchor_top = 0.38
	_title.anchor_bottom = 0.38
	_prompt = _label(18, Color(1.0, 0.85, 0.45))
	_prompt.anchor_top = 0.6
	_prompt.anchor_bottom = 0.6
	_prompt.text = prompt
	_prompt.modulate.a = 0.0


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.2))
	l.add_theme_constant_override("outline_size", maxi(4, size / 8))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	add_child(l)
	return l


func show_end() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	_title.text = title
	_title.visible_characters = 0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.92, 1.2)
	tw.tween_interval(0.3)
	tw.tween_property(_title, "visible_characters", title.length(), title.length() * 0.09)
	tw.tween_interval(0.6)
	tw.tween_property(_prompt, "modulate:a", 1.0, 0.4)
	tw.tween_callback(func() -> void:
		_ready_for_input = true
		var blink := create_tween().set_loops()
		blink.tween_property(_prompt, "modulate:a", 0.35, 0.6)
		blink.tween_property(_prompt, "modulate:a", 1.0, 0.6))


func _input(event: InputEvent) -> void:
	if not visible or not _ready_for_input:
		return
	var go: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("jump") \
		or event.is_action_pressed("bubble_press") \
		or (event is InputEventMouseButton and event.pressed)
	if go:
		get_viewport().set_input_as_handled()
		restart()


func restart() -> void:
	_ready_for_input = false
	skip_menu_once = true
	get_tree().paused = false
	get_tree().reload_current_scene()
