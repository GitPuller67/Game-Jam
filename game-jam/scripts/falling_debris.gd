class_name FallingDebris
extends AnimatableBody2D
## A chunk of ceiling falling in Room 4. Origin = the middle of its top surface.
## Too fast to use on its own: the baby slows it down (bubble + right stick left) so the Father can
## jump onto it and ride it down, then jump off it. Shatters on the floor.
## Landing on the Father while falling at speed hurts him (and shatters it).
## Its top is one-way, so it never shoves the Father around from below or the side.

@export var gravity := 252.0
@export var max_fall_speed := 72.0
## Where it shatters: the floor's y (global).
@export var floor_y := -192.0
@export var damage := 1
## It only hurts while falling at least this fast (so a slowed chunk is safe to stand under).
@export var hurt_speed := 48.0
@export var texture: Texture2D

## 1 = normal. The bubble changes this (slow / speed up).
## Slowing bites harder on debris (the factor is squared): slowed all the way (x0.15) a chunk
## all but hangs in the air (~2 px/s), so there's time to land on it and jump on up.
var time_scale := 1.0
## Fall speed in normal time (px/s).
var velocity_y := 0.0
var _shattered := false

const SIZE := Vector2(24, 14)


func _ready() -> void:
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = texture
	spr.centered = false
	spr.offset = Vector2(-14, -6)
	add_child(spr)

	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = SIZE
	shape.shape = r
	shape.position = Vector2(0, SIZE.y / 2.0)
	shape.one_way_collision = true
	add_child(shape)

	# Underside: hurts the Father if it lands on him.
	var hurt := Area2D.new()
	hurt.name = "Hurtbox"
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(SIZE.x - 4, 6)
	hs.shape = hr
	hs.position = Vector2(0, SIZE.y - 3)
	hurt.add_child(hs)
	add_child(hurt)
	hurt.body_entered.connect(_on_hurtbox_body_entered)

	# The baby can slow it down or speed it up (not rewind: that would carry the Father up into the ceiling).
	TimeSlowTarget.make(self, _rect(Vector2(30, 22)), Vector2(0, 8), [self], spr)


func _physics_process(delta: float) -> void:
	if _shattered:
		return
	var d := delta * _effective_scale()
	velocity_y = minf(velocity_y + gravity * d, max_fall_speed)
	position.y += velocity_y * d
	if global_position.y + SIZE.y >= floor_y:
		shatter()


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if _shattered or not body is Father:
		return
	if velocity_y * _effective_scale() < hurt_speed:
		return   # slowed right down: it just bumps him
	body.take_damage(damage, global_position)
	shatter()


func _effective_scale() -> float:
	return time_scale * time_scale if time_scale < 1.0 else time_scale


## Bursts into pebbles and dust, then disappears.
func shatter() -> void:
	if _shattered:
		return
	_shattered = true
	var burst := CPUParticles2D.new()
	burst.global_position = global_position + Vector2(0, SIZE.y / 2.0)
	burst.z_index = 3
	burst.one_shot = true
	burst.amount = 24
	burst.lifetime = 0.7
	burst.explosiveness = 0.95
	burst.texture = load("res://assets/gen/pebble.png")
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	burst.emission_rect_extents = Vector2(11, 5)
	burst.direction = Vector2(0, -1)
	burst.spread = 80.0
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 90.0
	burst.gravity = Vector2(0, 320)
	burst.finished.connect(burst.queue_free)
	get_parent().add_child(burst)
	burst.emitting = true
	queue_free()


static func _rect(size: Vector2) -> RectangleShape2D:
	var r := RectangleShape2D.new()
	r.size = size
	return r
