class_name Father
extends CharacterBody2D


# --- Signals ---
signal health_changed(new_health: int, max_health: int)
signal died
signal state_changed(new_state: State)


# --- Enums ---
enum State { IDLE, RUN, JUMP, FALL, SLIDE, HURT, DEAD }


# --- Constants ---
const GRAVITY: float = 980.0


# --- Exported variables ---
@export_group("Movement")
@export var speed: float = 200.0
@export var acceleration: float = 1200.0
@export var friction: float = 1000.0

@export_group("Jumping")
@export var jump_velocity: float = -400.0
@export var max_jumps: int = 1
## Coyote jump: after walking off a ledge you can still jump until you've
## moved this many pixels sideways past where you left the ground...
@export var coyote_distance: float = 8.0
## ...or this many seconds have passed, whichever comes first.
@export var coyote_time: float = 0.2

@export_group("Slide")
@export var slide_speed: float = 350.0
@export var slide_friction: float = 400.0
@export var slide_duration: float = 0.5
@export var slide_cooldown: float = 0.3
@export var min_speed_to_slide: float = 100.0

@export_group("Crouch")
@export var walk_speed: float = speed
@export var crouch_speed: float = 50.0

@export_group("Health")
@export var max_health: int = 3


# --- Regular variables ---
var health: int
var current_state: State = State.IDLE
var facing_direction: int = 1
var jumps_remaining: int
var can_slide: bool = true
var is_invincible: bool = false
var is_sliding: bool = false
var is_crouching: bool = false
# Coyote jump tracking
var last_floor_x: float = 0.0
var time_since_floor: float = 0.0
var has_jumped: bool = false


# --- @onready variables ---
@onready var standing_collision: CollisionShape2D = $StandingCollision
@onready var sliding_collision: CollisionShape2D = $SlidingCollision
@onready var ceiling_check: ShapeCast2D = $CeilingCheck
@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var baby: Baby = $Visuals/Baby
@onready var slide_timer: Timer = $SlideTimer
@onready var slide_cooldown_timer: Timer = $SlideCooldownTimer

# Bullet
@export var bullet_scene: PackedScene
@onready var muzzle: Marker2D = $Muzzle
@onready var aim_laser: Line2D = $"Muzzle/Aim Laser"

# Ammo
@export var max_ammo: int = 10
var current_ammo: int = 0

# Aim
var current_aim_angle: float = 0.0
var is_using_controller: bool = false

func _ready() -> void:
	current_ammo = max_ammo

func _on_slide_timer_timeout() -> void:
	is_sliding = false
	can_slide = false
	speed = walk_speed
	slide_cooldown_timer.start(slide_cooldown)
	
func _on_slide_cooldown_timer_timeout() -> void:
	can_slide = true
	

# Bullet logic
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		is_using_controller = true
	
	if Input.is_action_just_pressed("shoot"):
		shoot()
		
func _process(delta: float) -> void:
	if is_using_controller:
		var aim_vector = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		
		if aim_vector.length() > 0.2:
			current_aim_angle = aim_vector.angle()
	else:
		var mouse_pos = get_global_mouse_position()
		current_aim_angle = muzzle.global_position.direction_to(mouse_pos).angle()
		
	aim_laser.global_rotation = current_aim_angle	
		
func shoot() -> void:
	if current_ammo <= 0:
		return
		
	current_ammo -= 1
	
	var new_bullet = bullet_scene.instantiate()
	new_bullet.global_position = muzzle.global_position
	
	new_bullet.global_position = muzzle.global_position
	new_bullet.global_rotation = current_aim_angle
	
	get_tree().current_scene.add_child(new_bullet)

# --- Built-in functions ---
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	# Handle crouch.			
	if velocity.x != 0:
		if Input.is_action_just_pressed("crouch") and not is_sliding and can_slide:
			is_sliding = true
			animated_sprite.play("slide")
			speed = slide_speed
			slide_timer.start(slide_duration)

	# Handle jump.
	if is_on_floor():
		last_floor_x = global_position.x
		time_since_floor = 0.0
		has_jumped = false
	else:
		time_since_floor += delta

	if Input.is_action_just_pressed("jump") and can_jump():
		velocity.y = jump_velocity
		has_jumped = true

	# Get the input direction: -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")

	# Flip the sprite
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	# Play animations
	if is_sliding:
		pass
	elif is_on_floor():
		if direction == 0:
			if is_crouching:
				animated_sprite.play("crouch")
			else:
				animated_sprite.play("default")
		elif direction != 0 and !is_sliding:
			animated_sprite.play("run")
	else:
		animated_sprite.play("jump")

	# Apply movement
	if direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()


## On the ground, or just walked off a ledge (falling, not from a jump, and
## still within coyote_distance / coyote_time of where he left the ground).
func can_jump() -> bool:
	if is_on_floor():
		return true
	return (
		not has_jumped
		and velocity.y >= 0.0
		and time_since_floor <= coyote_time
		and absf(global_position.x - last_floor_x) <= coyote_distance
	)
