extends Node2D
## Hospital column that cracks, shakes and bursts, leaving ceiling + floor stumps and
## a floating chunk platform (child "Chunk"). Origin = top centre of the column.
## Call break_pillar(). time_scale slows the break (baby's time power).

signal broken

@export var auto_break_delay := -1.0   # >= 0: break by itself after this many seconds
@export var time_scale := 1.0

var is_broken := false
@onready var spr: AnimatedSprite2D = $Sprite
@onready var intact_shape: CollisionShape2D = $Body/Intact
@onready var top_shape: CollisionShape2D = $Body/TopStump
@onready var bottom_shape: CollisionShape2D = $Body/BottomStump
@onready var chunk: AnimatableBody2D = $Chunk
@onready var rubble: CPUParticles2D = $Rubble


func _ready() -> void:
	spr.play("intact")
	top_shape.disabled = true
	bottom_shape.disabled = true
	chunk.visible = false
	($Chunk/Shape as CollisionShape2D).disabled = true
	if auto_break_delay >= 0.0:
		get_tree().create_timer(auto_break_delay).timeout.connect(break_pillar)


func break_pillar() -> void:
	if is_broken:
		return
	is_broken = true
	spr.speed_scale = time_scale
	spr.play("break")
	await spr.animation_finished
	spr.play("broken")
	intact_shape.set_deferred("disabled", true)
	top_shape.set_deferred("disabled", false)
	bottom_shape.set_deferred("disabled", false)
	rubble.speed_scale = time_scale
	rubble.restart()
	chunk.visible = true
	($Chunk/Shape as CollisionShape2D).set_deferred("disabled", false)
	chunk.start()
	broken.emit()
