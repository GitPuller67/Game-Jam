class_name Baby
extends CharacterBody2D


# --- Signals ---
signal ability_used(ability_name: String)


# --- Exported variables ---
@export_group("Abilities")
@export var ability_cooldown: float = 1.0


# --- Regular variables ---
var can_use_ability: bool = true


# --- @onready variables ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ability_timer: Timer = $AbilityTimer


# --- Built-in functions ---
func _ready() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	pass


# --- Abilities ---
func use_ability(ability_name: String) -> void:
	pass


func is_ability_ready() -> bool:
	return false


# --- Timer callbacks ---
func _on_ability_timer_timeout() -> void:
	pass
