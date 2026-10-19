extends Control
## Carries finishing effects independently of the old room's monster and board.
const EFFECT_POPUP = preload("res://scripts/combat_effect_popup.gd")
var effect_popups: Array[Dictionary] = []
var paused: bool = false
var _incoming_lane: int = 0

## Player perspective: large numbers in separated lanes on the left.
func show_player_hit(result: Dictionary, damage_type: String = "physical", speed: float = 1.0) -> void:
	var entries: Array[Dictionary] = []
	if int(result.get("taken", 0)) > 0:
		entries.append({"key": "magical_attack" if damage_type == "magical" else "physical_attack", "amount": int(result["taken"])})
	if int(result.get("blocked", 0)) > 0:
		entries.append({"key": "block", "amount": int(result["blocked"])})
	var view: Vector2 = get_viewport_rect().size
	for entry: Dictionary in entries:
		var lane: int = _incoming_lane % 4
		_incoming_lane += 1
		var anchor := Vector2(view.x * (0.12 if lane % 2 == 0 else 0.32), view.y * (0.54 if lane < 2 else 0.76))
		anchor -= global_position
		var delay: float = 0.0
		for other: Dictionary in effect_popups:
			if int(other.get("incoming_lane", -1)) == lane:
				delay = maxf(delay, (float(other["duration"]) - float(other["elapsed"])) / float(other["speed"]))
		var popup_speed: float = clampf(speed, 0.75, 1.35)
		effect_popups.append({"anchor": anchor.round(), "key": entry["key"], "amount": entry["amount"],
			"elapsed": -delay * popup_speed, "speed": popup_speed, "duration": 1.8,
			"height": 90.0, "drift": 0.0, "size_multiplier": 2.0, "incoming_lane": lane})
	queue_redraw()

func take_from(source: Control, popups: Array[Dictionary]) -> void:
	for popup: Dictionary in popups:
		var transferred: Dictionary = popup.duplicate()
		transferred["anchor"] = source.global_position + popup["anchor"] - global_position
		effect_popups.append(transferred)
	popups.clear()
	source.queue_redraw()
	queue_redraw()

func clear() -> void:
	effect_popups.clear()
	_incoming_lane = 0
	paused = false
	queue_redraw()

func _process(delta: float) -> void:
	if paused or effect_popups.is_empty():
		return
	EFFECT_POPUP.advance(effect_popups, delta)
	queue_redraw()

func _draw() -> void:
	EFFECT_POPUP.draw(self, effect_popups)
