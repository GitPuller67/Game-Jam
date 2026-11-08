extends Node2D
## The hospital level: the map (scenes/Map.tscn) played with the real Father, Baby + bubble, Enemy and HUD.
##  - The Father starts standing on the map's PlayerStart marker in Room 1.
##  - Hover the bubble over the swinging lamp, the lift, a falling Room 4 chunk, a Room 5 floater or the Room 6 clock
##    and hold controller 2's right stick left to slow it down (the baby's time power).
##  - Press Y with the bubble over Room 1's keypad to open the exit door.
##  - Room 4's ceiling starts falling in when the Father walks into Room 4 (slow a chunk, jump on it).
##  - Touching a Room 5 floater calls take_damage(1) on the Father if he has that method.

@export var slow_factor := 0.25
@export var slow_duration := 4.0
## Room 1's door code. The doctor types it forwards; the player must enter it backwards
## (rewinding the doctor shows it in that order).
@export var door_code := "4719"
## Overrides the Father camera's zoom in this level (his scene uses 5).
@export var camera_zoom := 3.0
## Play the opening cutscene (the Father walks in and picks up the baby) before handing over.
@export var play_intro := true
## How quickly the camera's top/bottom limits follow the room heights (higher = snappier).
@export var camera_limit_speed := 6.0

@onready var map: Node2D = $Map
@onready var father: Node2D = $Father

# Camera clamping: the map's outer walls left/right, and per tile column the
# top and bottom of the Solid layer (rooms sit at different heights).
var _cam: Camera2D
var _keypad_doctor: KeypadDoctor
var _solid: TileMapLayer
var _col_top := {}
var _col_bottom := {}
var _limit_top := 0.0
var _limit_bottom := 0.0


func _ready() -> void:
	_place_father()
	map.get_node("Rooms/Room4_Collapse").set("demo_autoplay", false)   # wait for the trigger instead
	var cam := father.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.zoom = Vector2.ONE * camera_zoom
	_setup_camera_limits()
	_setup_room1()
	_setup_ammo_hud()
	_add_scalpel_pickups()
	_start_intro()
	_add_time_targets()
	_hook_hazards()
	_add_room4_trigger()
	_setup_health()
	_setup_energy()
	_add_end_trigger()
	# Restarted from the end screen: go straight into the game, no main menu.
	if EndScreen.skip_menu_once:
		EndScreen.skip_menu_once = false
		var menu := get_node_or_null("MainMenu")
		if menu and menu.has_method("_start_game"):
			menu.call_deferred("_start_game")


func _process(delta: float) -> void:
	_update_camera_limits(1.0 - exp(-camera_limit_speed * delta))


## Keeps the Father's camera inside the map so it never shows empty space past the walls.
func _setup_camera_limits() -> void:
	_cam = father.get_node_or_null("Camera2D") as Camera2D
	_solid = map.get_node_or_null("Solid") as TileMapLayer
	if _cam == null or _solid == null or _solid.tile_set == null:
		return
	var half := Vector2(_solid.tile_set.tile_size) / 2.0
	var left := INF
	var right := -INF
	for cell in _solid.get_used_cells():
		var centre := _solid.to_global(_solid.map_to_local(cell))
		left = minf(left, centre.x - half.x)
		right = maxf(right, centre.x + half.x)
		_col_top[cell.x] = minf(_col_top.get(cell.x, INF), centre.y - half.y)
		_col_bottom[cell.x] = maxf(_col_bottom.get(cell.x, -INF), centre.y + half.y)
	_cam.limit_left = floori(left)
	_cam.limit_right = ceili(right)
	_update_camera_limits(1.0)   # start already clamped, no sweep on the first frame


