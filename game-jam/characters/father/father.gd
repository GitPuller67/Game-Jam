class_name Father
extends CharacterBody2D


# --- Signals ---
signal health_changed(new_health: int, max_health: int)
signal died
signal state_changed(new_state: State)
signal shot
## His scalpel count changed (picked some up, or threw one).
signal ammo_changed(ammo: int)


# --- Enums ---
enum State { IDLE, RUN, JUMP, FALL, SLIDE, HURT, DEAD }


# --- Constants ---
const GRAVITY: float = 980.0


# --- Exported variables ---
@export_group("Movement")
@export var speed: float = 140.0
@export var acceleration: float = 1200.0
@export var friction: float = 1000.0

@export_group("Jumping")
@export var jump_velocity: float = -350.0
@export var max_jumps: int = 1
## Coyote jump: after walking off a ledge you can still jump until you've
## moved this many pixels sideways past where you left the ground...
@export var coyote_distance: float = 8.0
## ...or this many seconds have passed, whichever comes first.
@export var coyote_time: float = 0.2

@export_group("Slide")
@export var slide_speed: float = 260.0
@export var slide_friction: float = 400.0
@export var slide_duration: float = 0.5
@export var slide_cooldown: float = 0.3
@export var min_speed_to_slide: float = 100.0

@export_group("Crouch")
@export var walk_speed: float = 140.0
@export var crouch_speed: float = 50.0

@export_group("Health")
@export var max_health: int = 3
## Seconds he can't be hurt again after taking a hit (he blinks).
@export var invincible_time: float = 1.0
## Push-back when hurt: sideways away from the hit, and up.
@export var knockback: Vector2 = Vector2(160.0, -160.0)


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
## 1 = normal. The baby's bubble changes this to slow him down / speed him up; 0 while rewinding.
var time_scale: float = 1.0
## The bubble hovers over this to control his time / rewind him.
var time_handle: TimeSlowTarget

@export_group("Soothing")
## Hold X (controller 1) to soothe the baby: he stands still and the baby's energy refills this fast (per second).
@export var soothe_rate: float = 35.0
var is_soothing: bool = false
var _soothe_hearts: CPUParticles2D
var _soothe_t: float = 0.0

## Set by levels for special areas (Room 5's drop): cap how fast he can fall (normal-time px/s)...
var max_fall_speed: float = INF
## ...and let his left/right steering ignore time_scale while in the air, so slowing him down
## slows his fall but not his steering.
var steer_ignores_time_scale: bool = false
## Fastest the baby can speed him up (the stick goes up to 2.5x for everything else).
@export var max_time_boost: float = 1.5


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
## He starts empty-handed: scalpels come from pickups (ScalpelPickup).
var current_ammo: int = 0

## Set by cutscenes (e.g. the intro): the player's input is ignored, he walks in cutscene_walk's
## direction (-1 / 0 / 1, fractions walk slower) and crouches while cutscene_crouch is on.
var cutscene: bool = false
var cutscene_walk: float = 0.0
var cutscene_crouch: bool = false

# Aim
@export_group("Aiming")
## How far past straight up/down the aim must go before he turns around
## (fraction of a fully sideways aim). Stops him flipping back and forth when
## aiming straight up or down.
@export_range(0.0, 0.5) var turn_threshold: float = 0.1
var current_aim_angle: float = 0.0
var is_using_controller: bool = false

func _ready() -> void:
	current_ammo = 0
	# Jumping off something that's sinking (a slowed Room 4 chunk, the lift going down) still gets a
	# full-height jump; a rising platform still adds its lift.
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_ADD_UPWARD_VELOCITY
	add_to_group("door_blockable")   # timed doors (Room 6) shove him back if they shut on him
	_add_time_handle()
	_add_soothe_hearts()
	health = max_health
	health_changed.emit.call_deferred(health, max_health)

func _on_slide_timer_timeout() -> void:
	is_sliding = false
	can_slide = false
	speed = walk_speed
	slide_cooldown_timer.start(slide_cooldown)
	
func _on_slide_cooldown_timer_timeout() -> void:
	can_slide = true
	

