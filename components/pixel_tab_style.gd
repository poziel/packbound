@tool
extends StyleBox
## Native tab surface drawn in integer pixel bands, without an outline.

@export var bg_color: Color = Color(0.333, 0.365, 0.424, 1):
	set(value):
		bg_color = value
		emit_changed()
@export_range(0, 24, 1) var corner_radius: int = 8:
	set(value):
		corner_radius = value
		emit_changed()
@export_range(1, 4, 1) var pixel_step: int = 2:
	set(value):
		pixel_step = value
		emit_changed()
@export var round_bottom: bool = true:
	set(value):
		round_bottom = value
		emit_changed()
@export var round_top: bool = true:
	set(value):
		round_top = value
		emit_changed()
@export var top_corner_color: Color = Color.TRANSPARENT:
	set(value):
		top_corner_color = value
		emit_changed()

var _tab_bar: WeakRef
var _selected_surface: bool = false
@export_range(0, 12, 1) var header_separator_width: int = 0:
	set(value):
		header_separator_width = value
		emit_changed()

func bind_inactive_tabs(bar: TabBar) -> void:
	_tab_bar = weakref(bar)
	_selected_surface = false
	bar.queue_redraw()

func bind_selected_tab(bar: TabBar) -> void:
	_tab_bar = weakref(bar)
	_selected_surface = true
	bar.queue_redraw()

func _draw(canvas: RID, area: Rect2) -> void:
	var rect := Rect2(area.position.round(), area.size.floor())
	var radius: int = mini(corner_radius, floori(minf(rect.size.x, rect.size.y) / 2))
	var bottom_left: bool = round_bottom
	var bottom_right: bool = round_bottom
	var round_top_right: bool = round_top
	var join_top_right: bool = false
	var bar: TabBar = _tab_bar.get_ref() if _tab_bar != null else null
	if bar != null and bar.current_tab >= 0 and bar.get_tab_count() > 0:
		var selected: Rect2 = bar.get_tab_rect(bar.current_tab)
		var last: Rect2 = bar.get_tab_rect(bar.get_tab_count() - 1)
		if _selected_surface:
			round_top_right = round_top and (header_separator_width > 0 or not is_equal_approx(rect.end.x, last.end.x))
		else:
			# Inactive neighbors form one gray region. Only its exposed lower
			# endpoints round off; its left edge stays joined to the outer frame.
			bottom_left = round_bottom and is_equal_approx(rect.position.x, selected.end.x)
			bottom_right = round_bottom and (is_equal_approx(rect.end.x, selected.position.x) or is_equal_approx(rect.end.x, last.end.x))
			join_top_right = is_equal_approx(rect.end.x, last.end.x)
			if join_top_right:
				rect.size.x += header_separator_width
	for row in range(0, int(rect.size.y), pixel_step):
		var band: int = mini(pixel_step, int(rect.size.y) - row)
		var top_inset: int = _inset(row + band * 0.5, radius) if round_top else 0
		var right_top_inset: int = _inset(row + band * 0.5, radius) if round_top_right else 0
		var bottom_inset: int = _inset(rect.size.y - row - band * 0.5, radius)
		var left: int = maxi(top_inset, bottom_inset if bottom_left else 0)
		var right: int = maxi(right_top_inset, bottom_inset if bottom_right else 0)
		if top_inset > 0 and top_corner_color.a > 0:
			RenderingServer.canvas_item_add_rect(canvas, Rect2(rect.position + Vector2(0, row), Vector2(top_inset, band)), top_corner_color)
		if right_top_inset > 0 and top_corner_color.a > 0:
			RenderingServer.canvas_item_add_rect(canvas, Rect2(rect.position + Vector2(rect.size.x - right_top_inset, row), Vector2(right_top_inset, band)), top_corner_color)
		RenderingServer.canvas_item_add_rect(canvas, Rect2(rect.position + Vector2(left, row), Vector2(rect.size.x - left - right, band)), bg_color)
		if join_top_right:
			var join: int = _inset(row + band * 0.5, radius)
			if join > 0:
				RenderingServer.canvas_item_add_rect(canvas, Rect2(rect.position + Vector2(rect.size.x, row), Vector2(join, band)), bg_color)

func _inset(distance: float, radius: int) -> int:
	if distance >= radius:
		return 0
	var dy: float = radius - distance
	return ceili((radius - sqrt(maxf(0, radius * radius - dy * dy))) / pixel_step) * pixel_step
