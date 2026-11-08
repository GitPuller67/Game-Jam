extends Node2D
## Room 4: when every pillar has broken, the vent opens.
## demo_autoplay breaks the pillars one by one so you can watch it without a player.

@export var demo_autoplay := true
@export var demo_first_delay := 1.5
@export var demo_gap := 1.4

var remaining := 0
@onready var pillars: Node = $Pillars
@onready var vent: Node = $Vent


var _started := false


func _ready() -> void:
	for p in pillars.get_children():
		remaining += 1
		p.connect("broken", _on_pillar_broken)
	_autoplay.call_deferred()   # deferred so a level can switch demo_autoplay off in its own _ready


func _autoplay() -> void:
	if demo_autoplay:
		start_breaking()


## Break the columns one after another (the level calls this when the player walks in).
func start_breaking() -> void:
	if _started:
		return
	_started = true
	var d := demo_first_delay
	for p in pillars.get_children():
		get_tree().create_timer(d).timeout.connect(Callable(p, "break_pillar"))
		d += demo_gap


func _on_pillar_broken() -> void:
	remaining -= 1
	if remaining == 0:
		await get_tree().create_timer(1.0).timeout
		vent.call("open")
