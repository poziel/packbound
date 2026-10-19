@tool
extends Control
## A UI status glyph, kept separate from item artwork and crafting controls.

func _draw() -> void:
	var ink := Color("e8cf8f")
	draw_rect(Rect2(4, 10, 16, 12), ink)
	draw_rect(Rect2(7, 2, 10, 10), ink)
	draw_rect(Rect2(9, 4, 6, 6), Color("171014"))
	draw_rect(Rect2(11, 14, 2, 5), Color("171014"))
