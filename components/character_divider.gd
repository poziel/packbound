@tool
extends ColorRect
## Round the room and sheet openings where they meet the shared five-pixel seam.

@export var tabs_path: NodePath = ^"../CharacterPanel/Tabs"
@export_range(0, 32, 1) var corner_radius: int = 12:
	set(value):
		corner_radius = value
		queue_redraw()
@export_range(1, 4, 1) var pixel_step: int = 2:
	set(value):
		pixel_step = value
		queue_redraw()

@onready var tabs: TabContainer = get_node(tabs_path)

func _ready() -> void:
	tabs.tab_changed.connect(func(_index: int) -> void: queue_redraw())
	tabs.get_tab_bar().resized.connect(queue_redraw)
	tabs.get_parent_control().item_rect_changed.connect(queue_redraw)
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(tabs):
		return
	var bounds: Rect2 = tabs.get_parent_control().get_global_rect()
	var top: float = roundf(bounds.position.y - global_position.y)
	var bottom: float = roundf(bounds.end.y - global_position.y)
	var sheet_left: float = roundf(bounds.position.x - global_position.x)
	var sheet_top: float = roundf(tabs.get_tab_bar().get_global_rect().end.y - global_position.y)
	var radius: int = mini(corner_radius, floori((bottom - top) / 2))
	for row in range(0, radius, pixel_step):
		var band: int = mini(pixel_step, radius - row)
		var dy: float = radius - row - band * 0.5
		var inset: int = ceili((radius - sqrt(maxf(0, radius * radius - dy * dy))) / pixel_step) * pixel_step
		# Both room corners and the sheet's lower-left corner are permanent.
		draw_rect(Rect2(Vector2(-inset, top + row), Vector2(inset, band)), color)
		draw_rect(Rect2(Vector2(-inset, bottom - row - band), Vector2(inset, band)), color)
		draw_rect(Rect2(Vector2(sheet_left, bottom - row - band), Vector2(inset, band)), color)
		# When the first tab is selected, its own upper-left corner makes the join.
		if tabs.current_tab > 0:
			draw_rect(Rect2(Vector2(sheet_left, sheet_top + row), Vector2(inset, band)), color)
