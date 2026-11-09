extends CanvasLayer
## Main menu shown when the game starts.
## Pauses the level and hides the HUD until the player clicks Play or presses A on a controller.

## The in-game HUD to hide while the menu is open.
@export var hud: CanvasLayer

@onready var play_button: Button = $Center/Menu/PlayButton

var _started := false


func _ready() -> void:
	play_button.pressed.connect(_start_game)
	visible = true
	if hud:
		hud.visible = false
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.pressed:
		get_viewport().set_input_as_handled()
		_start_game()


func _start_game() -> void:
	if _started:
		return
	_started = true
	set_process_unhandled_input(false)
	visible = false
	if hud:
		hud.visible = true
	# A is also the jump button: wait two physics frames so the press that
	# started the game isn't read as a jump once the level unpauses.
	await get_tree().physics_frame
	await get_tree().physics_frame
	get_tree().paused = false