# Bullet logic
func _unhandled_input(event: InputEvent) -> void:
	# Only controller 1 (device 0) is the father's; controller 2 belongs to the baby.
	if (event is InputEventJoypadMotion or event is InputEventJoypadButton) and event.device == 0:
		is_using_controller = true

func _process(delta: float) -> void:
	if cutscene:
		# no aiming or shooting; he faces the way he walks
		if cutscene_walk != 0.0:
			facing_direction = 1 if cutscene_walk > 0.0 else -1
			animated_sprite.flip_h = facing_direction < 0
		return
	# Checked once per frame so one RT pull / click fires exactly one bullet.
	if Input.is_action_just_pressed("shoot"):
		shoot()

	if is_using_controller:
		var aim_vector = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		
		if aim_vector.length() > 0.2:
			current_aim_angle = aim_vector.angle()
	else:
		var mouse_pos = get_global_mouse_position()
		current_aim_angle = muzzle.global_position.direction_to(mouse_pos).angle()
		
	aim_laser.global_rotation = current_aim_angle
	_face_aim()	
		
## Turns the father to face the side he's aiming at. Measured from his center
## (not the hand) so the hand moving when he turns can't flip him back.
func _face_aim() -> void:
	var aim_x: float
	if is_using_controller:
		aim_x = cos(current_aim_angle)
	else:
		aim_x = (get_global_mouse_position() - global_position).normalized().x
	if absf(aim_x) > turn_threshold:
		facing_direction = 1 if aim_x > 0.0 else -1
		animated_sprite.flip_h = facing_direction < 0


func shoot() -> void:
	if current_ammo <= 0:
		return
		
	current_ammo -= 1
	ammo_changed.emit(current_ammo)
	
	var new_bullet = bullet_scene.instantiate()
	new_bullet.global_position = muzzle.global_position
	
	new_bullet.global_position = muzzle.global_position
	new_bullet.global_rotation = current_aim_angle
	new_bullet.shooter = self
	new_bullet.mirrored = animated_sprite.flip_h

	get_tree().current_scene.add_child(new_bullet)
	shot.emit()

# --- Health ---
## Hurt the father. source_position (optional) is where the hit came from, for knock-back.
func take_damage(amount: int = 1, source_position: Vector2 = Vector2.INF) -> void:
	if is_invincible or current_state == State.DEAD:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if source_position != Vector2.INF:
		var away := signf(global_position.x - source_position.x)
		if away == 0.0:
			away = -facing_direction
		velocity = Vector2(away * knockback.x, knockback.y)
	if health <= 0:
		_die()
		return
	is_invincible = true
	var blink := create_tween().set_loops(int(invincible_time / 0.12))
	blink.tween_property(visuals, "modulate:a", 0.25, 0.06)
	blink.tween_property(visuals, "modulate:a", 1.0, 0.06)
	await get_tree().create_timer(invincible_time, false).timeout
	visuals.modulate.a = 1.0
	is_invincible = false


## Picks up scalpels (up to max_ammo). Returns how many he actually took.
func add_ammo(amount: int) -> int:
	var before := current_ammo
	current_ammo = mini(current_ammo + amount, max_ammo)
	if current_ammo != before:
		ammo_changed.emit(current_ammo)
	return current_ammo - before


## Instant death (e.g. crushed by the lift), even during his post-hit invincibility.
func kill() -> void:
	if current_state == State.DEAD:
		return
	health = 0
	health_changed.emit(health, max_health)
	_die()


func _die() -> void:
	current_state = State.DEAD
	state_changed.emit(current_state)
	visuals.modulate = Color(1.0, 0.45, 0.45)
	died.emit()
	# If the level doesn't respawn him (nothing listening to died), restart the scene.
	if died.get_connections().is_empty():
		await get_tree().create_timer(1.2, false).timeout
		get_tree().reload_current_scene()


## Bring him back at full health (the level calls this after he dies).
func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	health = max_health
	health_changed.emit(health, max_health)
	visuals.modulate = Color.WHITE
	current_state = State.IDLE
	state_changed.emit(current_state)
	is_invincible = false


