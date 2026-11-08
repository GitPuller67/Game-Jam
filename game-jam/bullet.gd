class_name Bullet
extends Area2D

## A thrown scalpel. Spins while it flies, then plays the impact burst and
## disappears when it hits a body (walls, floors, enemies). Ignores whoever
## threw it.

signal hit(body: Node2D)

@export var speed: float = 800.0
## Seconds before a scalpel that never hit anything is removed.
@export var lifetime: float = 2.0

## Spin frame showing the blade pointing up, matching how it's held in the hand.
const HELD_FRAME: int = 6

## Set by the thrower so the scalpel doesn't hit them as it leaves the hand.
var shooter: Node2D
## True when thrown by someone facing left; mirrors the scalpel to match the hand.
var mirrored: bool = false
var has_hit: bool = false

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


func _physics_process(delta: float) -> void:
	if not has_hit:
		position += transform.x * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if has_hit or body == shooter:
		return
	has_hit = true
	collision_shape.set_deferred("disabled", true)
	animated_sprite.flip_v = false
	animated_sprite.global_rotation = 0.0
	animated_sprite.play("impact")
	hit.emit(body)


func _on_animation_finished() -> void:
	if animated_sprite.animation == &"impact":
		queue_free()


func _on_lifetime_timeout() -> void:
	if not has_hit:
		queue_free()
