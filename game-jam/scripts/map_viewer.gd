extends Camera2D
## Free-look camera for viewing the map until the player controllers are added.
## WASD / arrows = pan, mouse wheel or Q/E = zoom, right/middle mouse drag = pan,
## 1-6 = jump to a room, 0 = reset zoom. Delete this node once the real player camera exists.

@export var pan_speed := 320.0
var anchors: Array[Node2D] = []
var dragging := false
var hud: Label
var room := 1


func _ready() -> void:
	# Only used when Map.tscn is run on its own. Inside a level the player's camera takes over.
	if owner and owner.get_parent() != get_tree().root:
		queue_free()
		return
	make_current()
	for i in range(1, 7):
		var a := get_node_or_null("../RoomAnchors/Room%d" % i) as Node2D
		if a:
			anchors.append(a)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(4, 2)
	hud.add_theme_font_size_override("font_size", 8)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 3)
	layer.add_child(hud)
	jump(0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			jump(int(arg.substr(7)) - 1)
		elif arg.begins_with("--zoom="):
			zoom = Vector2.ONE * float(arg.substr(7))
		elif arg.begins_with("--x="):
			position.x = float(arg.substr(4))
		elif arg.begins_with("--y="):
			position.y = float(arg.substr(4))
		elif arg == "--nohud":
			hud.visible = false


func jump(i: int) -> void:
	if i >= 0 and i < anchors.size():
		position = anchors[i].global_position
		room = i + 1


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1
	if Input.is_key_pressed(KEY_Q): zoom = (zoom * (1.0 - delta)).clamp(Vector2.ONE * 0.2, Vector2.ONE * 4.0)
	if Input.is_key_pressed(KEY_E): zoom = (zoom * (1.0 + delta)).clamp(Vector2.ONE * 0.2, Vector2.ONE * 4.0)
	position += dir * pan_speed * delta / zoom.x
	hud.text = "MAP VIEWER  room %d  zoom %.2f   WASD pan | wheel/Q/E zoom | 1-6 rooms | 0 reset | G size guide" % [room, zoom.x]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = (zoom * 1.1).clamp(Vector2.ONE * 0.2, Vector2.ONE * 4.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = (zoom / 1.1).clamp(Vector2.ONE * 0.2, Vector2.ONE * 4.0)
		elif event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		position -= event.relative / zoom
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			jump(event.keycode - KEY_1)
		elif event.keycode == KEY_0:
			zoom = Vector2.ONE
		elif event.keycode == KEY_G:
			for g in get_tree().get_nodes_in_group("size_guide"):
				(g as CanvasItem).visible = not (g as CanvasItem).visible
