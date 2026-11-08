extends SceneTree
## Generates res://tiles/hospital_tileset.tres and res://scenes/Map.tscn from scratch.
##   godot --headless --path . --script res://tools/build_map.gd
## WARNING: re-running OVERWRITES Map.tscn, including anything you changed in the editor.
## After the first build, edit Map.tscn in the editor instead of re-running this.

const T := 16
const GEN := "res://assets/gen/"
const ART := "res://assets/art/"
const FLIP_H := 4096
const FLIP_V := 8192

# Open space of the whole level, in tiles: [x0, y0, x1, y1] inclusive. y grows downward.
const RECTS := [
	[1, -8, 14, -1], [15, -16, 47, -1],      # Room 1 (low left part, tall lab)
	[48, -4, 48, -1],                         # Room 1 -> 2 door (64 high, character is 51)
	[49, -7, 94, -1],                         # Room 2 corridor (7 tiles high, room for the lamp swing)
	[95, -26, 98, -1],                        # lift shaft (4 tiles wide) (Room 2 -> Room 3) + machine room
	[99, -16, 99, -13],                       # shaft -> Room 3
	[100, -18, 139, -13],                     # Room 3 (6 tiles high)
	[140, -16, 148, -13],                     # corridor 3 -> 4
	[149, -24, 188, -13],                     # Room 4 (12 tiles high)
	[189, -23, 201, -20],                     # vent duct 4 -> 5 (64 high, character is 51)
	[202, -23, 229, 9],                       # Room 5 (drop)
	[230, 5, 230, 9], [231, 0, 236, 9], [237, 0, 237, 3],   # stairs up to Room 6
	[238, -2, 277, 3],                        # Room 6 (6 tiles high)
	[278, 0, 281, 3],                         # Room 6 exit door + nook (64 high)
]

var ts: TileSet
var interior := {}
var slopes := {}
var forced := {}
var bg: TileMapLayer
var decor: TileMapLayer
var solid_layer: TileMapLayer


