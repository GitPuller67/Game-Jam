extends Node2D
## The hospital level: the map (scenes/Map.tscn) played with the real Father, Baby + bubble, Enemy and HUD.
##  - Hover the bubble over the swinging lamp, the lift, a pillar, a Room 5 floater or the Room 6 clock
##    and press interact to slow it down (the baby's time power).
##  - Room 4's columns start breaking when the Father walks into Room 4.
##  - Touching a Room 5 floater calls take_damage(1) on the Father if he has that method.

@export var slow_factor := 0.25
@export var slow_duration := 4.0
## Overrides the Father camera's zoom in this level (his scene uses 5).
@export var camera_zoom := 3.0

@onready var map: Node2D = $Map
@onready var father: Node2D = $Father


func _ready() -> void:
	map.get_node("Rooms/Room4_Pillars").set("demo_autoplay", false)   # wait for the trigger instead
	var cam := father.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.zoom = Vector2.ONE * camera_zoom
	_setup_room1()
	_add_time_targets()
	_hook_hazards()
	_add_room4_trigger()


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