## Sets the camera's top/bottom limits from the columns that are on screen.
## weight 1.0 snaps; smaller values ease towards the new limits.
func _update_camera_limits(weight: float) -> void:
	if _cam == null or _col_top.is_empty():
		return
	var view := get_viewport().get_visible_rect().size / _cam.zoom
	var half_w := view.x / 2.0
	# Where the camera will be horizontally once it's clamped to the side walls.
	var cx := clampf(father.global_position.x, _cam.limit_left + half_w, _cam.limit_right - half_w)
	var first := _solid.local_to_map(_solid.to_local(Vector2(cx - half_w, 0))).x
	var last := _solid.local_to_map(_solid.to_local(Vector2(cx + half_w, 0))).x
	var top := INF
	var bottom := -INF
	for col in range(first, last + 1):
		if _col_top.has(col):
			top = minf(top, _col_top[col])
			bottom = maxf(bottom, _col_bottom[col])
	if top == INF:
		return
	# A room shorter than the screen: centre it instead of pinning it to the top.
	var spare := view.y - (bottom - top)
	if spare > 0.0:
		top -= spare / 2.0
		bottom += spare / 2.0
	_limit_top = lerpf(_limit_top, top, weight)
	_limit_bottom = lerpf(_limit_bottom, bottom, weight)
	_cam.limit_top = roundi(_limit_top)
	_cam.limit_bottom = roundi(_limit_bottom)


## Stands the Father on the map's PlayerStart marker (feet on the marker), so moving the
## marker in Map.tscn moves the spawn.
func _place_father() -> void:
	var start := map.get_node_or_null("Rooms/Room1_FindingBaby/PlayerStart") as Node2D
	if start == null:
		push_warning("HospitalLevel: no PlayerStart marker in the map, Father stays where he is.")
		return
	var feet := 0.0
	var body := father.get_node_or_null("StandingCollision") as CollisionShape2D
	if body and body.shape:
		feet = (body.transform * body.shape.get_rect()).end.y   # bottom of his collision box
	father.global_position = start.global_position - Vector2(0, feet)


func _add_time_targets() -> void:
	var rooms := map.get_node("Rooms")
	# Room 2: swinging lamp (the area rides on the lamp head)
	var lamp := rooms.get_node("Room2_Corridor/SwingingLamp")
	_target(lamp.get_node("Lamp"), _circle(14), Vector2(0, 6), [lamp], lamp.get_node("Lamp")) 		.add_rewind(lamp, PackedStringArray(["t"]))
	# Room 2: the lift car
	var lift := rooms.get_node("Room2_Corridor/Elevator")
	var lt := _target(lift.get_node("Car"), _rect(Vector2(64, 76)), Vector2(32, -38), [lift], lift.get_node("Car"))
	lt.add_rewind(lift, PackedStringArray(["t", "moving", "target", "from_y", "wait"]))
	lt.add_rewind(lift.get_node("Car"), PackedStringArray(["position"]), &"")
	# Room 4: each falling chunk of ceiling makes its own time target (FallingDebris)
	# Room 5: every floating object
	for f in rooms.get_node("Room5_UncannyDrop/Floaters").get_children():
		_target(f, _circle(14), Vector2.ZERO, [f], f).add_rewind(f, PackedStringArray(["t"]))
	# Room 6: the big clock slows the whole 10-second loop
	var ward := rooms.get_node("Room6_TimeLoopWard")
	var clock := ward.get_node("BigClock")
	var t := _target(ward, _circle(18), clock.position, [ward], clock)
	t.property = &"loop_speed"
	# rewinding the clock plays the whole ward loop backwards
	t.add_rewind(ward, PackedStringArray(), &"loop_speed", Rewinder.Mode.REVERSE)
	# the enemy can be slowed, sped up and rewound too
	for child in get_children():
		if child is Enemy:
			_enemy_time_target(child)


func _enemy_time_target(enemy: Node2D) -> void:
	_target(enemy, _rect(Vector2(20, 48)), Vector2(0, -12), [enemy], enemy.get_node("AnimatedSprite2D")) 		.add_rewind(enemy, PackedStringArray(["global_position", "velocity"]))


func _target(parent: Node, shape: Shape2D, offset: Vector2, what: Array, tint: CanvasItem) -> TimeSlowTarget:
	var nodes: Array[Node] = []
	for n in what:
		nodes.append(n)
	var t := TimeSlowTarget.make(parent, shape, offset, nodes, tint)
	t.slow_factor = slow_factor
	t.slow_duration = slow_duration
	return t


func _circle(r: float) -> CircleShape2D:
	var c := CircleShape2D.new()
	c.radius = r
	return c


func _rect(s: Vector2) -> RectangleShape2D:
	var r := RectangleShape2D.new()
	r.size = s
	return r