func _init() -> void:
	for d in ["res://tiles", "res://scenes"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	build_tileset()
	build_map()
	print("BUILD OK")
	quit()


# ----------------------------------------------------------------- helpers
func tex(p: String) -> Texture2D:
	return load(p) as Texture2D


func add(parent: Node, node: Node, n: String) -> Node:
	node.name = n
	parent.add_child(node)
	return node


func spr(parent: Node, n: String, texture: Texture2D, pos: Vector2, z := 0, centered := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = centered
	s.position = pos
	s.z_index = z
	add(parent, s, n)
	return s


func atlas(texture: Texture2D, r: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = texture
	a.region = r
	return a


func rect_shape(parent: Node, n: String, size: Vector2, center: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = center
	add(parent, cs, n)
	return cs


func static_box(parent: Node, n: String, pos: Vector2, size: Vector2) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.position = pos
	add(parent, b, n)
	rect_shape(b, "Shape", size, size / 2.0)
	return b


func marker(parent: Node, n: String, pos: Vector2) -> void:
	var m := Marker2D.new()
	m.position = pos
	m.gizmo_extents = 8.0
	add(parent, m, n)


func note(parent: Node, text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.z_index = 60
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.set_script(load("res://scripts/editor_note.gd"))
	add(parent, l, "EditorNote")


func frames(texture: Texture2D, fw: int, fh: int, anims: Array) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in anims:
		var n: String = a[0]
		sf.add_animation(n)
		sf.set_animation_speed(n, a[2])
		sf.set_animation_loop(n, a[3])
		for i in a[1]:
			sf.add_frame(n, atlas(texture, Rect2(i * fw, 0, fw, fh)))
	return sf


func anim_sprite(parent: Node, n: String, sf: SpriteFrames, pos: Vector2, autoplay := "", z := 0) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = sf
	a.centered = false
	a.position = pos
	a.z_index = z
	if autoplay != "":
		a.animation = autoplay
		a.autoplay = autoplay
	else:
		a.animation = sf.get_animation_names()[0]
	add(parent, a, n)
	return a


func radial(size: int, inner: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func light(parent: Node, n: String, pos: Vector2, size: int, color: Color, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = radial(size, Color.WHITE, Color(1, 1, 1, 0))
	l.color = color
	l.energy = energy
	l.position = pos
	add(parent, l, n)
	return l


func clock(parent: Node, n: String, size: int, center: Vector2, spin := Vector3.ZERO, wobble := 0.0) -> Node2D:
	var c := Node2D.new()
	c.position = center
	add(parent, c, n)
	var p := GEN + "clock%d_" % size
	spr(c, "Face", tex(p + "face.png"), Vector2.ZERO, 0, true)
	spr(c, "Hour", tex(p + "hour.png"), Vector2.ZERO, 1, true).rotation_degrees = 300.0
	spr(c, "Minute", tex(p + "min.png"), Vector2.ZERO, 2, true).rotation_degrees = 60.0
	spr(c, "Second", tex(p + "sec.png"), Vector2.ZERO, 3, true)
	spr(c, "Hub", tex(p + "hub.png"), Vector2.ZERO, 4, true)
	if spin != Vector3.ZERO:
		c.set_script(load("res://scripts/spinning_clock.gd"))
		c.set("second_speed", spin.x)
		c.set("minute_speed", spin.y)
		c.set("hour_speed", spin.z)
		c.set("wobble", wobble)
	return c


func own(node: Node, owner_node: Node) -> void:
	for ch in node.get_children():
		ch.owner = owner_node
		own(ch, owner_node)


func hash3(c: Vector2i) -> int:
	return absi((c.x * 73856093) ^ (c.y * 19349663) ^ 0x5bd1e995)


# ----------------------------------------------------------------- tileset
func build_tileset() -> void:
	var t := TileSet.new()
	t.tile_size = Vector2i(T, T)
	t.add_physics_layer()
	t.set_physics_layer_collision_layer(0, 1)
	var a := TileSetAtlasSource.new()
	a.texture = tex(GEN + "sideview_tiles.png")
	a.texture_region_size = Vector2i(T, T)
	t.add_source(a, 0)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for y in 7:
		for x in 8:
			var c := Vector2i(x, y)
			a.create_tile(c)
			var poly := PackedVector2Array()
			var one_way := false
			if y <= 1:
				poly = full                                                              # structure (16 edge variants)
			elif y == 2 and x == 0:
				poly = PackedVector2Array([Vector2(-8, 8), Vector2(8, 8), Vector2(8, -8)])   # stairs going up-right
			elif y == 2 and x == 1:
				poly = full                                                              # plain solid fill
			elif y == 2 and x >= 2 and x <= 4:
				poly = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -4), Vector2(-8, -4)])
				one_way = true                                                           # catwalk you can jump up through
			if poly.size() > 0:
				var td := a.get_tile_data(c, 0)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, poly)
				td.set_collision_polygon_one_way(0, 0, one_way)
	var w := TileSetAtlasSource.new()
	w.texture = tex(ART + "hospital_ward_tiles.png")
	w.texture_region_size = Vector2i(T, T)
	t.add_source(w, 1)
	for y in 10:
		for x in 8:
			w.create_tile(Vector2i(x, y))
	ResourceSaver.save(t, "res://tiles/hospital_tileset.tres")
	ts = load("res://tiles/hospital_tileset.tres") as TileSet


# ----------------------------------------------------------------- level geometry
func carve() -> void:
	for r in RECTS:
		for y in range(r[1], r[3] + 1):
			for x in range(r[0], r[2] + 1):
				interior[Vector2i(x, y)] = true
	# observation booth hanging in Room 1 (walls + floor are solid)
	for y in range(-16, -9):
		forced[Vector2i(21, y)] = true
		forced[Vector2i(40, y)] = true
	for x in range(21, 41):
		forced[Vector2i(x, -10)] = true
	# baby pod roof
	for x in range(34, 44):
		forced[Vector2i(x, -7)] = true
	for c in forced:
		interior.erase(c)
	# staircase between Room 5 and Room 6: slope tiles with solid beneath
	for col in range(231, 237):
		var sr := 9 - (col - 231)
		interior.erase(Vector2i(col, sr))
		slopes[Vector2i(col, sr)] = true
		for row in range(sr + 1, 10):
			interior.erase(Vector2i(col, row))


func floor_dist(c: Vector2i) -> int:
	var n := 1
	var p := c + Vector2i(0, 1)
	while interior.has(p):
		n += 1
		p.y += 1
	return n


func region(c: Vector2i) -> String:
	var x := c.x
	if x <= 47:
		if x >= 22 and x <= 39 and c.y >= -16 and c.y <= -11:
			return "booth"
		if x >= 35 and x <= 42 and c.y >= -6 and c.y <= -1:
			return "pod"
		return "lab"
	if x >= 95 and x <= 98:
		return "brick" if c.y <= -23 else "shaft"
	if x >= 189 and x <= 201 and c.y >= -23 and c.y <= -20:
		return "duct"
	if x >= 202 and x <= 229:
		return "uncanny"
	if x >= 230 and x <= 237:
		return "concrete"
	return "ward"


func bg_tile(c: Vector2i) -> Vector2i:
	var f := floor_dist(c)
	var top := not interior.has(c + Vector2i(0, -1))
	match region(c):
		"booth": return Vector2i(7, 3)
		"pod": return Vector2i(6, 3)
		"shaft": return Vector2i(6, 2)
		"brick": return Vector2i(7, 2)
		"duct": return Vector2i(5, 2)
		"concrete": return Vector2i(5, 3)
		"lab":
			if f == 1: return Vector2i(4, 4)
			if f <= 3: return Vector2i(3, 4)
			if f == 4: return Vector2i(2, 4)
			if top: return Vector2i(0, 4)
			if c.x == 3 or c.x == 45: return Vector2i(5, 4)          # vertical pipes
			if c in [Vector2i(9, -6), Vector2i(17, -8), Vector2i(44, -12)]: return Vector2i(7, 4)
			if c in [Vector2i(6, -7), Vector2i(43, -7)]: return Vector2i(6, 4)
			return Vector2i(1, 4)
		"uncanny":
			if f == 1: return Vector2i(5, 5)
			if f == 2: return Vector2i(4, 5)
			if f == 3: return Vector2i(3, 5)
			if top: return Vector2i(0, 5)
			var h := hash3(c) % 45
			if h == 0: return Vector2i(1, 5)
			if h == 1: return Vector2i(2, 5)
			if h == 2: return Vector2i(6, 5)
			if h == 3: return Vector2i(7, 5)
			return Vector2i(0, 6)
	if f == 1: return Vector2i(4, 3)
	if f == 2: return Vector2i(3, 3)
	if f == 3: return Vector2i(2, 3)
	if top: return Vector2i(0, 3)
	return Vector2i(1, 3)


func paint_tiles() -> void:
	var lo := Vector2i(-4, -31)
	var hi := Vector2i(286, 14)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var c := Vector2i(x, y)
			if interior.has(c):
				bg.set_cell(c, 0, bg_tile(c))
				continue
			if slopes.has(c):
				bg.set_cell(c, 0, Vector2i(5, 3))
				solid_layer.set_cell(c, 0, Vector2i(0, 2))
				continue
			var near := forced.has(c)
			if not near:
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var n := c + Vector2i(dx, dy)
						if interior.has(n) or slopes.has(n):
							near = true
			if not near:
				continue
			var m := 0
			if interior.has(c + Vector2i(0, -1)): m |= 1
			if interior.has(c + Vector2i(1, 0)): m |= 2
			if interior.has(c + Vector2i(0, 1)): m |= 4
			if interior.has(c + Vector2i(-1, 0)): m |= 8
			solid_layer.set_cell(c, 0, Vector2i(m % 8, m / 8))


const D := {
	"window_tl": Vector2i(3, 4), "window_tr": Vector2i(4, 4), "window_bl": Vector2i(3, 5), "window_br": Vector2i(4, 5),
	"red_cross": Vector2i(5, 4), "vent": Vector2i(6, 4), "poster": Vector2i(7, 4), "gas": Vector2i(5, 5),
	"switch": Vector2i(6, 5), "sanitizer": Vector2i(7, 5), "tv_l": Vector2i(3, 7), "tv_r": Vector2i(4, 7),
	"lamp": Vector2i(5, 7), "notice_l": Vector2i(3, 8), "notice_r": Vector2i(4, 8), "gloves": Vector2i(5, 8),
	"sharps": Vector2i(6, 8), "call": Vector2i(7, 8),
}


func deco(x: int, y: int, key: String) -> void:
	decor.set_cell(Vector2i(x, y), 1, D[key])


func window(x: int, y: int) -> void:
	deco(x, y, "window_tl"); deco(x + 1, y, "window_tr")
	deco(x, y + 1, "window_bl"); deco(x + 1, y + 1, "window_br")


func paint_decor() -> void:
	# Room 2 corridor
	deco(58, -4, "switch"); deco(60, -6, "red_cross"); deco(62, -4, "sanitizer")
	deco(76, -4, "notice_l"); deco(77, -4, "notice_r"); deco(84, -7, "lamp"); deco(81, -4, "gloves")
	# Room 3 (kept bare - shooting range)
	deco(106, -18, "vent"); deco(133, -18, "vent")
	deco(112, -16, "notice_l"); deco(113, -16, "notice_r"); deco(131, -16, "sanitizer")
	# corridor + Room 4
	deco(144, -16, "lamp"); deco(154, -24, "lamp"); deco(170, -24, "lamp"); deco(162, -16, "poster"); deco(166, -16, "switch"); deco(157, -17, "red_cross")
	# Room 6 ward
	window(241, -2); deco(246, -1, "gas"); deco(248, -1, "call"); deco(252, -2, "vent")
	deco(266, -1, "notice_l"); deco(267, -1, "notice_r"); deco(274, -1, "sanitizer"); deco(276, -1, "sharps")
	deco(253, -2, "tv_l"); deco(254, -2, "tv_r")


# ----------------------------------------------------------------- map
func build_map() -> void:
	carve()
	var root := Node2D.new()
	root.name = "Map"
	bg = TileMapLayer.new(); bg.tile_set = ts; bg.z_index = -20; bg.collision_enabled = false
	add(root, bg, "Background")
	decor = TileMapLayer.new(); decor.tile_set = ts; decor.z_index = -19; decor.collision_enabled = false
	add(root, decor, "WallDecor")
	solid_layer = TileMapLayer.new(); solid_layer.tile_set = ts; solid_layer.z_index = 10
	add(root, solid_layer, "Solid")
	paint_tiles()
	paint_decor()

	var rooms := Node2D.new()
	add(root, rooms, "Rooms")
	room1(add(rooms, Node2D.new(), "Room1_FindingBaby"))
	room2(add(rooms, Node2D.new(), "Room2_Corridor"))
	room3(add(rooms, Node2D.new(), "Room3_ShootingIntro"))
	room4(rooms)
	room5(rooms)
	room6(rooms)

	lighting(root)

	var anchors := Node2D.new()
	add(root, anchors, "RoomAnchors")
	var centers := [Vector2(384, -136), Vector2(1180, -56), Vector2(1920, -240), Vector2(2704, -288), Vector2(3456, -72), Vector2(4128, 16)]
	for i in centers.size():
		marker(anchors, "Room%d" % (i + 1), centers[i])

	# 26x51 character-size guides (editor only; G toggles them in the viewer)
	var guides := Node2D.new()
	add(root, guides, "CharacterSizeGuides")
	for g in [Vector2(72, 0), Vector2(820, 0), Vector2(1700, -192), Vector2(2440, -192), Vector2(3300, 160), Vector2(3880, 64)]:
		var cr := ColorRect.new()
		cr.size = Vector2(26, 51)
		cr.position = g - Vector2(13, 51)
		cr.color = Color(1, 0.3, 0.6, 0.45)
		cr.z_index = 50
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cr.set_script(load("res://scripts/size_guide.gd"))
		add(guides, cr, "Player26x51")

	var cam := Camera2D.new()
	cam.set_script(load("res://scripts/map_viewer.gd"))
	add(root, cam, "MapViewer")

	own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed %d" % err)
	ResourceSaver.save(ps, "res://scenes/Map.tscn")
	root.free()


# ----------------------------------------------------------------- Room 1: finding the baby
func room1(r: Node2D) -> void:
	note(r, "ROOM 1 - Finding the baby\nCribs wired to the experiment machine. Clocks spin.\nScientists watch from the booth (Observers.vanish_all()).\nBaby pod on the right; keypad opens the exit door.", Vector2(24, -138))
	marker(r, "PlayerStart", Vector2(40, 0))
	anim_sprite(r, "LabMachine", frames(tex(GEN + "lab_machine_sheet.png"), 48, 64, [["run", [0, 1, 2, 3], 5, true]]), Vector2(152, -64), "run")
	var cribs := ["baby_crib_oak", "baby_crib_walnut", "baby_crib_oak", "baby_crib_walnut"]
	var cables := Node2D.new()
	add(r, cables, "Cables")
	for i in 4:
		var cx := 232 + i * 56
		spr(r, "Crib%d" % (i + 1), tex(ART + cribs[i] + ".png"), Vector2(cx, -48))
		var start := Vector2(199, -39 + i * 6)
		var end := Vector2(cx + 4, -26)
		var curve := Curve2D.new()
		curve.add_point(start, Vector2.ZERO, Vector2(18, 30 - i * 4))
		curve.add_point(end, Vector2(-26, 18), Vector2.ZERO)
		var path := Path2D.new()
		path.curve = curve
		add(cables, path, "Cable%d" % (i + 1))
		var pts := curve.tessellate()
		var dark := Line2D.new(); dark.points = pts; dark.width = 3.0; dark.default_color = Color(0.08, 0.09, 0.14)
		add(path, dark, "Wire")
		var core := Line2D.new(); core.points = pts; core.width = 1.0; core.default_color = Color(0.36, 0.77, 0.6, 0.55)
		add(path, core, "Glow")
		for k in 2:
			var pf := PathFollow2D.new()
			pf.rotates = false
			pf.set_script(load("res://scripts/cable_pulse.gd"))
			pf.set("start_ratio", k * 0.5 + i * 0.13)
			pf.set("speed", 0.45 + i * 0.07)
			add(path, pf, "Pulse%d" % (k + 1))
			spr(pf, "Dot", tex(GEN + "glow_dot.png"), Vector2.ZERO, 1, true)
	# spinning clocks either side of the booth
	clock(r, "ClockLeft", 32, Vector2(296, -216), Vector3(720, 200, 30), 0.6)
	clock(r, "ClockRight", 32, Vector2(704, -216), Vector3(-540, -150, -20), 0.9)
	# observation booth
	var booth := Node2D.new()
	add(r, booth, "ObservationBooth")
	var interior_tex := tex(GEN + "booth_interior.png")
	spr(booth, "Interior", interior_tex, Vector2(352, -256), -5)
	var obs := Node2D.new()
	obs.set_script(load("res://scripts/observers.gd"))
	obs.z_index = -4
	add(booth, obs, "Observers")
	var sf := frames(tex(GEN + "scientist_walk.png"), 12, 22, [["walk", [0, 1], 4, true]])
	var walkers := [[372, 440, -1.0, 11.0], [470, 530, 1.0, 6.0], [560, 628, 1.0, 12.0]]
	for i in walkers.size():
		var w := anim_sprite(obs, "Scientist%d" % (i + 1), sf, Vector2(walkers[i][0] + 20, -200), "walk")
		w.set_script(load("res://scripts/walker.gd"))
		w.set("min_x", float(walkers[i][0])); w.set("max_x", float(walkers[i][1]))
		w.set("start_dir", walkers[i][2]); w.set("speed", walkers[i][3])
		w.modulate = Color(0.85, 0.9, 1.0)
	var desk := spr(booth, "DeskFront", interior_tex, Vector2(352, -184), -3)
	desk.region_enabled = true
	desk.region_rect = Rect2(0, 72, 288, 24)
	spr(booth, "Glass", tex(GEN + "booth_glass.png"), Vector2(352, -256), -2)
	# baby pod: glass door + glass wall, glowing crib
	var pod := Node2D.new()
	add(r, pod, "BabyPod")
	var glass := tex(GEN + "pod_glass.png")
	var door := Node2D.new()
	door.position = Vector2(544, -96)
	add(pod, door, "PodDoor")
	var dsp := spr(door, "Door", glass, Vector2(4, 0), 1); dsp.scale = Vector2(1, 2)
	var db := StaticBody2D.new(); add(door, db, "Body"); rect_shape(db, "Shape", Vector2(8, 96), Vector2(8, 48))
	door.set_script(load("res://scripts/sliding_door.gd")); door.set("open_offset", Vector2(0, -92))
	var wall := spr(pod, "GlassWall", glass, Vector2(692, -96), 1); wall.scale = Vector2(1, 2)
	static_box(pod, "GlassWallBody", Vector2(692, -96), Vector2(8, 96))
	var glow := spr(pod, "BabyGlow", radial(96, Color(1, 0.9, 0.45, 0.8), Color(1, 0.9, 0.45, 0)), Vector2(616, -28), -1, true)
	glow.set_script(load("res://scripts/pulse.gd")); glow.set("scale_amount", 0.15)
	spr(pod, "BabyCrib", tex(ART + "baby_crib_white.png"), Vector2(592, -48))
	marker(pod, "BabyStart", Vector2(616, -20))
	light(pod, "PodLight", Vector2(616, -80), 160, Color(0.5, 1.0, 0.75), 0.45)
	# exit door + keypad
	var ex := Node2D.new()
	ex.position = Vector2(768, -64)
	add(r, ex, "ExitDoor")
	spr(ex, "Door", tex(GEN + "security_door.png"), Vector2.ZERO, 0)
	var eb := StaticBody2D.new(); add(ex, eb, "Body"); rect_shape(eb, "Shape", Vector2(12, 64), Vector2(8, 32))
	ex.set_script(load("res://scripts/sliding_door.gd")); ex.set("open_offset", Vector2(0, -62))
	anim_sprite(r, "Keypad", frames(tex(GEN + "keypad.png"), 10, 14, [["locked", [0, 1], 2.0, true], ["unlocked", [2], 1.0, true]]), Vector2(748, -42), "locked")


# ----------------------------------------------------------------- Room 2: corridor + lift
func room2(r: Node2D) -> void:
	note(r, "ROOM 2 - Corridor (mechanics tutorial)\nJump the crate, swing from the lamp (baby speeds it up to\nclear the rubble), security lunge spot, lab guy, then the lift.", Vector2(792, -106))
	var crate := static_box(r, "Crate", Vector2(872, -32), Vector2(32, 32))
	spr(crate, "Sprite", tex(GEN + "crate.png"), Vector2.ZERO)
	var lamp := Node2D.new()
	lamp.position = Vector2(1128, -112)
	add(r, lamp, "SwingingLamp")
	var chain := Line2D.new(); chain.width = 2.0; chain.default_color = Color(0.16, 0.18, 0.27)
	chain.points = PackedVector2Array([Vector2.ZERO, Vector2(0, 36)])
	add(lamp, chain, "Chain")
	var head := Node2D.new(); head.position = Vector2(0, 36)
	add(lamp, head, "Lamp")
	spr(head, "Shade", tex(GEN + "lamp.png"), Vector2(-12, 0))
	light(head, "Light", Vector2(0, 16), 170, Color(1, 0.9, 0.7), 0.45)
	var grab := Area2D.new(); grab.collision_layer = 4; grab.collision_mask = 0
	add(head, grab, "GrabPoint")
	grab.add_to_group("grab_point", true)
	var cs := CollisionShape2D.new(); var circ := CircleShape2D.new(); circ.radius = 7.0; cs.shape = circ; cs.position = Vector2(0, 6)
	add(grab, cs, "Shape")
	lamp.set_script(load("res://scripts/swinging_lamp.gd"))
	lamp.set("length", 36.0)
	lamp.set("amplitude_deg", 40.0)
	var rubble := StaticBody2D.new(); rubble.position = Vector2(1092, -16)
	add(r, rubble, "Rubble")
	spr(rubble, "Sprite", tex(GEN + "rubble_pile.png"), Vector2.ZERO)
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(2, 16), Vector2(18, 8), Vector2(36, 3), Vector2(52, 4), Vector2(66, 9), Vector2(78, 16)])
	add(rubble, poly, "Shape")
	spr(r, "WindowLeft", tex(GEN + "window_big.png"), Vector2(812, -104), -18)
	spr(r, "WindowRight", tex(GEN + "window_big.png"), Vector2(1400, -104), -18)
	marker(r, "BoxJump", Vector2(888, -40))
	marker(r, "SecurityGuardSpot", Vector2(1344, 0))
	marker(r, "LabGuySpot", Vector2(1456, 0))
	marker(r, "ElevatorCall", Vector2(1496, -24))
	# lift
	var el := Node2D.new()
	el.position = Vector2(1520, 0)
	add(r, el, "Elevator")
	spr(el, "Motor", tex(GEN + "lift_motor.png"), Vector2(10, -414), -1)
	spr(el, "Pulley", tex(GEN + "pulley.png"), Vector2(43, -392), 1, true)
	spr(el, "Counterweight", tex(GEN + "counterweight.png"), Vector2(49, -370), -2)
	var c1 := Line2D.new(); c1.width = 2.0; c1.default_color = Color(0.15, 0.17, 0.27); c1.z_index = -1
	add(el, c1, "CableCar")
	var c2 := Line2D.new(); c2.width = 2.0; c2.default_color = Color(0.15, 0.17, 0.27); c2.z_index = -3
	add(el, c2, "CableCounterweight")
	var car := AnimatableBody2D.new()
	car.z_index = 2
	add(el, car, "Car")
	spr(car, "Sprite", tex(GEN + "lift_car.png"), Vector2(0, -76))
	rect_shape(car, "Floor", Vector2(64, 4), Vector2(32, 2))
	el.set_script(load("res://scripts/elevator.gd"))
	el.set("travel_time", 3.0)
	el.set("wait_time", 2.5)
	el.set("counterweight_sum", -446.0)
	el.set("car_height", 76.0)


func room3(r: Node2D) -> void:
	note(r, "ROOM 3 - Shooting introduction (left empty: no NPCs yet)\nMarkers show where the dad and the two guards stand.", Vector2(1608, -282))
	marker(r, "DadShootSpot", Vector2(1650, -192))
	marker(r, "Guard1Spot", Vector2(1980, -192))
	marker(r, "Guard2Spot", Vector2(2090, -192))
	# reception / waiting area (background props, no collision)
	var p := Node2D.new()
	add(r, p, "Props")
	spr(p, "PlantLeft", tex(GEN + "plant.png"), Vector2(1606, -228), -5)
	spr(p, "ReceptionDesk", tex(GEN + "reception_desk.png"), Vector2(1640, -232), -5)
	spr(p, "ReceptionSign", tex(GEN + "sign_reception.png"), Vector2(1664, -268), -6)
	spr(p, "WaitingChairs1", tex(GEN + "waiting_chairs.png"), Vector2(1748, -220), -5)
	spr(p, "WaterCooler", tex(GEN + "water_cooler.png"), Vector2(1830, -232), -5)
	spr(p, "WardDoors", tex(GEN + "double_door.png"), Vector2(1864, -256), -7)
	spr(p, "WardSign", tex(GEN + "sign_ward.png"), Vector2(1870, -284), -6)
	spr(p, "Extinguisher", tex(GEN + "extinguisher.png"), Vector2(1930, -236), -6)
	spr(p, "WaitingChairs2", tex(GEN + "waiting_chairs.png"), Vector2(1952, -220), -5)
	clock(p, "WallClock", 32, Vector2(1984, -258))
	spr(p, "VendingMachine", tex(GEN + "vending.png"), Vector2(2040, -248), -5)
	spr(p, "WetFloorSign", tex(GEN + "wet_floor.png"), Vector2(2118, -214), -4)
	spr(p, "ParkedGurney", atlas(tex(GEN + "bed_side.png"), Rect2(0, 0, 64, 32)), Vector2(2150, -224), -5)
	spr(p, "PlantRight", tex(GEN + "plant.png"), Vector2(2216, -228), -5)


# ----------------------------------------------------------------- Room 4: pillars -> floating staircase -> vent
func room4(rooms: Node2D) -> void:
	var r := Node2D.new()
	add(rooms, r, "Room4_Pillars")
	note(r, "ROOM 4 - Pillars\nEach column cracks, bursts and leaves a floating chunk.\nThe chunks make a staircase up to the vent duct (top right).\nRoom4_Pillars.demo_autoplay breaks them automatically.", Vector2(2392, -360))
	# the calm half of the room before the columns (background props, no collision)
	var props := Node2D.new()
	add(r, props, "Props")
	spr(props, "WardDoors", tex(GEN + "double_door.png"), Vector2(2392, -256), -7)
	spr(props, "HighWindowLeft", tex(GEN + "window_big.png"), Vector2(2420, -360), -18)
	spr(props, "HighWindowRight", tex(GEN + "window_big.png"), Vector2(2580, -360), -18)
	spr(props, "MedCabinet", tex(GEN + "med_cabinet.png"), Vector2(2452, -274), -6)
	spr(props, "SupplyCart", tex(GEN + "supply_cart.png"), Vector2(2448, -222), -5)
	spr(props, "ParkedGurney", atlas(tex(GEN + "bed_side.png"), Rect2(0, 0, 64, 32)), Vector2(2490, -224), -5)
	spr(props, "WaitingChairs", tex(GEN + "waiting_chairs.png"), Vector2(2574, -220), -5)
	spr(props, "Wheelchair", tex(GEN + "wheelchair.png"), Vector2(2636, -224), -5)
	spr(props, "Plant", tex(GEN + "plant.png"), Vector2(2680, -228), -5)
	spr(props, "Extinguisher", tex(GEN + "extinguisher.png"), Vector2(2560, -236), -6)
	# warning signs that the columns are failing
	spr(props, "CautionSign", tex(GEN + "sign_caution.png"), Vector2(2706, -270), -6)
	spr(props, "KeepOutSign", tex(GEN + "sign_keepout.png"), Vector2(2730, -216), -3)
	spr(props, "Barrier", tex(GEN + "barrier.png"), Vector2(2712, -214), -4)
	spr(props, "WallCracks1", tex(GEN + "wall_cracks.png"), Vector2(2744, -384), -17)
	spr(props, "WallCracks2", tex(GEN + "wall_cracks.png"), Vector2(2900, -300), -17).flip_h = true
	spr(props, "HangingCeilingPanel", tex(GEN + "ceiling_panel.png"), Vector2(2756, -384), -2)
	var grit := CPUParticles2D.new()
	grit.position = Vector2(2770, -378)
	grit.amount = 10
	grit.lifetime = 1.6
	grit.preprocess = 2.0
	grit.texture = tex(GEN + "mote.png")
	grit.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	grit.emission_rect_extents = Vector2(10, 2)
	grit.direction = Vector2(0, 1)
	grit.spread = 8.0
	grit.gravity = Vector2(0, 60)
	grit.initial_velocity_min = 4.0
	grit.initial_velocity_max = 12.0
	grit.color = Color(0.85, 0.85, 0.8, 0.8)
	add(props, grit, "FallingGrit")

	var holder := Node2D.new()
	add(r, holder, "Pillars")
	# chunk_top / top_stump_end / bottom_stump_start, in px below the ceiling
	var data := [[167, 107, 180], [139, 79, 173], [111, 51, 145], [83, 23, 117]]   # from pillars_tall.lua
	for k in 4:
		var ct: float = data[k][0]
		var te: float = data[k][1]
		var bs: float = data[k][2]
		var p := Node2D.new()
		p.position = Vector2(2804 + k * 56, -384)
		add(holder, p, "Pillar%d" % (k + 1))
		anim_sprite(p, "Sprite", frames(tex(ART + "pillar%d_tall_sheet.png" % (k + 1)), 32, 192,
			[["intact", [0], 1.0, false], ["break", [1, 1, 2, 2, 3, 4, 3, 4], 8.0, false], ["broken", [5], 1.0, false]]), Vector2(-16, 0), "intact")
		var body := StaticBody2D.new()
		add(p, body, "Body")
		rect_shape(body, "Intact", Vector2(24, 192), Vector2(0, 96))
		rect_shape(body, "TopStump", Vector2(24, maxf(te, 1.0)), Vector2(0, te / 2.0))
		rect_shape(body, "BottomStump", Vector2(24, 192.0 - bs), Vector2(0, (bs + 192.0) / 2.0))
		var chunk := AnimatableBody2D.new()
		chunk.position = Vector2(0, ct)
		add(p, chunk, "Chunk")
		spr(chunk, "Sprite", tex(ART + "chunk_tall_%d.png" % (k + 1)), Vector2(-14, -6))
		rect_shape(chunk, "Shape", Vector2(24, 14), Vector2(0, 7))
		chunk.set_script(load("res://scripts/floating_platform.gd"))
		chunk.set("phase", (k + 1) * 1.3)
		var rb := CPUParticles2D.new()
		rb.position = Vector2(0, (te + bs) / 2.0)
		rb.emitting = false
		rb.one_shot = true
		rb.amount = 40
		rb.lifetime = 0.8
		rb.explosiveness = 0.95
		rb.texture = tex(GEN + "pebble.png")
		rb.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		rb.emission_rect_extents = Vector2(12, (bs - te) / 2.0)
		rb.direction = Vector2(0, -1)
		rb.spread = 75.0
		rb.initial_velocity_min = 30.0
		rb.initial_velocity_max = 95.0
		rb.gravity = Vector2(0, 320)
		rb.z_index = 3
		add(p, rb, "Rubble")
		p.set_script(load("res://scripts/pillar.gd"))
	var vent := Node2D.new()
	vent.position = Vector2(3024, -304)
	add(r, vent, "Vent")
	var panel := spr(vent, "Panel", tex(GEN + "vent_panel.png"), Vector2.ZERO, 12)
	panel.offset = Vector2(-1, -63)
	var vb := StaticBody2D.new(); add(vent, vb, "Block"); rect_shape(vb, "Shape", Vector2(14, 64), Vector2(8, -32))
	vent.set_script(load("res://scripts/vent.gd"))
	marker(r, "DuctEntry", Vector2(3044, -304))
	r.set_script(load("res://scripts/room4_controller.gd"))


# ----------------------------------------------------------------- Room 5: the uncanny drop
func floater(parent: Node, n: String, texture: Texture2D, pos: Vector2, spin: float, sway: float, drift := Vector2(10, 14), rot := 0.0) -> Node2D:
	var f := Node2D.new()
	f.position = pos
	f.rotation_degrees = rot
	add(parent, f, n)
	spr(f, "Sprite", texture, Vector2.ZERO, 0, true)
	var hz := Area2D.new(); hz.collision_layer = 2; hz.collision_mask = 0
	add(f, hz, "Hazard")
	hz.add_to_group("hazard", true)
	rect_shape(hz, "Shape", texture.get_size() * 0.7, Vector2.ZERO)
	f.set_script(load("res://scripts/floater.gd"))
	f.set("spin", spin)
	f.set("sway_deg", sway)
	f.set("drift", drift)
	return f


func room5(rooms: Node2D) -> void:
	var r := Node2D.new()
	add(rooms, r, "Room5_UncannyDrop")
	note(r, "ROOM 5 - The drop\nOut of the duct (top left) and fall. Hospital things hang in the air,\ndrifting, spinning and glitching. Each has a Hazard area (group 'hazard').\nExit: stairs bottom right.", Vector2(3240, -268))
	marker(r, "FallStart", Vector2(3250, -272))
	marker(r, "Exit", Vector2(3700, 150))
	var fl := Node2D.new()
	add(r, fl, "Floaters")
	var icons := tex(ART + "item_icons_16x16.png")
	var bed := tex(GEN + "bed_side.png")
	var list := [
		["CribWhite", tex(ART + "baby_crib_white.png"), Vector2(3300, -190), 0.0, 22.0],
		["CribOak", tex(ART + "baby_crib_oak.png"), Vector2(3560, -150), 7.0, 10.0],
		["CribWalnut", tex(ART + "baby_crib_walnut.png"), Vector2(3420, 70), -5.0, 14.0],
		["Bed", atlas(bed, Rect2(0, 0, 64, 32)), Vector2(3490, -40), 0.0, 16.0],
		["Wheelchair", tex(GEN + "wheelchair.png"), Vector2(3280, 110), 22.0, 0.0],
		["Wheelchair2", tex(GEN + "wheelchair.png"), Vector2(3630, 40), -14.0, 0.0],
		["IVStand", tex(GEN + "iv_stand.png"), Vector2(3450, -235), 0.0, 35.0],
		["IVStand2", tex(GEN + "iv_stand.png"), Vector2(3655, 115), 48.0, 0.0],
		["Chair", tex(GEN + "chair.png"), Vector2(3360, -100), 60.0, 0.0],
		["Chair2", tex(GEN + "chair.png"), Vector2(3585, 105), -40.0, 0.0],
		["Monitor", tex(GEN + "heart_monitor.png"), Vector2(3530, -255), 0.0, 9.0],
		["Tray", tex(GEN + "tray_full.png"), Vector2(3300, -55), 90.0, 0.0],
		["Stethoscope", tex(GEN + "stethoscope.png"), Vector2(3430, 135), -70.0, 0.0],
		["Teddy", tex(GEN + "teddy.png"), Vector2(3385, -268), 30.0, 0.0],
		["Bottle", atlas(icons, Rect2(0, 0, 16, 16)), Vector2(3505, 15), 120.0, 0.0],
		["Syringe", atlas(icons, Rect2(16, 0, 16, 16)), Vector2(3565, -85), -150.0, 0.0],
		["Plaster", atlas(icons, Rect2(32, 0, 16, 16)), Vector2(3325, 70), 80.0, 0.0],
		["Pills", atlas(icons, Rect2(48, 0, 16, 16)), Vector2(3645, -120), 110.0, 0.0],
		["Scalpel", tex(ART + "scalpel_icon_16.png"), Vector2(3465, -130), 300.0, 0.0],
		["Crate", tex(GEN + "crate.png"), Vector2(3610, -20), 12.0, 0.0],
		["Apple", tex(GEN + "apple.png"), Vector2(3395, 10), 200.0, 0.0],
		["Cup", tex(GEN + "cup.png"), Vector2(3540, 140), -95.0, 0.0],
	]
	for it in list:
		floater(fl, it[0], it[1], it[2], it[3], it[4])
	var holder := floater(fl, "FloatingClock", tex(GEN + "clock64_face.png"), Vector2(3610, -250), 4.0, 0.0)
	clock(holder, "Hands", 64, Vector2.ZERO, Vector3(-200, -40, -6), 1.2)
	# things stuck where they shouldn't be
	var wrong := Node2D.new()
	add(r, wrong, "WrongThings")
	var up := clock(wrong, "CeilingClock", 32, Vector2(3560, -288), Vector3(-90, -15, -2), 0.5)
	up.rotation_degrees = 180.0
	spr(wrong, "CeilingIVStand", tex(GEN + "iv_stand.png"), Vector2(3400, -280), -1, true).rotation_degrees = 180.0
	spr(wrong, "WallWheelchair", tex(GEN + "wheelchair.png"), Vector2(3664, -60), -1, true).rotation_degrees = -90.0
	spr(wrong, "CeilingChair", tex(GEN + "chair.png"), Vector2(3300, -292), -1, true).rotation_degrees = 180.0
	# atmosphere
	var tint := ColorRect.new()
	tint.position = Vector2(3232, -368)
	tint.size = Vector2(448, 528)
	tint.color = Color(0.78, 0.66, 0.92)
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	tint.material = mat
	tint.z_index = 30
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(r, tint, "Tint")
	var vig := spr(r, "Vignette", radial(128, Color(0, 0, 0, 0), Color(0.03, 0.0, 0.06, 0.75)), Vector2(3456, -104), 31, true)
	vig.scale = Vector2(448.0 / 128.0 * 1.25, 528.0 / 128.0 * 1.25)
	var dust := CPUParticles2D.new()
	dust.position = Vector2(3456, -72)
	dust.amount = 80
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.texture = tex(GEN + "mote.png")
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(224, 232)
	dust.direction = Vector2(0, -1)
	dust.spread = 30.0
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 7.0
	dust.gravity = Vector2(0, -3)
	dust.color = Color(1, 1, 1, 0.5)
	dust.z_index = 29
	add(r, dust, "Dust")
	var lights := Node2D.new()
	add(r, lights, "Lights")
	light(lights, "SickLight1", Vector2(3300, -200), 220, Color(0.6, 1.0, 0.7), 0.7)
	light(lights, "SickLight2", Vector2(3580, -10), 260, Color(0.75, 0.6, 1.0), 0.7)
	light(lights, "SickLight3", Vector2(3420, 120), 200, Color(0.6, 1.0, 0.7), 0.7)
	r.set_script(load("res://scripts/uncanny_room.gd"))


# ----------------------------------------------------------------- Room 6: the 10-second loop ward
func key(a: Animation, path: String, keys: Array, discrete := false) -> void:
	var tr := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tr, NodePath(path))
	if discrete:
		a.value_track_set_update_mode(tr, Animation.UPDATE_DISCRETE)
	for k in keys:
		a.track_insert_key(tr, k[0], k[1])