# --- Time control (the baby's bubble) ---
## Lets the bubble slow him down, speed him up (right stick) and rewind him (hold Y).
func _add_time_handle() -> void:
	var box := RectangleShape2D.new()
	box.size = Vector2(24, 46)
	var nodes: Array[Node] = [self]
	time_handle = TimeSlowTarget.make(self, box, Vector2(0, 2), nodes, visuals)
	time_handle.max_factor = max_time_boost
	time_handle.set_meta(&"is_player", true)   # the bubble prefers rewinding other things over him
	time_handle.add_rewind(self, PackedStringArray(["global_position", "velocity", "facing_direction"]))


## move_and_slide() at time_scale speed (velocity stays in "normal time" units).
func _move_scaled() -> void:
	if is_equal_approx(time_scale, 1.0):
		move_and_slide()
		return
	var normal_velocity := velocity
	var steer_free := steer_ignores_time_scale and not is_on_floor()
	velocity = Vector2(normal_velocity.x if steer_free else normal_velocity.x * time_scale, normal_velocity.y * time_scale)
	move_and_slide()
	if time_scale > 0.001:
		velocity = Vector2(velocity.x if steer_free else velocity.x / time_scale, velocity.y / time_scale)
	else:
		velocity = normal_velocity


# --- Built-in functions ---
func _physics_process(delta: float) -> void:
	var real_delta := delta
	delta *= time_scale
	animated_sprite.speed_scale = time_scale
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	velocity.y = minf(velocity.y, max_fall_speed)

	if current_state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		_move_scaled()
		return

	# Soothing the baby: stand still, rock the baby, energy refills.
	_set_soothing(Input.is_action_pressed("soothe") and is_on_floor() and not is_sliding and not cutscene, real_delta)
	if is_soothing:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		animated_sprite.play("default")
		_move_scaled()
		return
		
	# Handle crouch.			
	if velocity.x != 0:
		if Input.is_action_just_pressed("crouch") and not is_sliding and can_slide and not cutscene:
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

	if Input.is_action_just_pressed("jump") and can_jump() and not cutscene:
		velocity.y = jump_velocity
		has_jumped = true

	# Get the input direction: -1, 0, 1
	var direction := cutscene_walk if cutscene else Input.get_axis("move_left", "move_right")

	# Facing follows the aim, not movement (see _face_aim).

	# Play animations
	if is_sliding:
		pass
	elif is_on_floor():
		if direction == 0:
			if is_crouching or (cutscene and cutscene_crouch):
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

	_move_scaled()


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


# --- Soothing the baby (hold X) ---
func _set_soothing(on: bool, delta: float) -> void:
	if on != is_soothing:
		is_soothing = on
		_soothe_hearts.emitting = on
		if not on:
			baby.sprite.offset = Vector2.ZERO
			baby.sprite.modulate = Color.WHITE
	if not on:
		return
	_soothe_t += delta
	# gentle rocking + a warm glow on the baby
	baby.sprite.offset = Vector2(0, roundf(sin(_soothe_t * 6.0) * 1.0))
	baby.sprite.modulate = Color(1.15, 1.0, 1.05)
	_soothe_hearts.global_position = baby.sprite.global_position + Vector2(7, -2)
	var bubble := baby.get_node_or_null("Bubble")
	if bubble and bubble.has_method("add_energy"):
		bubble.add_energy(soothe_rate * delta)


func _add_soothe_hearts() -> void:
	# little 16-bit heart, drawn in code
	var rows := [".XX.XX.", "XWXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
	var img := Image.create(7, 6, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			if ch == "X":
				img.set_pixel(x, y, Color(1.0, 0.42, 0.55))
			elif ch == "W":
				img.set_pixel(x, y, Color(1.0, 0.85, 0.9))
	var p := CPUParticles2D.new()
	p.name = "SootheHearts"
	p.texture = ImageTexture.create_from_image(img)
	p.emitting = false
	p.amount = 6
	p.lifetime = 1.2
	p.direction = Vector2(0, -1)
	p.spread = 35.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 24.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.z_index = 20
	add_child(p)
	_soothe_hearts = p