func _hook_hazards() -> void:
	for h in get_tree().get_nodes_in_group("hazard"):
		var area := h as Area2D
		if area:
			area.collision_mask = 1          # detect the Father's body (layer 1)
			area.monitoring = true
			area.body_entered.connect(_on_hazard_touched.bind(area))


func _on_hazard_touched(body: Node, area: Area2D) -> void:
	if body == father and father.has_method("take_damage"):
		father.call("take_damage", 1, area.global_position)


func _add_room4_trigger() -> void:
	var room4 := map.get_node("Rooms/Room4_Collapse")
	var trig := Area2D.new()
	trig.name = "Room4Trigger"
	trig.position = Vector2(2420, -224)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(32, 64)
	cs.shape = r
	trig.add_child(cs)
	add_child(trig)
	trig.body_entered.connect(func(body: Node) -> void:
		if body == father:
			room4.call("start_collapse")
			trig.queue_free())


## Room 1: the glass pod opens as the Father walks up, and the bubble works the keypad to open the exit door.
func _setup_room1() -> void:
	var r1 := map.get_node("Rooms/Room1_FindingBaby")
	var pod := r1.get_node("BabyPod")
	var trig := Area2D.new()
	trig.name = "PodTrigger"
	trig.position = Vector2(616, -48)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(260, 96)
	cs.shape = shape
	trig.add_child(cs)
	add_child(trig)
	trig.body_entered.connect(func(body: Node) -> void:
		if body != father:
			return
		trig.queue_free()
		pod.get_node("PodDoor").call("open")
		# the right-hand glass panel slides up into the pod roof too
		var wall := pod.get_node("GlassWall") as Node2D
		create_tween().tween_property(wall, "position:y", wall.position.y - 94.0, 0.6).set_trans(Tween.TRANS_QUAD)
		(pod.get_node("GlassWallBody/Shape") as CollisionShape2D).set_deferred("disabled", true))

	var keypad := r1.get_node("Keypad") as AnimatedSprite2D
	var exit_door := r1.get_node("ExitDoor")
	# a doctor walks up, types the code and leaves through the door; rewind him to see it again
	var doctor := KeypadDoctor.new()
	doctor.name = "KeypadDoctorScene"
	doctor.code = door_code
	doctor.keypad = keypad
	doctor.door = exit_door
	doctor.wait_for_begin = play_intro   # his scene follows the intro
	r1.add_child(doctor)
	_keypad_doctor = doctor
	# once he's after the Father he's a normal enemy: slow / speed up / rewind him like the others
	doctor.turned_hostile.connect(_enemy_time_target)
	# the keypad screen (type the code backwards)
	var ui := KeypadUI.new()
	ui.name = "KeypadUI"
	ui.code = door_code
	add_child(ui)
	var btn := BubbleButton.new()
	btn.one_shot = false
	btn.name = "KeypadButton"
	btn.position = keypad.position + Vector2(5, 7)
	var bcs := CollisionShape2D.new()
	var bshape := RectangleShape2D.new()
	bshape.size = Vector2(16, 20)
	bcs.shape = bshape
	btn.add_child(bcs)
	r1.add_child(btn)
	btn.pressed.connect(func() -> void:
		if not exit_door.get("is_open"):
			ui.open.call_deferred())   # deferred: don't pause the game in the middle of input handling
	ui.solved.connect(func() -> void:
		keypad.play("unlocked")
		doctor.turn_hostile()   # the door opening gives the Father away
		exit_door.call("open"))


## The opening: the Father walks in and picks up the baby, then the keypad doctor's scene starts.
func _start_intro() -> void:
	if not play_intro:
		return
	var intro := IntroCutscene.new()
	intro.name = "Intro"
	intro.father = father as Father
	intro.crib = map.get_node("Rooms/Room1_FindingBaby/BabyPod/BabyCrib") as Sprite2D
	intro.finished.connect(_keypad_doctor.begin)
	add_child(intro)


# --- Scalpels: pickups, HUD count + pickup popup ---
## Scalpels left on the floor (feet positions), 5 each. The Father starts with none.
## 30 in all: each shielded enemy takes 3 (a sped-up one for the shield, then 2), and there are 4
## (the keypad doctor + Room 3's three), so there's plenty to spare for misses.
const SCALPEL_PICKUPS: Array[Vector2] = [
	Vector2(750, 0),        # Room 1, just before the keypad door
	Vector2(960, 0),        # Room 2, where the keypad doctor waits
	Vector2(1440, 0),       # Room 2, before the lift
	Vector2(1640, -192),    # Room 3, on the way in
	Vector2(2035, -192),    # Room 3, between the guards
	Vector2(2300, -192),    # corridor 3 -> 4
]


