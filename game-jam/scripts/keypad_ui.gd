class_name KeypadUI
extends CanvasLayer
## Full-screen keypad for Room 1's security door. The code has to be typed in BACKWARDS
## (the doctor types it out of sight; rewinding him shows it backwards, see KeypadDoctor).
## Navigate with the d-pad / left stick (either controller), press with A, controller 2's Y or a
## mouse click. * clears, # submits (it also checks automatically after the last digit).
## The EXIT button (or B / Esc) closes it. The game is paused while it's open.

signal solved
signal closed

@export var code := "4719"
@export var ui_scale := 3.0

const GEN := "res://assets/gen/"
const KEY_ORDER := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
const KEY_SIZE := Vector2(24, 20)
const KEY_ORIGIN := Vector2(14, 51)
const KEY_STEP := Vector2(30, 24)
const LCD_ORIGIN := Vector2(30, 16)
const LCD_STEP := 14.0
const PANEL_SIZE := Vector2(112, 172)
const EXIT_POS := Vector2(34, 152)
const EXIT_SIZE := Vector2(44, 14)

var entry := ""
var is_open := false
var _busy := false
var _root: Control
var _panel: TextureRect
var _lcd: Array[TextureRect] = []
var _led_red: TextureRect
var _led_green: TextureRect
var _buttons := {}


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	get_viewport().size_changed.connect(_center)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_root = Control.new()
	_root.size = PANEL_SIZE
	_root.scale = Vector2.ONE * ui_scale
	add_child(_root)

	_panel = TextureRect.new()
	_panel.texture = load(GEN + "keypad_ui_panel.png")
	_root.add_child(_panel)

	var lcd_tex: Texture2D = load(GEN + "lcd_digits.png")
	for i in code.length():
		var d := TextureRect.new()
		d.texture = _atlas(lcd_tex, Rect2(11 * 10, 0, 10, 16))   # blank
		d.position = LCD_ORIGIN + Vector2(i * LCD_STEP, 0)
		_panel.add_child(d)
		_lcd.append(d)

	var leds: Texture2D = load(GEN + "keypad_ui_leds.png")
	_led_red = TextureRect.new()
	_led_red.texture = _atlas(leds, Rect2(0, 0, 7, 7))
	_led_red.position = Vector2(81, 3)
	_panel.add_child(_led_red)
	_led_green = TextureRect.new()
	_led_green.texture = _atlas(leds, Rect2(0, 0, 7, 7))
	_led_green.position = Vector2(91, 3)
	_panel.add_child(_led_green)

	var keys: Texture2D = load(GEN + "keypad_ui_keys.png")
	for i in KEY_ORDER.size():
		var k: String = KEY_ORDER[i]
		var b := TextureButton.new()
		var x := i * KEY_SIZE.x
		b.texture_normal = _atlas(keys, Rect2(x, 0, KEY_SIZE.x, KEY_SIZE.y))
		b.texture_focused = _atlas(keys, Rect2(x, KEY_SIZE.y, KEY_SIZE.x, KEY_SIZE.y))
		b.texture_hover = b.texture_focused
		b.texture_pressed = _atlas(keys, Rect2(x, KEY_SIZE.y * 2, KEY_SIZE.x, KEY_SIZE.y))
		b.focus_mode = Control.FOCUS_ALL
		b.position = KEY_ORIGIN + Vector2((i % 3) * KEY_STEP.x, (i / 3) * KEY_STEP.y)
		b.pressed.connect(_press.bind(k))
		b.mouse_entered.connect(b.grab_focus)
		_panel.add_child(b)
		_buttons[k] = b

	var exit_tex: Texture2D = load(GEN + "keypad_ui_exit.png")
	var ex := TextureButton.new()
	ex.texture_normal = _atlas(exit_tex, Rect2(0, 0, EXIT_SIZE.x, EXIT_SIZE.y))
	ex.texture_focused = _atlas(exit_tex, Rect2(0, EXIT_SIZE.y, EXIT_SIZE.x, EXIT_SIZE.y))
	ex.texture_hover = ex.texture_focused
	ex.texture_pressed = _atlas(exit_tex, Rect2(0, EXIT_SIZE.y * 2, EXIT_SIZE.x, EXIT_SIZE.y))
	ex.focus_mode = Control.FOCUS_ALL
	ex.position = EXIT_POS
	ex.pressed.connect(close)
	ex.mouse_entered.connect(ex.grab_focus)
	_panel.add_child(ex)
	_buttons["exit"] = ex
	_center()


func _atlas(t: Texture2D, r: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = t
	a.region = r
	return a


func _center() -> void:
	if _root:
		_root.position = ((get_viewport().get_visible_rect().size - PANEL_SIZE * ui_scale) / 2.0).round()


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	entry = ""
	_busy = false
	_set_leds(0, 0)
	_refresh()
	get_tree().paused = true
	_buttons["5"].grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	closed.emit()
	# Wait two physics frames so the button that closed this isn't read by the game (e.g. A = jump).
	await get_tree().physics_frame
	await get_tree().physics_frame
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("bubble_press"):
		get_viewport().set_input_as_handled()
		var f := get_viewport().gui_get_focus_owner() as TextureButton
		if f:
			f.pressed.emit()


func _press(k: String) -> void:
	if _busy:
		return
	match k:
		"*":
			entry = ""
		"#":
			_check()
			return
		_:
			if entry.length() < code.length():
				entry += k
	_refresh()
	if entry.length() == code.length():
		_check()


func _refresh() -> void:
	for i in _lcd.size():
		var idx := 11   # blank
		if i < entry.length():
			idx = int(entry[i])
		(_lcd[i].texture as AtlasTexture).region = Rect2(idx * 10, 0, 10, 16)


func _check() -> void:
	_busy = true
	if entry == code.reverse():
		_set_leds(0, 2)
		await get_tree().create_timer(0.7, true, false, true).timeout
		solved.emit()
		close()
	else:
		_set_leds(1, 0)
		var x := _root.position.x
		var tw := create_tween()
		for i in 4:
			tw.tween_property(_root, "position:x", x + (6.0 if i % 2 == 0 else -6.0), 0.04)
		tw.tween_property(_root, "position:x", x, 0.04)
		for i in _lcd.size():
			(_lcd[i].texture as AtlasTexture).region = Rect2(10 * 10, 0, 10, 16)   # dashes
		await get_tree().create_timer(0.6, true, false, true).timeout
		entry = ""
		_refresh()
		_set_leds(0, 0)
	_busy = false


## 0 = off, 1 = red, 2 = green
func _set_leds(red: int, green: int) -> void:
	(_led_red.texture as AtlasTexture).region = Rect2(7 * red, 0, 7, 7)
	(_led_green.texture as AtlasTexture).region = Rect2(7 * green, 0, 7, 7)
