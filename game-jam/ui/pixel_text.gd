@tool
class_name PixelText
extends Control
## Draws text with the HUD's pixel font (assets/ui/hud_font.png, letters lifted from ui_spritesheet.png).
## Upper-case letters, digits, "x", "!" and "-". Lower-case letters are drawn as capitals (except x).

@export var text := "":
	set(v):
		text = v
		update_minimum_size()
		queue_redraw()

const FONT_TEX := preload("res://assets/ui/hud_font.png")
static var _meta: Dictionary = {}


static func _load_meta() -> void:
	if _meta.is_empty():
		var f := FileAccess.open("res://assets/ui/hud_font.json", FileAccess.READ)
		_meta = JSON.parse_string(f.get_as_text())


func _ready() -> void:
	_load_meta()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	update_minimum_size()


static func measure(s: String) -> int:
	_load_meta()
	var w := 0
	var gap: int = int(_meta.gap)
	for i in s.length():
		var ch := _glyph_char(s[i])
		if ch == " ":
			w += int(_meta.space)
		elif _meta.glyphs.has(ch):
			w += int(_meta.glyphs[ch][1])
		if i < s.length() - 1:
			w += gap
	return w


static func _glyph_char(c: String) -> String:
	return c if c == "x" else c.to_upper()


func _get_minimum_size() -> Vector2:
	_load_meta()
	return Vector2(measure(text), int(_meta.height))


func _draw() -> void:
	_load_meta()
	var x := 0
	var cell: int = int(_meta.cell)
	var h: int = int(_meta.height)
	for i in text.length():
		var ch := _glyph_char(text[i])
		if ch == " ":
			x += int(_meta.space) + int(_meta.gap)
			continue
		if not _meta.glyphs.has(ch):
			continue
		var g: Array = _meta.glyphs[ch]
		var w: int = int(g[1])
		draw_texture_rect_region(FONT_TEX, Rect2(x, 0, w, h), Rect2(int(g[0]) * cell, 0, w, h))
		x += w + int(_meta.gap)
