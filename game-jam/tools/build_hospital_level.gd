extends SceneTree
## Builds res://levels/hospital_level.tscn: the hospital map + Father, Enemy, HUD and MainMenu.
##   godot --headless --path . --script res://tools/build_hospital_level.gd
## Re-running overwrites hospital_level.tscn (not the map or anyone else's scenes).


func _init() -> void:
	var root := Node2D.new()
	root.name = "HospitalLevel"
	root.set_script(load("res://scripts/hospital_level.gd"))

	# dark backdrop behind the map
	var bg_layer := CanvasLayer.new()
	bg_layer.name = "Backdrop"
	bg_layer.layer = -100
	root.add_child(bg_layer)
	bg_layer.owner = root
	var bg := ColorRect.new()
	bg.name = "Colour"
	bg.color = Color(0.055, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(bg)
	bg.owner = root

	var map: Node2D = load("res://scenes/Map.tscn").instantiate()
	map.name = "Map"
	root.add_child(map)
	map.owner = root

	var start: Node2D = map.get_node("Rooms/Room1_FindingBaby/PlayerStart")
	var father: Node2D = load("res://characters/father/father.tscn").instantiate()
	father.name = "Father"
	father.position = start.position + Vector2(0, -27)   # feet on the floor
	root.add_child(father)
	father.owner = root

	var guard: Node2D = map.get_node("Rooms/Room3_ShootingIntro/Guard1Spot")
	var enemy: Node2D = load("res://characters/enemy/enemy.tscn").instantiate()
	enemy.name = "Enemy"
	enemy.position = guard.position + Vector2(0, -30)
	root.add_child(enemy)
	enemy.owner = root

	var hud: Node = load("res://ui/hud.tscn").instantiate()
	hud.name = "HUD"
	root.add_child(hud)
	hud.owner = root
	var menu: Node = load("res://ui/main_menu.tscn").instantiate()
	menu.name = "MainMenu"
	root.add_child(menu)
	menu.owner = root
	menu.set("hud", hud)

	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed %d" % err)
	err = ResourceSaver.save(ps, "res://levels/hospital_level.tscn")
	print("SAVE ", err)
	root.free()
	quit()
