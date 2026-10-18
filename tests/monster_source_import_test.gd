extends SceneTree

func _initialize() -> void:
	var checked := 0
	var failures := 0
	var root_path := "res://workspace/docs/art/concepts/monsters/"
	for folder: String in DirAccess.get_directories_at(root_path):
		var base := root_path + folder + "/sprite"
		if not FileAccess.file_exists(base + ".svg"):
			continue
		var png := Image.load_from_file(base + ".png")
		var svg := Image.new()
		var result := svg.load_svg_from_string(FileAccess.get_file_as_string(base + ".svg"))
		if result != OK:
			failures += 1
			printerr("FAIL: ", folder, " SVG decode ", result)
			continue
		png.convert(Image.FORMAT_RGBA8)
		svg.convert(Image.FORMAT_RGBA8)
		if png.get_size() != svg.get_size() or png.get_data() != svg.get_data():
			failures += 1
			printerr("FAIL: ", folder, " native Godot SVG raster differs from PNG")
		checked += 1
	print("MONSTER SOURCE IMPORT RESULT: %d sources, %d failures" % [checked, failures])
	quit(1 if failures else 0)