func room6(rooms: Node2D) -> void:
	var r := Node2D.new()
	add(rooms, r, "Room6_TimeLoopWard")
	note(r, "ROOM 6 - Ward stuck in a 10-second loop\nBed rolls, curtain opens, nurse drops her tray, clock turns,\nexit door is open from 7.0s to 8.4s. LoopPlayer drives it all;\nRoom6.loop_speed changes the speed of the whole room.", Vector2(3816, -28))
	marker(r, "LoopClock", Vector2(4128, -8))
	var glow := spr(r, "ClockGlow", radial(56, Color(1, 0.9, 0.4, 0.7), Color(1, 0.9, 0.4, 0)), Vector2(4128, -8), -1, true)
	glow.set_script(load("res://scripts/pulse.gd"))
	glow.set("scale_amount", 0.1)
	clock(r, "BigClock", 32, Vector2(4128, -8))
	var bed_tex := tex(GEN + "bed_side.png")
	var bed := anim_sprite(r, "BedA", frames(bed_tex, 64, 32, [["roll", [0, 1], 8.0, true]]), Vector2(3830, 32), "roll", 1)
	bed.speed_scale = 0.0
	spr(r, "BedB", atlas(bed_tex, Rect2(0, 0, 64, 32)), Vector2(4220, 32), 1)
	spr(r, "IVStand", tex(GEN + "iv_stand.png"), Vector2(4288, 16), 1)
	spr(r, "HeartMonitor", tex(GEN + "heart_monitor.png"), Vector2(4196, -12), 0)
	spr(r, "Chair", tex(GEN + "chair.png"), Vector2(3980, 40), 0)
	var csf := frames(tex(GEN + "curtain_side.png"), 48, 80, [["slide", [0, 1, 2, 3], 1.0, false]])
	var cur := anim_sprite(r, "Curtain", csf, Vector2(4228, -32), "", 3)
	var cur2 := anim_sprite(r, "CurtainOpen", csf, Vector2(3912, -32), "", 3)
	cur2.frame = 3
	var nurse := spr(r, "Nurse", tex(GEN + "nurse_tray.png"), Vector2(4380, 12), 4)
	nurse.hframes = 3
	nurse.flip_h = true   # drawn facing right; she walks left
	var tray := spr(r, "Tray", tex(GEN + "tray_full.png"), Vector2(4302, 27), 4); tray.visible = false; tray.flip_h = true
	var cup := spr(r, "Cup", tex(GEN + "cup.png"), Vector2(4318, 52), 4); cup.visible = false
	var plate := spr(r, "Plate", tex(GEN + "plate.png"), Vector2(4320, 55), 4); plate.visible = false
	var apple := spr(r, "Apple", tex(GEN + "apple.png"), Vector2(4320, 52), 4); apple.visible = false
	var ex := Node2D.new()
	ex.position = Vector2(4448, 0)
	add(r, ex, "ExitDoor")
	spr(ex, "Door", tex(GEN + "ward_door.png"), Vector2.ZERO)
	var eb := StaticBody2D.new(); add(ex, eb, "Body"); rect_shape(eb, "Shape", Vector2(10, 64), Vector2(8, 32))
	var flash := ColorRect.new()
	flash.position = Vector2(3808, -32)
	flash.size = Vector2(704, 96)
	flash.color = Color(0.85, 0.92, 1, 0)
	flash.z_index = 40
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(r, flash, "RewindFlash")

	var a := Animation.new()
	a.length = 10.0
	a.loop_mode = Animation.LOOP_LINEAR
	key(a, "BedA:position", [[0.0, Vector2(3830, 32)], [0.6, Vector2(3830, 32)], [3.4, Vector2(3990, 32)], [10.0, Vector2(3990, 32)]])
	key(a, "BedA:speed_scale", [[0.0, 0.0], [0.6, 1.0], [3.4, 0.0]], true)
	key(a, "Curtain:frame", [[0.0, 0], [1.5, 1], [1.75, 2], [2.0, 3]], true)
	key(a, "Nurse:position", [[0.0, Vector2(4380, 12)], [3.0, Vector2(4300, 12)], [10.0, Vector2(4300, 12)]])
	var nf := []
	for i in 13:
		nf.append([i * 0.25, i % 2])
	nf.append([3.2, 0])
	nf.append([5.0, 2])
	key(a, "Nurse:frame", nf, true)
	key(a, "Tray:visible", [[0.0, false], [5.0, true]], true)
	key(a, "Tray:texture", [[0.0, tex(GEN + "tray_full.png")], [5.45, tex(GEN + "tray.png")]], true)
	key(a, "Tray:position", [[5.0, Vector2(4302, 27)], [5.15, Vector2(4296, 22)], [5.44, Vector2(4288, 52)], [5.45, Vector2(4288, 58)], [10.0, Vector2(4288, 58)]])
	key(a, "Tray:rotation", [[5.0, 0.0], [5.44, -0.5], [5.6, -0.12], [10.0, -0.12]])
	for it in [["Cup", Vector2(4292, 50), Vector2(4276, 40), Vector2(4264, 56)], ["Apple", Vector2(4298, 50), Vector2(4314, 38), Vector2(4330, 57)], ["Plate", Vector2(4296, 55), Vector2(4290, 52), Vector2(4282, 59)]]:
		key(a, it[0] + ":visible", [[0.0, false], [5.45, true]], true)
		key(a, it[0] + ":position", [[5.45, it[1]], [5.65, it[2]], [5.9, it[3]], [10.0, it[3]]])
	key(a, "BigClock/Second:rotation", [[0.0, 0.0], [10.0, TAU]])
	key(a, "BigClock/Minute:rotation", [[0.0, 1.0], [10.0, 1.0 + TAU / 6.0]])
	key(a, "BigClock/Hour:rotation", [[0.0, 5.2], [10.0, 5.2 + TAU / 72.0]])
	key(a, "ExitDoor/Door:position", [[0.0, Vector2.ZERO], [6.6, Vector2.ZERO], [7.0, Vector2(0, -60)], [8.2, Vector2(0, -60)], [8.6, Vector2.ZERO]])
	key(a, "ExitDoor/Body/Shape:disabled", [[0.0, false], [7.0, true], [8.4, false]], true)
	key(a, "RewindFlash:color", [[0.0, Color(0.85, 0.92, 1, 0.6)], [0.35, Color(0.85, 0.92, 1, 0)], [9.5, Color(0.85, 0.92, 1, 0)], [9.95, Color(0.85, 0.92, 1, 0.85)], [10.0, Color(0.85, 0.92, 1, 0.6)]])
	var lib := AnimationLibrary.new()
	lib.add_animation("loop", a)
	var ap := AnimationPlayer.new()
	add(r, ap, "LoopPlayer")
	ap.add_animation_library("", lib)
	ap.autoplay = "loop"
	marker(r, "ExitBeyond", Vector2(4500, 64))
	r.set_script(load("res://scripts/time_loop_room.gd"))


