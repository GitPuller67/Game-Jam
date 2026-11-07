class_name Enemy
extends CharacterBody2D


@export var speed: float = 40.0            # wandering speed
@export var wander_range: float = 64.0     # how far it wanders each side of its spawn
@export var sidestep_speed: float = 60.0   # how hard each sidestep pushes

var target: Father = null                  # null = wandering, set = Father spotted
var spawn_x: float                         # where the enemy was placed in the level
var direction: float = 1.0                 # 1 = right, -1 = left
var sidestep_timer: float = 0.0            # time until the next sidestep

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	spawn_x = global_position.x


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if target:
		aggravated(delta)
	else:
		wander()

	move_and_slide()


func wander() -> void:
	# Turn around at the edges of the wander area, or when hitting a wall
	if global_position.x > spawn_x + wander_range:
		direction = -1.0
	elif global_position.x < spawn_x - wander_range:
		direction = 1.0
	elif is_on_wall():
		direction = signf(get_wall_normal().x)

	velocity.x = direction * speed
	animated_sprite.flip_h = direction < 0.0


func aggravated(delta: float) -> void:
	# Look at the Father
	animated_sprite.flip_h = target.global_position.x < global_position.x

	# Slow down to a stop between sidesteps
	velocity.x = move_toward(velocity.x, 0.0, sidestep_speed * 4.0 * delta)

	# Every 0.5–1.5 seconds, hop a little left or right
	sidestep_timer -= delta
	if sidestep_timer <= 0.0:
		sidestep_timer = randf_range(0.5, 1.5)
		velocity.x = [-1.0, 1.0].pick_random() * sidestep_speed


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is Father:
		target = body


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
		
