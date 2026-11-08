extends CanvasLayer
## The in-game HUD, built from assets/ui/ui_spritesheet.png (bars, prompts, buttons) at 2x.
##  Left:   Dad's controls - Shoot (+ scalpels left), Slide, Jump, Crouch, Soothe
##  Middle: Baby Energy and Health bars
##  Right:  the baby's controls - Move bubble, Rewind time, Slow down time, Speed up time
## The level drives it through set_energy(), set_health(), set_ammo() and show_popup().

const SHEET := preload("res://assets/ui/ui_spritesheet.png")
const EXTRA := preload("res://assets/ui/hud_extra.png")
## Pixel scale of the whole HUD.
const S := 2

# regions on ui_spritesheet.png
const BAR_EMPTY := Rect2(0, 0, 128, 16)
const BAR_EMPTY_2 := Rect2(0, 18, 128, 16)
const BAR_ENERGY := Rect2(0, 36, 128, 16)       # blue, labelled BABY ENERGY
const BAR_HEALTH := Rect2(132, 36, 128, 16)     # red, labelled HEALTH
const P_SLIDE := Rect2(0, 54, 55, 17)
const P_JUMP := Rect2(59, 54, 49, 17)
const P_CROUCH := Rect2(112, 54, 61, 17)
const P_MOVE := Rect2(177, 54, 89, 17)
const P_SLOW := Rect2(0, 73, 108, 17)
const P_SPEED := Rect2(112, 73, 102, 17)
const P_REWIND := Rect2(218, 73, 89, 17)
# regions on hud_extra.png (made in the same style: SHOOT / SOOTHE prompts and a blank pill)
const P_SHOOT := Rect2(0, 0, 57, 17)
const P_SOOTHE := Rect2(0, 17, 61, 17)
const PILL := Rect2(0, 34, 24, 17)

var energy_bar: TextureProgressBar
var health_bar: TextureProgressBar
var shoot_row: Control
var _shoot_prompt: Control
var _ammo_text: PixelText
var _ammo_box: Control
var _popup: Control
var _popup_text: PixelText
var _popup_bg: NinePatchRect
var _popup_tween: Tween


func _ready() -> void:
	_build()


# --- what the level calls ---
func set_energy(percent: float, exhausted := false) -> void:
	energy_bar.value = percent
	energy_bar.modulate = Color(1.0, 0.6, 0.6) if exhausted else Color.WHITE


func set_health(percent: float) -> void:
	health_bar.value = percent


## Shoot prompt + scalpel count only show while he has scalpels.
func set_ammo(count: int) -> void:
	_shoot_prompt.visible = count > 0
	_ammo_box.visible = count > 0
	_set_pill_text(_ammo_box, _ammo_text, "x%d" % count)


func show_popup(message: String) -> void:
	_set_pill_text(_popup, _popup_text, message)
	_popup.position.x = (get_viewport().get_visible_rect().size.x - _popup.custom_minimum_size.x) / 2.0
	_popup.modulate.a = 1.0
	_popup.visible = true
	if _popup_tween:
		_popup_tween.kill()
	_popup_tween = create_tween()
	_popup_tween.tween_interval(2.0)
	_popup_tween.tween_property(_popup, "modulate:a", 0.0, 0.5)
	_popup_tween.tween_callback(_popup.hide)


# --- building ---
func _build() -> void:
	var bottom := HBoxContainer.new()
	bottom.name = "BottomBar"
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_top = -(17 * S * 2 + 4 + 12)
	bottom.offset_bottom = -12
	bottom.add_theme_constant_override("separation", 10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)

	# Dad (left)
	var dad := _column(bottom, "Controls")
	shoot_row = _row(dad, "ShootRow")
	_shoot_prompt = _img(shoot_row, EXTRA, P_SHOOT, "ShootPrompt")
	var ammo := _pill(shoot_row, "AmmoCounter")
	_ammo_box = ammo[0]
	_ammo_text = ammo[1]
	_img(shoot_row, SHEET, P_SLIDE, "SlidePrompt")
	_img(shoot_row, SHEET, P_JUMP, "JumpPrompt")
	var basic := _row(dad, "BasicControls")
	_img(basic, SHEET, P_CROUCH, "CrouchPrompt")
	_img(basic, EXTRA, P_SOOTHE, "SoothePrompt")

	_spacer(bottom)

	# bars (middle)
	var bars := _column(bottom, "Bars")
	energy_bar = _bar(bars, "BabyEnergyBar", BAR_EMPTY, BAR_ENERGY)
	health_bar = _bar(bars, "HealthBar", BAR_EMPTY_2, BAR_HEALTH)

	_spacer(bottom)

	# Baby (right)
	var baby := _column(bottom, "BabyControls")
	var b1 := _row(baby, "BabyRow1")
	_img(b1, SHEET, P_MOVE, "MoveBubblePrompt")
	_img(b1, SHEET, P_REWIND, "RewindTimePrompt")
	var b2 := _row(baby, "BabyRow2")
	_img(b2, SHEET, P_SLOW, "SlowTimePrompt")
	_img(b2, SHEET, P_SPEED, "SpeedTimePrompt")

	# pickup popup (top middle)
	var pop := _pill(self, "WeaponPopup")
	_popup = pop[0]
	_popup_text = pop[1]
	_popup.position = Vector2(0, 16)
	_popup.visible = false

	set_ammo(0)


func _column(parent: Node, n: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = n
	v.add_theme_constant_override("separation", 4)
	v.alignment = BoxContainer.ALIGNMENT_END
	v.size_flags_vertical = Control.SIZE_SHRINK_END
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	return v


func _row(parent: Node, n: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.name = n
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	return h


func _spacer(parent: Node) -> void:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)


func _atlas(tex: Texture2D, r: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = r
	return a


func _img(parent: Node, tex: Texture2D, r: Rect2, n: String) -> TextureRect:
	var t := TextureRect.new()
	t.name = n
	t.texture = _atlas(tex, r)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = r.size * S
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


## A bar: dark empty bar underneath, the sheet's labelled full bar drains from the right.
func _bar(parent: Node, n: String, under: Rect2, fill: Rect2) -> TextureProgressBar:
	var holder := Control.new()
	holder.name = n
	holder.custom_minimum_size = under.size * S
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var bar := TextureProgressBar.new()
	bar.name = "Bar"
	bar.texture_under = _atlas(SHEET, under)
	bar.texture_progress = _atlas(SHEET, fill)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.scale = Vector2(S, S)
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bar)
	return bar


## A dark pill (the sheet's prompt frame) with pixel text in it; grows to fit the text.
func _pill(parent: Node, n: String) -> Array:
	var holder := Control.new()
	holder.name = n
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var bg := NinePatchRect.new()
	bg.name = "Bg"
	bg.texture = _atlas(EXTRA, PILL)
	bg.patch_margin_left = 4
	bg.patch_margin_right = 4
	bg.patch_margin_top = 4
	bg.patch_margin_bottom = 4
	bg.scale = Vector2(S, S)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)
	var t := PixelText.new()
	t.name = "Text"
	t.position = Vector2(5, 5)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(t)
	return [holder, t]


func _set_pill_text(holder: Control, t: PixelText, s: String) -> void:
	t.text = s
	var bg := holder.get_node("Bg") as NinePatchRect
	bg.size = Vector2(PixelText.measure(s) + 10, 17)
	holder.custom_minimum_size = bg.size * S
	holder.size = holder.custom_minimum_size
