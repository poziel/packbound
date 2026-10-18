extends SceneTree
## Deterministic native-size canvas: render the same fixed icon slot at each
## consuming font size. H is white so its cap center can be measured separately.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,960)
	root.content_scale_size = Vector2i.ZERO
	var panel := Control.new()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(panel)
	var bg := ColorRect.new()
	bg.color = Color("10151F")
	bg.size = Vector2(1280,960)
	panel.add_child(bg)
	var font: Font = load("res://assets/fonts/ui_pixel.tres")
	var family: Dictionary = PackKeywords.registry()["keywords"]
	var names: Array = family.keys()
	var metrics: Array[Dictionary] = []
	for col in range(3):
		var font_px: int = [16,24,32][col]
		for row in range(names.size()):
			var key: String = names[row]
			var label := RichTextLabel.new()
			panel.add_child(label)
			label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			label.position = Vector2(20+col*420,18+row*40)
			label.size = Vector2(400,38)
			label.bbcode_enabled = true
			label.scroll_active = false
			label.add_theme_font_override("normal_font",font)
			label.add_theme_font_size_override("normal_font_size",font_px)
			label.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
			label.text = PackKeywords.image_markup(key) + "[color=#FFFFFF]H[/color] " + str(family[key]["label"])
			metrics.append({"key":key,"font_px":font_px,"position":[label.position.x,label.position.y],"icon_box_width":16})
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var destination: String = "res://workspace/docs/art/reviews/semantic-icons-v2"
	DirAccess.make_dir_recursive_absolute(destination)
	root.get_texture().get_image().save_png(destination+"/alignment.png")
	var file := FileAccess.open(destination+"/alignment-layout.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"  "))
	file.close()
	print("KEYWORD ALIGNMENT: ",names.size()," icons at 16,24,32px fonts")
	quit()
