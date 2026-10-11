class_name InputBindings
extends RefCounted
## The game's input actions and their default keys, so the game works even
## when the running input map is out of date.
##
## project.godot holds the same bindings (test_keyboard_input.gd checks they
## match). But the Godot editor keeps project settings in memory: if the
## project was open while project.godot changed (e.g. a git pull that
## renamed actions), the editor runs the game with the old map, and can save
## it back over the new file. Renamed actions then don't exist and their keys
## silently do nothing. ensure_defaults() repairs that at startup.

const DEADZONE := 0.2

## Action -> default physical keycodes.
const DEFAULTS := {
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"button_a": [KEY_PERIOD, KEY_KP_PERIOD],
	&"button_b": [KEY_0, KEY_KP_0],
	&"open_focus": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	&"reshuffle": [KEY_R],
}


## Adds any missing action, and gives default keys to any action that has
## no events. Actions that already have keys are left alone, so custom
## rebinding still works. Returns the names of the actions it repaired.
static func ensure_defaults() -> PackedStringArray:
	var repaired := PackedStringArray()
	for action: StringName in DEFAULTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		elif not InputMap.action_get_events(action).is_empty():
			continue
		for keycode: Key in DEFAULTS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)
		repaired.append(action)
	return repaired