# ----------------------------------------------------------------- lighting helpers
## Darkening layer for a room: a vertical gradient multiplied over everything (darker at the ceiling and floor).
func shade(parent: Node, n: String, r: Rect2, top: Color, mid: Color, bot: Color) -> Sprite2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([top, mid, bot])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 4
	t.height = 64
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	var s := spr(parent, n, t, r.position, 30)
	s.scale = r.size / Vector2(4, 64)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	s.material = m
	return s


## Ceiling light: a half-ellipse of light spreading down from pos (w wide, depth deep).
func cone_light(parent: Node, n: String, pos: Vector2, w: int, depth: int, color: Color, energy: float) -> PointLight2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = w
	t.height = depth * 2
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(1.0, 0.0)
	var l := PointLight2D.new()
	l.texture = t
	l.offset = Vector2(0, depth)
	l.color = color
	l.energy = energy
	l.position = pos
	add(parent, l, n)
	return l


## Strip light fixture on the ceiling + its light. Returns the light.
func strip_light(parent: Node, n: String, pos: Vector2, color: Color, energy: float, depth := 110, flicker := false) -> PointLight2D:
	var holder := Node2D.new()
	holder.position = pos
	add(parent, holder, n)
	spr(holder, "Fixture", tex(GEN + "strip_light.png"), Vector2(-16, 0), 5)
	var glow := spr(holder, "Glow", radial(48, Color(1, 1, 0.9, 0.5), Color(1, 1, 0.9, 0)), Vector2(0, 6), 31, true)
	glow.scale = Vector2(1.4, 0.5)
	var l := cone_light(holder, "Light", Vector2(0, 5), 190, depth, color, energy)
	if flicker:
		l.set_script(load("res://scripts/flicker_light.gd"))
		l.set("fixture_path", NodePath("../Fixture"))
	return l


