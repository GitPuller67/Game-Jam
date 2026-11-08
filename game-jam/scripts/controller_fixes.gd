extends Node

## Works around controllers that report their triggers swapped, so actions bound
## to a trigger (e.g. shoot = right trigger) use the right physical trigger.
##
## Godot can't bind "every controller except this one", so trigger bindings that
## apply to all controllers are split into one binding per connected controller,
## with the axis swapped for the controllers listed below. This is redone
## whenever a controller is plugged in or out.

## Controllers known to report LT as axis 5 and RT as axis 4, keyed by
## "vendor_id:product_id" (from Input.get_joy_info), per OS.
const SWAPPED_TRIGGERS: Dictionary[String, Array] = {
	"macOS": [
		"11720:12317", # 8BitDo Ultimate 2C Wired Controller, default mode
	],
}

## Each action's original trigger bindings that applied to all controllers.
var _all_device_trigger_events: Dictionary[StringName, Array] = {}


func _ready() -> void:
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if _is_trigger(event) and event.device == -1:
				_all_device_trigger_events.get_or_add(action, []).append(event)
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _rebuild())
	_rebuild()


func has_swapped_triggers(device: int) -> bool:
	var info := Input.get_joy_info(device)
	var id := "%s:%s" % [info.get("vendor_id", ""), info.get("product_id", "")]
	return id in SWAPPED_TRIGGERS.get(OS.get_name(), [])


func _rebuild() -> void:
	for action in _all_device_trigger_events:
		# Drop the trigger bindings from the last rebuild (and the originals).
		for event in InputMap.action_get_events(action):
			if _is_trigger(event):
				InputMap.action_erase_event(action, event)
		# One binding per connected controller, swapped where needed.
		for device in Input.get_connected_joypads():
			for original: InputEventJoypadMotion in _all_device_trigger_events[action]:
				var event := original.duplicate() as InputEventJoypadMotion
				event.device = device
				if has_swapped_triggers(device):
					event.axis = JOY_AXIS_TRIGGER_LEFT if original.axis == JOY_AXIS_TRIGGER_RIGHT else JOY_AXIS_TRIGGER_RIGHT
				InputMap.action_add_event(action, event)


func _is_trigger(event: InputEvent) -> bool:
	return event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
