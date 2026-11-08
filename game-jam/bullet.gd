class_name Bullet
extends Interactable

## A thrown scalpel. Spins while it flies, then plays the impact burst and
## disappears when it hits a body (walls, floors, enemies). Ignores whoever
## threw it. The baby can slow it down by hovering the bubble over it and holding
## the right stick left (speeding it up makes no sense, so speed_up_time() isn't overridden).

signal hit(body: Node2D)

@export var speed: float = 450.0
## Damage dealt to anything it hits that has take_damage() (enemies).
@export var damage: int = 1
## How fast the scalpel moves while slowed by the bubble (0.5 = half speed).
@export var slowed_multiplier: float = 0.5
## Tint applied while slowed so the player can see it working.
@export var slowed_tint: Color = Color(0.6, 0.85, 1.0)
## Seconds before a scalpel that never hit anything is removed.
@export var lifetime: float = 2.0

## Spin frame showing the blade pointing up, matching how it's held in the hand.
const HELD_FRAME: int = 6

## Set by the thrower so the scalpel doesn't hit them as it leaves the hand.
var shooter: Node2D
## True when thrown by someone facing left; mirrors the scalpel to match the hand.
var mirrored: bool = false
var has_hit: bool = false
## 1.0 = normal speed; set by slow_down_time() / reset_time().
var time_scale: float = 1.0
var _rewinder: Rewinder
var _rewinding: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	# Thrown facing left: mirror it so it leaves the hand the same way up as it was held.
	animated_sprite.flip_v = mirrored
	animated_sprite.play("spin")
	# The father holds it sideways (blade up), so start the spin on the blade-up frame.
	animated_sprite.frame = HELD_FRAME
	get_tree().create_timer(lifetime, false).timeout.connect(_on_lifetime_timeout)
	_rewinder = Rewinder.new()
	_rewinder.target = self
	_rewinder.properties = PackedStringArray(["global_position"])
	add_child(_rewinder)


func _physics_process(delta: float) -> void:
	if has_hit:
		return # stay where it hit while the impact plays
	position += transform.x * speed * time_scale * delta


## Thrown off screen: remove it (screen_exited sends no arguments).
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if has_hit or body == shooter:
		return
	has_hit = true
	collision_shape.set_deferred("disabled", true)
	animated_sprite.flip_v = false
	animated_sprite.global_rotation = 0.0
	animated_sprite.play("impact")
	if body.has_method("take_damage"):
		body.call("take_damage", damage, global_position)
	hit.emit(body)


func _on_animation_finished() -> void:
	if animated_sprite.animation == &"impact":
		queue_free()


func _on_lifetime_timeout() -> void:
	if _rewinding:   # being pulled back by the baby: give it a bit longer
		get_tree().create_timer(1.0, false).timeout.connect(_on_lifetime_timeout)
		return
	if not has_hit:
		queue_free()


# --- Bubble time control ---
func slow_down_time() -> void:
	time_scale = slowed_multiplier
	modulate = slowed_tint


func reset_time() -> void:
	time_scale = 1.0
	modulate = Color.WHITE


## Dynamic: slows down the further the stick is pushed left; pushing right doesn't speed it up.
func set_time_factor(factor: float) -> void:
	time_scale = clampf(factor, 0.0, 1.0)
	modulate = Color.WHITE.lerp(slowed_tint, clampf((1.0 - time_scale) / 0.75, 0.0, 1.0))


func can_rewind() -> bool:
	return not has_hit


func start_rewind() -> void:
	if has_hit:
		return
	_rewinding = true
	_rewinder.start()
	modulate = Color(1.1, 0.75, 1.35)


func stop_rewind() -> void:
	_rewinding = false
	_rewinder.stop()
	modulate = Color.WHITE
