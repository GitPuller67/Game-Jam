@tool
extends ColorRect
## 26x51 outline of the player character, for checking scale.
## Always shown in the editor. In the game it's hidden; press G in the map viewer
## (or run with -- --sizes) to show it.

func _ready() -> void:
	add_to_group("size_guide")
	if not Engine.is_editor_hint():
		visible = "--sizes" in OS.get_cmdline_user_args()
