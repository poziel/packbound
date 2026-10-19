extends Control
## All controls are saved scene instances; this script only wires the demo.
var activation_count: int = 0

func _ready() -> void:
	for node: Node in get_children():
		if node is PackPixelButton:
			var button: PackPixelButton = node
			if button.name.begins_with("Tint"):
				button.pressed.connect(_set_palette.bind(button.face_color, button.tooltip_text))
			else:
				button.pressed.connect(_activated.bind(button))
	$Status.text = "Try a button. Tab + Enter works too; cutouts pass clicks through."

func _activated(button: PackPixelButton) -> void:
	activation_count += 1
	var label: String = button.tooltip_text if not button.tooltip_text.is_empty() else button.text
	var suffix: String = " / selected" if button.toggle_mode and button.button_pressed else ""
	$Status.text = "%s%s  /  %d activations" % [label, suffix, activation_count]

func _set_palette(color: Color, label: String) -> void:
	for path: String in ["Attack", "Square", "Hexagon", "Diamond", "LShape", "TShape", "Chevron", "CustomContent"]:
		get_node(path).face_color = color
	$Status.text = "%s palette applied. Every shape uses the same border and face." % label