## Daylight falling from a back-wall window: soft slanted beam, warm pool on the floor and drifting dust.
func window_shaft(parent: Node, n: String, win: Rect2, floor_y: float, color: Color, slant := 0.45, strength := 0.16) -> void:
	var holder := Node2D.new()
	add(parent, holder, n)
	var x0 := win.position.x + 4.0
	var x1 := win.end.x - 4.0
	var y0 := win.position.y + 4.0
	var dx := (floor_y - y0) * slant
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1 + dx, floor_y), Vector2(x0 + dx, floor_y)])
	var ct := Color(color.r, color.g, color.b, strength)
	var cb := Color(color.r, color.g, color.b, strength * 0.15)
	p.vertex_colors = PackedColorArray([ct, ct, cb, cb])
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	p.z_index = 31
	add(holder, p, "Beam")
	var pool := light(holder, "FloorPool", Vector2((x0 + x1) / 2.0 + dx, floor_y - 6), int((x1 - x0) * 2.4), color, 0.3)
	pool.scale = Vector2(1.0, 0.55)
	var wl := light(holder, "WindowGlow", win.get_center(), int(win.size.x * 2.0), color, 0.2)
	wl.scale = Vector2(1.0, 0.8)
	var d := CPUParticles2D.new()
	d.position = Vector2((x0 + x1) / 2.0 + dx / 2.0, (y0 + floor_y) / 2.0)
	d.amount = 12
	d.lifetime = 7.0
	d.preprocess = 7.0
	d.texture = tex(GEN + "mote.png")
	d.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	d.emission_rect_extents = Vector2((x1 - x0) / 2.0, (floor_y - y0) / 2.0 - 4.0)
	d.direction = Vector2(0.4, 1)
	d.spread = 40.0
	d.gravity = Vector2.ZERO
	d.initial_velocity_min = 1.5
	d.initial_velocity_max = 4.0
	d.color = Color(1, 0.97, 0.85, 0.55)
	d.z_index = 31
	add(holder, d, "Dust")


