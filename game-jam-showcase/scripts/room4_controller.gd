extends Node2D
## Room 4: the ceiling is coming down. When the Father walks in (start_collapse()), the vent in the
## top-right wall rattles open and chunks of ceiling keep dropping in a few columns in front of it.
## The columns drop in a steady left-to-right cascade, one chunk after the other.
## They fall too fast to stand on: the baby slows one down so the Father can jump onto it, ride it,
## and hop up to the next one / the open vent lid. Each chunk shatters on the floor (FallingDebris).
## Grit trickles from the ceiling just before each drop, as a warning.
## demo_autoplay starts it straight away, so you can watch it without a player.

@export var demo_autoplay := true
## x of each column chunks fall in (global). Chunks drop through these in order, then loop.
## The right-hand one is tucked against the vent lid (which starts at x 2962): from a slowed chunk
## there it's a jump almost straight up onto the lid.
@export var columns := PackedFloat32Array([2852.0, 2900.0, 2946.0])
## Seconds between successive drops in the cascade. A column only drops again once its previous
## chunk is gone, so a slowed chunk is safe to ride.
@export var drop_interval := 1.1
## Warning grit before each drop.
@export var warning_time := 0.5
@export var ceiling_y := -384.0
@export var floor_y := -192.0
@export var chunk_textures: Array[Texture2D] = [
	preload("res://assets/art/chunk_tall_1.png"),
	preload("res://assets/art/chunk_tall_2.png"),
	preload("res://assets/art/chunk_tall_3.png"),
	preload("res://assets/art/chunk_tall_4.png"),
]

@onready var vent: Node = $Vent

var _started := false
var _drop_timer := 0.0
var _next_column := 0
var _warned := false
var _live: Array[FallingDebris] = []   # each column's chunk that's still falling
var _debris: Node2D
var _mote: Texture2D


func _ready() -> void:
	_mote = load("res://assets/gen/mote.png")
	_debris = Node2D.new()
	_debris.name = "Debris"
	add_child(_debris)
	_autoplay.call_deferred()   # deferred so a level can switch demo_autoplay off in its own _ready


func _autoplay() -> void:
	if demo_autoplay:
		start_collapse()


## Start the collapse (the level calls this when the Father walks in).
func start_collapse() -> void:
	if _started or columns.is_empty():
		return
	_started = true
	get_tree().create_timer(0.6, false).timeout.connect(Callable(vent, "open"))
	_live.resize(columns.size())
	_next_column = 0
	_drop_timer = 0.8
	_warned = false


func _physics_process(delta: float) -> void:
	if not _started:
		return
	# Wait for this column's previous chunk to disappear before continuing the cascade.
	if is_instance_valid(_live[_next_column]):
		return
	_drop_timer -= delta
	if not _warned and _drop_timer <= warning_time:
		_warned = true
		_grit(columns[_next_column])
	if _drop_timer > 0.0:
		return
	_live[_next_column] = _drop(columns[_next_column])
	_next_column = (_next_column + 1) % columns.size()
	_drop_timer = drop_interval
	_warned = false


func _drop(x: float) -> FallingDebris:
	var chunk := FallingDebris.new()
	chunk.texture = chunk_textures.pick_random()
	chunk.floor_y = floor_y
	_debris.add_child(chunk)
	chunk.global_position = Vector2(x, ceiling_y + 2.0)
	return chunk


## A little trickle of grit from the ceiling where a chunk is about to come loose.
func _grit(x: float) -> void:
	var g := CPUParticles2D.new()
	g.global_position = Vector2(x, ceiling_y + 2.0)
	g.one_shot = true
	g.amount = 8
	g.lifetime = 0.9
	g.explosiveness = 0.3
	g.texture = _mote
	g.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	g.emission_rect_extents = Vector2(10, 1)
	g.direction = Vector2(0, 1)
	g.spread = 10.0
	g.gravity = Vector2(0, 120)
	g.initial_velocity_min = 10.0
	g.initial_velocity_max = 25.0
	g.color = Color(0.85, 0.85, 0.8, 0.9)
	g.finished.connect(g.queue_free)
	_debris.add_child(g)
	g.emitting = true
