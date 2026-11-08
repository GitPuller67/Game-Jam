extends PointLight2D
## A light that occasionally stutters off (tired fluorescent tube). Dims its fixture sprite too.

@export var fixture_path: NodePath
@export var flicker_chance := 0.015   # chance per frame of a flicker starting
var base_energy := 0.0
var off_time := 0.0
@onready var fixture: CanvasItem = get_node_or_null(fixture_path) as CanvasItem


func _ready() -> void:
	base_energy = energy


func _process(delta: float) -> void:
	if off_time > 0.0:
		off_time -= delta
		energy = base_energy * 0.15
		if fixture:
			fixture.modulate = Color(0.55, 0.55, 0.6)
	else:
		energy = base_energy
		if fixture:
			fixture.modulate = Color.WHITE
		if randf() < flicker_chance:
			off_time = randf_range(0.04, 0.22)
