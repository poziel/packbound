extends "res://tests/support/test_case.gd"

func _initialize() -> void:
	if not require_isolation():
		return
	var bar = load("res://components/ui/indicators/pixel_stat_bar/pixel_stat_bar.tscn").instantiate()
	root.add_child(bar)
	bar.set_protected_amount(30, 40, 15)
	check(bar.value == 30 and bar.max_value == 40, "Contract: bar.value == 30 and bar.max_value == 40")
	check(bar.get_value_text() == "30 / 40 +15", "Contract: bar.get_value_text() == \"30 / 40 +15\"")
	check(is_equal_approx(bar.ratio, 0.75), "Contract: is_equal_approx(bar.ratio, 0.75)")
	check(bar.protection_pattern, "Contract: bar.protection_pattern")
	bar.set_protected_amount(30, 40, 130)
	check(is_equal_approx(bar.ratio, 0.75), "Contract: is_equal_approx(bar.ratio, 0.75)")
	check(bar.get_value_text() == "30 / 40 +130", "Contract: bar.get_value_text() == \"30 / 40 +130\"")
	bar.set_protected_amount(30, 40, 0)
	check(bar.value == 30 and not bar.protection_pattern, "Contract: bar.value == 30 and not bar.protection_pattern")
	bar.segmented = true
	bar.number_mode = PixelStatBar.NumberMode.HIDDEN
	bar.set_amount(1, 1)
	check(bar.resource_width() == bar.segment_width + 6, "One resource point includes its fixed six-pixel frame")
	check(bar.get_minimum_size().x <= bar.resource_width(), "Contract: bar.get_minimum_size().x <= bar.resource_width()")
	bar.set_amount(2, 4)
	check(bar.get_value_text().is_empty(), "Contract: bar.get_value_text().is_empty()")
	check(bar.segment_rects(Rect2(0, 0, 190, 8)).size() == 4, "Contract: bar.segment_rects(Rect2(0, 0, 190, 8)).size() == 4")
	check(bar.segment_rects(Rect2(0, 0, bar.resource_width() - 6, 8))[0].size.x == bar.segment_width, "Natural four-point well retains pixel segment width")
	bar.set_amount(2, 10)
	check(bar.segment_rects(Rect2(0, 0, bar.resource_width() - 6, 8))[0].size.x == bar.segment_width, "Natural ten-point well retains pixel segment width")
	bar.set_amount(2, 100)
	check(bar.segment_rects(Rect2(0, 0, 190, 8)).is_empty(), "Contract: bar.segment_rects(Rect2(0, 0, 190, 8)).is_empty()")
	bar.set_amount(0, 0)
	check(bar.segment_rects(Rect2(0, 0, 190, 8)).is_empty(), "Contract: bar.segment_rects(Rect2(0, 0, 190, 8)).is_empty()")
	report("character_resource_bars")
	quit()
