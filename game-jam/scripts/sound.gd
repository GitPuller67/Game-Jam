extends Node
## Game sounds (autoload "Sound"). Hooks itself into the game, so no other script calls it:
##  - The theme song loops the whole time, through menus and pauses too.
##  - knife_throw plays when the Father throws a scalpel.
##  - knife_hit plays when any scalpel hits something (a wall, the floor, an enemy, the Father).
##  - door_open plays when Room 1's exit door is opened with the keypad code (the first door).
##  - baby_laugh plays at random times while the game is being played (not paused / in a menu).
## Call Sound.play_sfx(stream) from anywhere for other one-off sounds.

const THEME := preload("res://assets/audio/theme_song.mp3")
const KNIFE_THROW := preload("res://assets/audio/knife_throw.mp3")
const KNIFE_HIT := preload("res://assets/audio/knife_hit.mp3")
const DOOR_OPEN := preload("res://assets/audio/door_open.mp3")
const BABY_LAUGH := preload("res://assets/audio/baby_laugh.mp3")

@export var music_volume_db := -10.0
@export var throw_volume_db := -4.0
@export var hit_volume_db := -2.0
@export var door_volume_db := 0.0
@export var laugh_volume_db := 4.0
## Seconds of gameplay between baby laughs (picked at random in this range each time).
@export var laugh_min_gap := 15.0
@export var laugh_max_gap := 40.0

var music: AudioStreamPlayer
var _throw: AudioStreamPlayer
var _hit: AudioStreamPlayer
var _door: AudioStreamPlayer
var _laugh: AudioStreamPlayer
var _laugh_wait := 0.0


func _ready() -> void:
	# keep running while the game is paused (main menu, keypad, end screen)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var theme := THEME.duplicate() as AudioStreamMP3
	theme.loop = true
	music = _make_player(theme, music_volume_db, 1)
	_throw = _make_player(KNIFE_THROW, throw_volume_db, 4)
	_hit = _make_player(KNIFE_HIT, hit_volume_db, 4)
	_door = _make_player(DOOR_OPEN, door_volume_db, 1)
	_laugh = _make_player(BABY_LAUGH, laugh_volume_db, 1)
	music.play()
	_laugh_wait = randf_range(laugh_min_gap, laugh_max_gap)
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	# random baby laughs, only while actually playing
	if get_tree().paused:
		return
	_laugh_wait -= delta
	if _laugh_wait <= 0.0:
		_laugh.pitch_scale = randf_range(0.95, 1.08)
		_laugh.play()
		_laugh_wait = randf_range(laugh_min_gap, laugh_max_gap)


## Plays a one-off sound (not positional).
func play_sfx(stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _make_player(stream: AudioStream, volume_db: float, polyphony: int) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.max_polyphony = polyphony
	add_child(p)
	return p


# --- Hooking into the game ---
func _on_node_added(node: Node) -> void:
	if node is Bullet:
		var scalpel := node as Bullet
		if scalpel.shooter is Father:
			_throw.pitch_scale = randf_range(0.92, 1.08)
			_throw.play()
		scalpel.hit.connect(_on_scalpel_hit)
	elif node is KeypadUI:
		(node as KeypadUI).solved.connect(_door.play)


func _on_scalpel_hit(_body: Node2D) -> void:
	_hit.pitch_scale = randf_range(0.92, 1.08)
	_hit.play()
