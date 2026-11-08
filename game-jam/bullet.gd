class_name Bullet
extends Interactable

## A thrown scalpel. Spins while it flies, then plays the impact burst and
## disappears when it hits a body (walls, floors, enemies) or an enemy's shield
## (which only a sped-up scalpel can break, see EnemyShield). Ignores whoever
## threw it; scalpels thrown by enemies also ignore other enemies.
## While the baby rewinds it, it flies back the way it came and keeps going past the
## thrower's hand, hitting any enemy in the way (including whoever threw it) but never the Father. The baby can slow it down by hovering the bubble over it and holding
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
## Spin frame it starts on, to match how the thrower held it (enemies hold it flat: frame 0).
var start_frame: int = HELD_FRAME
var _thrown_by_enemy: bool = false
## True when thrown by someone facing left; mirrors the scalpel to match the hand.
var mirrored: bool = false
var has_hit: bool = false
## 1.0 = normal speed; set by slow_down_time() / reset_time().
var time_scale: float = 1.0
var _rewinder: Rewinder
## Speed boost from the baby (1 = none). Kept after leaving the bubble.
var boost: float = 1.0
## Fastest a boosted scalpel can go (x its normal speed).
@export var max_boost: float = 2.5
## Tint while boosted.
@export var boosted_tint: Color = Color(1.25, 0.9, 0.6)
var _rewinding: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_thrown_by_enemy = shooter is Enemy
	animated_sprite.animation_finished.connect(_on_animation_finished)
	# Thrown facing left: mirror it so it leaves the hand the same way up as it was held.
	animated_sprite.flip_v = mirrored
	animated_sprite.play("spin")
	# Start the spin on the frame matching how it was held (the father holds it blade up).
	animated_sprite.frame = start_frame
	get_tree().create_timer(lifetime, false).timeout.connect(_on_lifetime_timeout)
	_rewinder = Rewinder.new()
	_rewinder.target = self
	_rewinder.properties = PackedStringArray(["global_position"])
	add_child(_rewinder)


func _physics_process(delta: float) -> void:
	if has_hit:
		return # stay where it hit while the impact plays
	if _rewinding:
		# The Rewinder plays its path back; once that runs out (back at the hand that threw it),
		# keep flying backwards at the same rewind speed so it can be sent into the thrower.
		if _rewinder.is_exhausted():
			position -= transform.x * speed * maxf(boost, 1.0) * _rewinder.rewind_rate * delta
		return
	position += transform.x * speed * time_scale * delta


## Thrown off screen: remove it (screen_exited sends no arguments).
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	# An enemy still behind its shield (e.g. thrown from inside the dome): the shield takes it.
	if body is Enemy and body.shield and body.shield.active:
		_on_area_entered(body.shield)
		return
	if not _can_hit(body):
		return
	_impact()
	if body.has_method("take_damage"):
		body.call("take_damage", damage, global_position)
	hit.emit(body)


func _on_area_entered(area: Area2D) -> void:
	var shield := area as EnemyShield
	if not shield or not shield.active or not _can_hit(shield):
		return
	_impact()
	shield.hit_by(self)
	hit.emit(shield)


func _can_hit(node: Node2D) -> bool:
	if has_hit:
		return false
	if _rewinding:
		return not (node is Father)   # the baby's attack now: anything but the Father
	if node == shooter:
		return false
	if _thrown_by_enemy and (node is Enemy or node is EnemyShield):
		return false   # enemies don't hit each other (or their own shield)
	return true


## Stop where it hit and play the impact burst.
func _impact() -> void:
	has_hit = true
	if _rewinding:   # hit something mid-rewind: stop the playback so it stays where it hit
		_rewinding = false
		_rewinder.stop()
		_update_tint()
	collision_shape.set_deferred("disabled", true)
	animated_sprite.flip_v = false
	animated_sprite.global_rotation = 0.0
	animated_sprite.play("impact")


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
	time_scale = boost   # 1.0 unless it was sped up, which it keeps
	_update_tint()


## Dynamic: the further the stick is pushed, the slower / faster it flies.
## Speeding up sticks: once boosted it keeps its fastest speed even after it leaves the bubble
## or the stick is let go. Slowing only lasts while it's in the bubble.
func set_time_factor(factor: float) -> void:
	if factor >= 1.0:
		boost = maxf(boost, minf(factor, max_boost))
		time_scale = boost
	else:
		time_scale = factor
	_update_tint()


func _update_tint() -> void:
	if time_scale < 1.0:
		modulate = Color.WHITE.lerp(slowed_tint, clampf((1.0 - time_scale) / 0.75, 0.0, 1.0))
	else:
		modulate = Color.WHITE.lerp(boosted_tint, clampf(time_scale - 1.0, 0.0, 1.0))


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
	_update_tint()
