extends Node2D
## The hospital level: the map (scenes/Map.tscn) played with the real Father, Baby + bubble, Enemy and HUD.
##  - The Father starts standing on the map's PlayerStart marker in Room 1.
##  - Hover the bubble over the swinging lamp, the lift, a pillar, a Room 5 floater or the Room 6 clock
##    and hold controller 2's right stick left to slow it down (the baby's time power).
##  - Press Y with the bubble over Room 1's keypad to open the exit door.
##  - Room 4's columns start breaking when the Father walks into Room 4.
##  - Touching a Room 5 floater calls take_damage(1) on the Father if he has that method.

@export var slow_factor := 0.25
@export var slow_duration := 4.0
## Overrides the Father camera's zoom in this level (his scene uses 5).
@export var camera_zoom := 3.0
## How quickly the camera's top/bottom limits follow the room heights (higher = snappier).
@export var camera_limit_speed := 6.0

@onready var map: Node2D = $Map
@onready var father: Node2D = $Father

# Camera clamping: the map's outer walls left/right, and per tile column the
# top and bottom of the Solid layer (rooms sit at different heights).
var _cam: Camera2D
var _solid: TileMapLayer
var _col_top := {}
var _col_bottom := {}
var _limit_top := 0.0
var _limit_bottom := 0.0


func _ready() -> void:
	_place_father()
	map.get_node("Rooms/Room4_Pillars").set("demo_autoplay", false)   # wait for the trigger instead
	var cam := father.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.zoom = Vector2.ONE * camera_zoom
	_setup_camera_limits()
	_setup_room1()
	_add_time_targets()
	_hook_hazards()
	_add_room4_trigger()


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
	_target(lamp.get_node("Lamp"), _circle(14), Vector2(0, 6), [lamp], lamp.get_node("Lamp"))
	# Room 2: the lift car
	var lift := rooms.get_node("Room2_Corridor/Elevator")
	_target(lift.get_node("Car"), _rect(Vector2(64, 76)), Vector2(32, -38), [lift], lift.get_node("Car"))
	# Room 4: each column and its floating chunk
	for p in rooms.get_node("Room4_Pillars/Pillars").get_children():
		_target(p, _rect(Vector2(28, 192)), Vector2(0, 96), [p, p.get_node("Chunk")], p)
	# Room 5: every floating object
	for f in rooms.get_node("Room5_UncannyDrop/Floaters").get_children():
		_target(f, _circle(14), Vector2.ZERO, [f], f)
	# Room 6: the big clock slows the whole 10-second loop
	var ward := rooms.get_node("Room6_TimeLoopWard")
	var clock := ward.get_node("BigClock")
	var t := _target(ward, _circle(18), clock.position, [ward], clock)
	t.property = &"loop_speed"


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
			area.body_entered.connect(_on_hazard_touched)


func _on_hazard_touched(body: Node) -> void:
	if body == father and father.has_method("take_damage"):
		father.call("take_damage", 1)


func _add_room4_trigger() -> void:
	var room4 := map.get_node("Rooms/Room4_Pillars")
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
			room4.call("start_breaking")
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
	var btn := BubbleButton.new()
	btn.name = "KeypadButton"
	btn.position = keypad.position + Vector2(5, 7)
	var bcs := CollisionShape2D.new()
	var bshape := RectangleShape2D.new()
	bshape.size = Vector2(16, 20)
	bcs.shape = bshape
	btn.add_child(bcs)
	r1.add_child(btn)
	btn.pressed.connect(func() -> void:
		keypad.play("unlocked")
		exit_door.call("open"))