# ----------------------------------------------------------------- lighting (all rooms except Room 5, which has its own)
func lighting(root: Node) -> void:
	var L := Node2D.new()
	add(root, L, "Lighting")
	# shade colours: ceiling / middle / floor (multiplied, so 1.0 = untouched)
	var ward := [Color(0.44, 0.46, 0.57), Color(0.66, 0.67, 0.77), Color(0.55, 0.56, 0.67)]
	var lab := [Color(0.38, 0.42, 0.54), Color(0.60, 0.64, 0.75), Color(0.50, 0.54, 0.65)]
	var dusk := [Color(0.45, 0.41, 0.50), Color(0.72, 0.65, 0.68), Color(0.58, 0.52, 0.58)]
	var dark := [Color(0.40, 0.42, 0.52), Color(0.50, 0.52, 0.62), Color(0.44, 0.46, 0.56)]
	var fluoro := Color(0.86, 0.96, 1.0)
	var warm := Color(1.0, 0.88, 0.68)
	var sun := Color(1.0, 0.95, 0.80)

	var r1 := Node2D.new(); add(L, r1, "Room1")
	shade(r1, "ShadeLow", Rect2(16, -128, 224, 128), lab[0], lab[1], lab[2])
	shade(r1, "ShadeLab", Rect2(240, -256, 528, 256), lab[0], lab[1], lab[2])
	strip_light(r1, "CeilingLight1", Vector2(128, -128), fluoro, 0.35)
	strip_light(r1, "UnderBooth1", Vector2(410, -144), fluoro, 0.32, 120)
	strip_light(r1, "UnderBooth2", Vector2(590, -144), fluoro, 0.32, 120, true)
	strip_light(r1, "DoorLight", Vector2(720, -256), fluoro, 0.32, 200)
	cone_light(r1, "BoothLight", Vector2(488, -256), 300, 90, warm, 0.32)

	var r2 := Node2D.new(); add(L, r2, "Room2")
	shade(r2, "Shade", Rect2(768, -112, 752, 112), ward[0], ward[1], ward[2])
	shade(r2, "ShaftShade", Rect2(1520, -416, 64, 416), dark[0], dark[1], dark[2])
	strip_light(r2, "CeilingLight", Vector2(930, -112), fluoro, 0.32)
	cone_light(r2, "LampFixtureLight", Vector2(1352, -106), 180, 100, warm, 0.28)
	window_shaft(r2, "WindowLeftLight", Rect2(812, -104, 64, 44), 0.0, sun)
	window_shaft(r2, "WindowRightLight", Rect2(1400, -104, 64, 44), 0.0, sun)
	cone_light(r2, "LiftLight", Vector2(1552, -416), 90, 420, fluoro, 0.25)

	var r3 := Node2D.new(); add(L, r3, "Room3")
	shade(r3, "Shade", Rect2(1584, -288, 656, 96), ward[0], ward[1], ward[2])
	strip_light(r3, "CeilingLight1", Vector2(1700, -288), fluoro, 0.35)
	strip_light(r3, "CeilingLight2", Vector2(1900, -288), fluoro, 0.35)
	strip_light(r3, "CeilingLight3", Vector2(2100, -288), fluoro, 0.35, 110, true)
	var vend := light(r3, "VendingGlow", Vector2(2056, -224), 90, Color(0.6, 0.85, 1.0), 0.4)
	vend.scale = Vector2(0.8, 1.0)

	var c34 := Node2D.new(); add(L, c34, "Corridor3to4")
	shade(c34, "Shade", Rect2(2240, -256, 144, 64), ward[0], ward[1], ward[2])
	cone_light(c34, "Light", Vector2(2312, -252), 170, 80, warm, 0.32)

	var r4 := Node2D.new(); add(L, r4, "Room4")
	shade(r4, "Shade", Rect2(2384, -384, 640, 192), ward[0], ward[1], ward[2])
	window_shaft(r4, "HighWindowLeftLight", Rect2(2420, -360, 64, 44), -192.0, sun, 0.45, 0.13)
	window_shaft(r4, "HighWindowRightLight", Rect2(2580, -360, 64, 44), -192.0, sun, 0.45, 0.13)
	cone_light(r4, "CeilingLight1", Vector2(2472, -378), 220, 200, fluoro, 0.28)
	cone_light(r4, "CeilingLight2", Vector2(2728, -378), 220, 200, fluoro, 0.28)
	strip_light(r4, "PillarLight", Vector2(2900, -384), fluoro, 0.3, 200, true)
	shade(r4, "DuctShade", Rect2(3024, -368, 208, 64), dark[0], dark[1], dark[2])

	var st := Node2D.new(); add(L, st, "Stairs5to6")
	shade(st, "Shade", Rect2(3680, 0, 128, 160), dark[0], dark[1], dark[2])
	cone_light(st, "Light", Vector2(3744, 0), 160, 120, warm, 0.28)

	var r6 := Node2D.new(); add(L, r6, "Room6")
	shade(r6, "Shade", Rect2(3808, -32, 704, 96), dusk[0], dusk[1], dusk[2])
	strip_light(r6, "CeilingLight1", Vector2(3990, -32), warm, 0.32, 100)
	strip_light(r6, "CeilingLight2", Vector2(4360, -32), warm, 0.32, 100)
	window_shaft(r6, "WindowLight", Rect2(3856, -32, 32, 32), 64.0, Color(1.0, 0.78, 0.55), 0.55, 0.2)
