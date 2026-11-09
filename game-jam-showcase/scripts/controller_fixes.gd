extends Node

## Works around controllers Godot has no layout for (Input.is_joy_known() is false). Those report
## their raw axis / button numbers, which don't always match the standard ones, so e.g. their X
## button shows up as Godot's "Y". Input.add_joy_mapping() doesn't take for these on macOS, so
## instead the input map is rewritten: every controller binding is copied once per connected
## controller, with its axis / button number translated for controllers listed below.
## Godot can't bind "every controller except this one", which is why "all controllers" bindings
## (device -1) are split per controller. Redone whenever a controller is plugged in or out.

## Per OS, keyed by "vendor_id:product_id" (from Input.get_joy_info): standard -> raw numbers.
const LAYOUTS: Dictionary[String, Dictionary] = {
	"macOS": {
		# 8BitDo Ultimate 2C Wired Controller, default mode. Measured: LT/RT come in as axes 5/4,
		# X/Y as buttons 3/4 (A is 0 as usual).
		"11720:12317": {
			"axes": {JOY_AXIS_TRIGGER_LEFT: JOY_AXIS_TRIGGER_RIGHT, JOY_AXIS_TRIGGER_RIGHT: JOY_AXIS_TRIGGER_LEFT},
			"buttons": {JOY_BUTTON_X: 3, JOY_BUTTON_Y: 4},
		},
	},
}

## Each action's original controller bindings, as set in the project's input map.
var _original_events: Dictionary[StringName, Array] = {}


func _ready() -> void:
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if _is_joy(event):
				_original_events.get_or_add(action, []).append(event)
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _rebuild())
	_rebuild()


## The raw-number layout for this controller, or {} if it reports standard numbers.
func layout_for(device: int) -> Dictionary:
	var info := Input.get_joy_info(device)
	var id := "%s:%s" % [info.get("vendor_id", ""), info.get("product_id", "")]
	return LAYOUTS.get(OS.get_name(), {}).get(id, {})


func has_swapped_triggers(device: int) -> bool:
	return layout_for(device).get("axes", {}).has(JOY_AXIS_TRIGGER_RIGHT)


func _rebuild() -> void:
	var connected := Input.get_connected_joypads()
	for action in _original_events:
		# Drop the controller bindings from the last rebuild (and the originals).
		for event in InputMap.action_get_events(action):
			if _is_joy(event):
				InputMap.action_erase_event(action, event)
		for original: InputEvent in _original_events[action]:
			# A binding for every controller becomes one per connected controller.
			var devices: Array = connected if original.device == -1 else [original.device]
			for device in devices:
				var event := original.duplicate() as InputEvent
				event.device = device
				var layout := layout_for(device) if device in connected else {}
				if event is InputEventJoypadButton:
					event.button_index = layout.get("buttons", {}).get(event.button_index, event.button_index)
				elif event is InputEventJoypadMotion:
					event.axis = layout.get("axes", {}).get(event.axis, event.axis)
				InputMap.action_add_event(action, event)


func _is_joy(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion
