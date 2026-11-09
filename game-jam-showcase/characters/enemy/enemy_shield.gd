class_name EnemyShield
extends Area2D
## Energy dome around an enemy. Ordinary scalpels bounce off it (it flashes); a scalpel the
## baby has sped up with the bubble shatters it. Once broken it's gone for good.
##
## Sits on its own physics layer ("shield", layer 4) so only scalpels notice it.

signal broken
## Any scalpel hit it (blocked or not).
signal struck

## How sped up a scalpel must be to break the shield (its Bullet.boost: 1 = normal speed,
## 2.5 = the most the bubble can give it).
@export var break_boost: float = 1.5

var active: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	monitoring = false   # scalpels do the detecting
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play(&"idle")


## A scalpel flew into the shield. Returns true if the shield stopped it.
func hit_by(scalpel: Bullet) -> bool:
	if not active:
		return false
	struck.emit()
	if scalpel.boost >= break_boost:
		shatter()
	else:
		sprite.play(&"hit")
	return true


func shatter() -> void:
	if not active:
		return
	active = false
	set_deferred("monitorable", false)
	sprite.play(&"break")
	broken.emit()


func _on_animation_finished() -> void:
	match sprite.animation:
		&"hit":
			sprite.play(&"idle")
		&"break":
			sprite.hide()
