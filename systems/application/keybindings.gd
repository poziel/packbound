extends RefCounted

const DEFAULTS := {
	"dev_menu": KEY_F8, "pause": KEY_ESCAPE, "primary": KEY_SPACE, "rotate_left": KEY_Q, "rotate_right": KEY_E,
	"craft_lock": {"mouse": MOUSE_BUTTON_RIGHT},
	"priority_up": {"mouse": MOUSE_BUTTON_LEFT, "ctrl": true},
	"priority_down": {"mouse": MOUSE_BUTTON_RIGHT, "ctrl": true}, "quick_inspect": KEY_SHIFT,
	"stash": KEY_B, "item_reward": KEY_I, "relic_reward": KEY_L,
	"backpack": KEY_F1, "relics": KEY_F2, "statistics": KEY_F3, "logs": KEY_F4,
	"select_1": KEY_1, "select_2": KEY_2, "select_3": KEY_3, "select_4": KEY_4, "select_5": KEY_5
}
const LABELS := {
	"dev_menu": "Developer tools", "pause": "Pause / resume", "primary": "Primary room action", "rotate_left": "Rotate item left", "rotate_right": "Rotate item right",
	"craft_lock": "Lock item crafting", "priority_up": "Increase item priority", "priority_down": "Decrease item priority",
	"quick_inspect": "Quick inspect (hold)", "stash": "Open stash", "item_reward": "Open item rewards", "relic_reward": "Open relic rewards",
	"backpack": "Backpack panel", "relics": "Relics panel", "statistics": "Statistics panel", "logs": "Logs panel",
	"select_1": "Select choice 1", "select_2": "Select choice 2", "select_3": "Select choice 3", "select_4": "Select choice 4", "select_5": "Select choice 5"
}

static func normalize(binding: Variant) -> Dictionary:
	var data: Dictionary = {"key": int(binding)} if binding is int else (binding.duplicate() if binding is Dictionary else {})
	return {"key": int(data.get("key", 0)), "mouse": int(data.get("mouse", 0)), "ctrl": bool(data.get("ctrl", false)), "shift": bool(data.get("shift", false)), "alt": bool(data.get("alt", false)), "meta": bool(data.get("meta", false))}

static func event_for(binding: Variant) -> InputEventWithModifiers:
	var data := normalize(binding)
	var event: InputEventWithModifiers
	if data.mouse > 0:
		event = InputEventMouseButton.new()
		event.button_index = data.mouse
	else:
		event = InputEventKey.new()
		event.keycode = data.key
	event.ctrl_pressed = data.ctrl
	event.shift_pressed = data.shift
	event.alt_pressed = data.alt
	event.meta_pressed = data.meta
	return event

static func from_event(event: InputEventWithModifiers) -> Dictionary:
	var data := {"ctrl": event.ctrl_pressed, "shift": event.shift_pressed, "alt": event.alt_pressed, "meta": event.meta_pressed}
	if event is InputEventMouseButton:
		data["mouse"] = event.button_index
	else:
		data["key"] = event.keycode
		if event.keycode == KEY_SHIFT: data.shift = false
		if event.keycode == KEY_CTRL: data.ctrl = false
		if event.keycode == KEY_ALT: data.alt = false
		if event.keycode == KEY_META: data.meta = false
	return normalize(data)

static func label(binding: Variant) -> String:
	var data := normalize(binding)
	var parts: PackedStringArray = []
	if data.ctrl: parts.append("Ctrl")
	if data.shift: parts.append("Shift")
	if data.alt: parts.append("Alt")
	if data.meta: parts.append("Meta")
	parts.append("Mouse %d" % data.mouse if data.mouse > 0 else OS.get_keycode_string(data.key))
	return "+".join(parts)

static func valid(binding: Variant) -> bool:
	var data := normalize(binding)
	return (data.mouse >= 1 and data.mouse <= 9 and data.key == 0) or (data.mouse == 0 and data.key > 0 and data.key != KEY_F11 and not OS.get_keycode_string(data.key).is_empty())

static func apply(bindings: Dictionary) -> void:
	for obsolete in ["rotate_alternate", "inspect"]:
		if InputMap.has_action("pack_" + obsolete): InputMap.erase_action("pack_" + obsolete)
	for action: String in DEFAULTS:
		var name := "pack_" + action
		if not InputMap.has_action(name): InputMap.add_action(name)
		InputMap.action_erase_events(name)
		InputMap.action_add_event(name, event_for(bindings.get(action, DEFAULTS[action])))

static func matches(event: InputEvent, action: String) -> bool:
	if not DEFAULTS.has(action) or not (event is InputEventKey or event is InputEventMouseButton) or not event.pressed or (event is InputEventKey and event.echo):
		return false
	var binding: InputEventWithModifiers = InputMap.action_get_events("pack_" + action)[0] if InputMap.has_action("pack_" + action) else event_for(DEFAULTS[action])
	return from_event(event) == from_event(binding)

static func held(action: String) -> bool:
	if not InputMap.has_action("pack_" + action): return false
	var data := from_event(InputMap.action_get_events("pack_" + action)[0])
	var down: bool = Input.is_mouse_button_pressed(data.mouse) if data.mouse > 0 else Input.is_key_pressed(data.key)
	return down and (not data.ctrl or Input.is_key_pressed(KEY_CTRL)) and (not data.shift or Input.is_key_pressed(KEY_SHIFT)) and (not data.alt or Input.is_key_pressed(KEY_ALT)) and (not data.meta or Input.is_key_pressed(KEY_META))
