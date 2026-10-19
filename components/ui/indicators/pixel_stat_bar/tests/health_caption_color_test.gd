extends "res://tests/support/test_case.gd"

class MeasuredBar extends PixelStatBar:
	var health_tint: Color
	var block_tint: Color
	func _draw_side_box(rect: Rect2, amount: float, tint: Color, icon: Texture2D = null, caption: String = "") -> void:
		if caption.is_empty():
			block_tint = tint
		else:
			health_tint = tint
		super._draw_side_box(rect, amount, tint, icon, caption)

func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("_run")

func _run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(500, 160)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var bar := MeasuredBar.new()
	bar.side_boxes = true
	bar.size = Vector2(450, 80)
	view.add_child(bar)
	bar.set_amount(23, 40)
	bar.set_protected_amount(23, 40, 12)
	await process_frame
	await RenderingServer.frame_post_draw
	check(bar.health_tint.is_equal_approx(Color("bdbdbd")), "Resting health text matches border")
	check(bar.block_tint.is_equal_approx(bar.protection_color), "Block keeps its own color")
	bar.glow_enabled = true
	await process_frame
	await RenderingServer.frame_post_draw
	check(bar.health_tint.is_equal_approx(Color("bdbdbd").darkened(0.55)), "Health text follows border feedback")
	view.queue_free()
	await process_frame
	report("health_caption_color")
	quit()
