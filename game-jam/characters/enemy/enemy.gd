class_name Enemy
extends CharacterBody2D


@export var speed: float = 40.0            # wandering speed
@export var wander_range: float = 64.0     # how far it wanders each side of its spawn
@export var sidestep_speed: float = 60.0   # how hard each sidestep pushes

@export_group("Attack")
@export var attack_range: float = 48.0     # starts an attack when the Father is this close (px)
@export var attack_windup: float = 0.45    # flashes red this long before lunging (time to react)
@export var lunge_speed: float = 230.0     # how fast the lunge goes
@export var lunge_time: float = 0.25       # how long the lunge lasts
@export var attack_cooldown: float = 1.4   # rest between attacks
@export var hit_reach: float = 26.0        # how close the lunge must get to land a hit
@export var damage: int = 1

@export_group("Health")
@export var max_health: int = 2

enum AttackPhase { NONE, WINDUP, LUNGE, RECOVER }
var attack_phase: AttackPhase = AttackPhase.NONE
var attack_timer: float = 0.0              # time left in the current attack phase
var cooldown_timer: float = 0.0
var attack_dir: float = 1.0
var attack_landed: bool = false
var health: int
var dead: bool = false
## 1 = normal. Changed by the baby's bubble (slow / fast), 0 while rewinding.
var time_scale: float = 1.0

var target: Father = null                  # null = wandering, set = Father spotted
var spawn_x: float                         # where the enemy was placed in the level
var direction: float = 1.0                 # 1 = right, -1 = left
var sidestep_timer: float = 0.0            # time until the next sidestep

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	spawn_x = global_position.x
	health = max_health


func _physics_process(delta: float) -> void:
	delta *= time_scale
	animated_sprite.speed_scale = time_scale
	if not is_on_floor():
		velocity += get_gravity() * delta

	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	elif attack_phase != AttackPhase.NONE:
		_update_attack(delta)
	elif target:
		aggravated(delta)
	else:
		wander()

	# move at time_scale speed (velocity stays in normal-time units)
	var normal_velocity := velocity
	velocity *= time_scale
	move_and_slide()
	velocity = velocity / time_scale if time_scale > 0.001 else normal_velocity


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

	# Close enough: attack
	cooldown_timer -= delta
	if cooldown_timer <= 0.0 and global_position.distance_to(target.global_position) <= attack_range:
		_start_attack()
		return

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


# --- Attack: wind up (flash red), lunge at the Father, recover ---
func _start_attack() -> void:
	attack_phase = AttackPhase.WINDUP
	attack_timer = attack_windup
	attack_dir = signf(target.global_position.x - global_position.x)
	if attack_dir == 0.0:
		attack_dir = 1.0
	attack_landed = false
	velocity.x = 0.0
	var flash := create_tween().set_loops(3)
	flash.tween_property(animated_sprite, "modulate", Color(1.6, 0.5, 0.5), attack_windup / 6.0)
	flash.tween_property(animated_sprite, "modulate", Color.WHITE, attack_windup / 6.0)


func _update_attack(delta: float) -> void:
	attack_timer -= delta
	match attack_phase:
		AttackPhase.WINDUP:
			velocity.x = -attack_dir * 15.0          # leans back before the lunge
			if attack_timer <= 0.0:
				attack_phase = AttackPhase.LUNGE
				attack_timer = lunge_time
		AttackPhase.LUNGE:
			velocity.x = attack_dir * lunge_speed
			if not attack_landed and is_instance_valid(target) \
					and global_position.distance_to(target.global_position) <= hit_reach:
				attack_landed = true
				if target.has_method("take_damage"):
					target.take_damage(damage, global_position)
			if attack_timer <= 0.0 or is_on_wall():
				attack_phase = AttackPhase.RECOVER
				attack_timer = 0.35
		AttackPhase.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, lunge_speed * 6.0 * delta)
			if attack_timer <= 0.0:
				attack_phase = AttackPhase.NONE
				cooldown_timer = attack_cooldown
				animated_sprite.modulate = Color.WHITE


# --- Getting hit (scalpels call this) ---
func take_damage(amount: int = 1, source_position: Vector2 = Vector2.INF) -> void:
	if dead:
		return
	health -= amount
	if source_position != Vector2.INF:
		velocity.x = signf(global_position.x - source_position.x) * 120.0
	attack_phase = AttackPhase.NONE
	cooldown_timer = 0.6
	var flash := create_tween()
	flash.tween_property(animated_sprite, "modulate", Color(3, 3, 3), 0.05)
	flash.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)
	if health <= 0:
		_die()


func _die() -> void:
	dead = true
	target = null
	$CollisionShape2D.set_deferred("disabled", true)
	$DetectionArea.set_deferred("monitoring", false)
	var fade := create_tween()
	fade.tween_property(animated_sprite, "rotation_degrees", 90.0 * signf(velocity.x if velocity.x != 0.0 else 1.0), 0.3)
	fade.parallel().tween_property(animated_sprite, "modulate:a", 0.0, 0.8)
	fade.tween_callback(queue_free)
