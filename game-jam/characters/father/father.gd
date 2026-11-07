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


# --- @onready variables ---
@onready var standing_collision: CollisionShape2D = $StandingCollision
@onready var sliding_collision: CollisionShape2D = $SlidingCollision
@onready var ceiling_check: ShapeCast2D = $CeilingCheck
@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var baby: Baby = $Visuals/Baby
@onready var slide_timer: Timer = $SlideTimer
@onready var slide_cooldown_timer: Timer = $SlideCooldownTimer


func _on_slide_timer_timeout() -> void:
	is_sliding = false
	can_slide = false
	slide_cooldown_timer.start(slide_cooldown)
	
func _on_slide_cooldown_timer_timeout() -> void:
	can_slide = true

# --- Built-in functions ---
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	# Handle crouch.
	if velocity.x == 0:
		if Input.is_action_just_released("crouch") and is_on_floor():
			if speed == walk_speed:
				animated_sprite.play("crouch")
				speed = crouch_speed
			elif speed == crouch_speed:
				speed = walk_speed
				
	else:
		if Input.is_action_just_pressed("crouch") and not is_sliding and can_slide:
			is_sliding = true
			animated_sprite.play("slide")
			slide_timer.start(slide_duration)

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

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
