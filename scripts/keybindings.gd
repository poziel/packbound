extends RefCounted

const DEFAULTS := {"pause": KEY_ESCAPE, "rotate_left": KEY_Q, "rotate_right": KEY_E, "rotate_alternate": KEY_R, "inspect": KEY_F1}
const LABELS := {"pause": "Pause / resume", "rotate_left": "Rotate item left", "rotate_right": "Rotate item right", "rotate_alternate": "Rotate right (alternate)", "inspect": "Inspect focused item"}

static func apply(bindings: Dictionary) -> void:
	for action: String in DEFAULTS:
		var name := "pack_" + action
		if not InputMap.has_action(name):
			InputMap.add_action(name)
		InputMap.action_erase_events(name)
		var event := InputEventKey.new()
		event.keycode = int(bindings.get(action, DEFAULTS[action])) as Key
		InputMap.action_add_event(name, event)

static func matches(event: InputEvent, action: String) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	if InputMap.has_action("pack_" + action):
		return event.is_action_pressed("pack_" + action, false, true)
	return event.keycode == DEFAULTS[action]
