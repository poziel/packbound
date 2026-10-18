@tool
extends TabContainer
## Keeps native tab input and layout while joining neighboring idle surfaces.

@export var header_separator_path: NodePath
@export var join_left_border: bool = false:
	set(value):
		join_left_border = value
		queue_redraw()

func _ready() -> void:
	_bind_surfaces()
	theme_changed.connect(_bind_surfaces)
	get_tab_bar().resized.connect(_sync_separator)
	get_tab_bar().draw.connect(_sync_separator)
	tab_changed.connect(func(_index: int) -> void: _sync_separator(); queue_redraw())
	get_tab_bar().resized.connect(queue_redraw)
	_sync_separator.call_deferred()

func _draw() -> void:
	if not join_left_border or current_tab <= 0:
		return
	var idle: StyleBox = get_theme_stylebox("tab_unselected")
	if not idle.has_method("bind_inactive_tabs"):
		return
	var radius: int = idle.get("corner_radius")
	var step: int = idle.get("pixel_step")
	var color: Color = idle.get("bg_color")
	var bar_bottom: float = get_tab_bar().get_rect().end.y
	for row in range(0, radius, step):
		var band: int = mini(step, radius - row)
		var dy: float = radius - row - band * 0.5
		var inset: int = ceili((radius - sqrt(maxf(0, radius * radius - dy * dy))) / step) * step
		draw_rect(Rect2(Vector2(0, bar_bottom + row), Vector2(inset, band)), color)

func _sync_separator() -> void:
	if header_separator_path.is_empty() or get_tab_count() == 0:
		return
	var separator: Control = get_node_or_null(header_separator_path)
	if separator == null:
		return
	var bar := get_tab_bar()
	var end: float = bar.get_tab_rect(get_tab_count() - 1).end.x
	separator.position = bar.global_position - separator.get_parent_control().global_position + Vector2(end, 0)
	separator.size.y = bar.size.y
	# An inactive last tab already paints this gray strip and its lower curve.
	separator.visible = current_tab == get_tab_count() - 1

func _bind_surfaces() -> void:
	for style_name: String in ["tab_unselected", "tab_hovered", "tab_disabled"]:
		var style: StyleBox = get_theme_stylebox(style_name)
		if style.has_method("bind_inactive_tabs"):
			style.bind_inactive_tabs(get_tab_bar())
	var selected: StyleBox = get_theme_stylebox("tab_selected")
	if selected.has_method("bind_selected_tab"):
		selected.bind_selected_tab(get_tab_bar())
