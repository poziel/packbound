extends SceneTree

func _initialize() -> void:
	var failed := false
	var button := PackPixelButton.new()
	button.size = Vector2(160, 64)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var image: Image = button.create_styleboxes(Vector2i(160, 64))[state].texture.get_image()
		var offset := 2 if state == "pressed" else 0
		for y in [2, 3]:
			if image.get_pixel(80, y + offset).a != 0:
				printerr("FAIL: 2 px transparent frame gap in " + state)
				failed = true
		if image.get_pixel(80, offset).a == 0 or image.get_pixel(80, 4 + offset).a == 0:
			printerr("FAIL: border and face surround the gap in " + state)
			failed = true
	button.free()
	var game: Theme = load("res://themes/gameplay/theme.tres")
	var menu: Theme = load("res://themes/menu/theme.tres")
	if game.get_stylebox("normal", "Button").get_script() != menu.get_stylebox("normal", "Button").get_script():
		printerr("FAIL: native framed buttons share their renderer")
		failed = true
	print("Shared button frame: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
