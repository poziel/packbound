extends "res://components/menu_button/hold_menu_button.gd"

const TOOLTIP: PackedScene = preload("res://components/menu_button/simple_gameplay_tooltip.tscn")

func _make_custom_tooltip(for_text: String) -> Object:
	var tooltip: Control = TOOLTIP.instantiate()
	var label: Label = tooltip.get_node("Label")
	label.text = for_text
	return tooltip
