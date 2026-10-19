extends "res://tests/support/test_case.gd"

func _initialize() -> void:
	if not require_isolation():
		return
	var button := PackPixelButton.new()
	button.size = Vector2(160, 64)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var image: Image = button.create_styleboxes(Vector2i(160, 64))[state].texture.get_image()
		var offset := 2 if state == "pressed" else 0
		for y in [2, 3]:
			check_equal(image.get_pixel(80, y + offset).a, 0.0, "2 px transparent frame gap in " + state)
		check(image.get_pixel(80, offset).a != 0 and image.get_pixel(80, 4 + offset).a != 0, "Border and face surround the gap in " + state)
	button.free()
	var game: Theme = load("res://themes/gameplay/theme.tres")
	var menu: Theme = load("res://themes/menu/theme.tres")
	check_equal(game.get_stylebox("normal", "Button").get_script(), menu.get_stylebox("normal", "Button").get_script(), "Native framed buttons share their renderer")
	report("SHARED BUTTON FRAME")
	quit(1 if failures else 0)