func _add_scalpel_pickups() -> void:
	var holder := Node2D.new()
	holder.name = "ScalpelPickups"
	add_child(holder)
	for i in SCALPEL_PICKUPS.size():
		var pickup := ScalpelPickup.new()
		pickup.name = "ScalpelPickup%d" % (i + 1)
		pickup.position = SCALPEL_PICKUPS[i]
		pickup.picked_up.connect(_show_pickup_popup)
		holder.add_child(pickup)


func _setup_ammo_hud() -> void:
	if father.has_signal("ammo_changed"):
		father.connect("ammo_changed", _on_ammo_changed)
	_on_ammo_changed(int(father.get("current_ammo")))


## The Shoot prompt only shows once he has scalpels, with how many are left.
func _on_ammo_changed(ammo: int) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("set_ammo"):
		hud.set_ammo(ammo)


func _show_pickup_popup(amount: int) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("show_popup"):
		hud.show_popup("PICKED UP %d SCALPELS" % amount)


# --- Health bar + respawning ---
## Where the Father comes back after dying: the start of the furthest room he has reached.
## [x where the room begins, respawn point (feet)]
const CHECKPOINTS := [
	[0.0, Vector2(40, 0)],          # Room 1
	[784.0, Vector2(820, 0)],       # Room 2
	[1600.0, Vector2(1620, -192)],  # Room 3
	[2384.0, Vector2(2410, -192)],  # Room 4
	[3232.0, Vector2(3200, -304)],  # Room 5 (end of the duct, above the drop)
	[3552.0, Vector2(3574, 560)],   # Room 6 (below the long Room 5 drop)
]
var _checkpoint := Vector2(40, 0)


func _setup_energy() -> void:
	var bubble := father.find_child("Bubble", true, false)
	if bubble and bubble.has_signal("energy_changed"):
		bubble.connect("energy_changed", _on_energy_changed)


func _on_energy_changed(value: float, max_value: float) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("set_energy"):
		var bubble := father.find_child("Bubble", true, false)
		hud.set_energy(100.0 * value / maxf(max_value, 1.0), bubble != null and bool(bubble.get("exhausted")))


func _setup_health() -> void:
	if father.has_signal("health_changed"):
		father.connect("health_changed", _on_health_changed)
	if father.has_signal("died"):
		father.connect("died", _on_father_died)


## Room 5's shaft: a floaty fall (capped speed) where slowing Dad slows his fall but not his steering.
const ROOM5_SHAFT := Rect2(3232, -368, 192, 1024)
@export var room5_max_fall := 420.0


func _physics_process(_delta: float) -> void:
	var in_shaft := ROOM5_SHAFT.has_point(father.global_position)
	father.set("max_fall_speed", room5_max_fall if in_shaft else INF)
	father.set("steer_ignores_time_scale", in_shaft)
	for c in CHECKPOINTS:
		if father.global_position.x >= c[0] and c[1].x > _checkpoint.x:
			_checkpoint = c[1]


func _on_health_changed(new_health: int, max_health: int) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("set_health"):
		hud.set_health(100.0 * new_health / maxf(max_health, 1))


func _on_father_died() -> void:
	await get_tree().create_timer(1.2, false).timeout
	var feet := 0.0
	var body := father.get_node_or_null("StandingCollision") as CollisionShape2D
	if body and body.shape:
		feet = (body.transform * body.shape.get_rect()).end.y
	father.call("respawn", _checkpoint - Vector2(0, feet + 1))


# --- The end (for now): past Room 6's exit door ---
func _add_end_trigger() -> void:
	var screen := EndScreen.new()
	screen.name = "EndScreen"
	add_child(screen)
	var trig := Area2D.new()
	trig.name = "EndTrigger"
	trig.position = Vector2(3916, 528)     # the nook just past Room 6's exit door
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(32, 64)
	cs.shape = r
	trig.add_child(cs)
	add_child(trig)
	trig.body_entered.connect(func(body: Node) -> void:
		if body == father:
			screen.show_end())

