extends Label
## Notes that are visible in the editor but hidden when the game runs.

func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
