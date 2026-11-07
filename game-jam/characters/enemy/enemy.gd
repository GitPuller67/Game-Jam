class_name Enemy
extends CharacterBody2D


# --- Regular variables ---
var target: Father = null              # null = Father not in range, set = Father in range


# --- Signal callbacks ---
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is Father:
		target = body
		print("Enemy: Father entered detection range")


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
		print("Enemy: Father left detection range")
