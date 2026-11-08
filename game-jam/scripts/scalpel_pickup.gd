class_name ScalpelPickup
extends Area2D
## Scalpels left lying on the floor. Walking over them gives the Father `amount` scalpels
## (Father.add_ammo). If he can't carry them all, the rest stay on the floor for later.
## Origin = the floor under it. Glints now and then so it's easy to spot.

signal picked_up(amount: int)

@export var amount: int = 5

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	var tex := AtlasTexture.new()
	tex.atlas = load("res://assets/spritesheets/scalpel_projectile_sheet.png")
	tex.region = Rect2(0, 0, 20, 20)   # the flat, blade-right frame
	_sprite.texture = tex
	_sprite.position = Vector2(0, -12)  # blade resting on the floor
	_sprite.z_index = 4
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(18, 12)
	shape.shape = r
	shape.position = Vector2(0, -6)
	add_child(shape)
	monitorable = false
	body_entered.connect(_on_body_entered)

	var glint := create_tween().set_loops()
	glint.tween_interval(1.4)
	glint.tween_property(_sprite, "modulate", Color(1.9, 1.9, 1.9), 0.12)
	glint.tween_property(_sprite, "modulate", Color.WHITE, 0.3)


func _on_body_entered(body: Node2D) -> void:
	if not body is Father:
		return
	var took: int = body.add_ammo(amount)
	if took <= 0:
		return   # his hands are full: leave it
	picked_up.emit(took)
	amount -= took
	if amount > 0:
		return   # took what he could carry; the rest stay here
	set_deferred("monitoring", false)
	# hop up and fade
	var tw := create_tween()
	tw.tween_property(_sprite, "position:y", _sprite.position.y - 10.0, 0.2).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
