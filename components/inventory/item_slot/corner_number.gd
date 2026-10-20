@tool
extends Control
## Numbered variant foreground, rendered above the tile's Art child.

const FRAME = preload("res://components/inventory/item_slot/item_frame.gd")

func _draw() -> void:
	var slot: Control = get_parent()
	if slot.occupied and slot.corner_number > 0:
		FRAME.draw_priority_corner(self, Vector2.ZERO, slot.get_theme_default_font(), slot.corner_number, slot.accent, slot.hovered, 1.0, slot.border_color)
