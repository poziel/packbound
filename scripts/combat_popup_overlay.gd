extends Control
## Carries finishing effects independently of the old room's monster and board.
const EFFECT_POPUP = preload("res://scripts/combat_effect_popup.gd")
var effect_popups: Array[Dictionary] = []
var paused: bool = false

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
	paused = false
	queue_redraw()

func _process(delta: float) -> void:
	if paused or effect_popups.is_empty():
		return
	EFFECT_POPUP.advance(effect_popups, delta)
	queue_redraw()

func _draw() -> void:
	EFFECT_POPUP.draw(self, effect_popups)
