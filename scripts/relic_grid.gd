@tool
extends GridContainer

signal slots_changed

const SLOT: PackedScene = preload("res://components/item_slot/item_slot.tscn")
const COLUMNS: int = 6
const GAP: int = 6
const MARGIN: Vector2 = Vector2(22, 22)
var _queued: bool = false

func _ready() -> void:
	columns = COLUMNS
	add_theme_constant_override("h_separation", GAP)
	add_theme_constant_override("v_separation", GAP)
	get_parent().resized.connect(_queue_layout)
	visibility_changed.connect(_queue_layout)
	_queue_layout()

func _queue_layout() -> void:
	if _queued:
		return
	_queued = true
	_layout_slots.call_deferred()

func _layout_slots() -> void:
	_queued = false
	if not is_inside_tree():
		return
	var page: Control = get_parent()
	var padding: int = page.get_theme_constant("content_padding", "PackSurface")
	var margin := Vector2.ONE * padding
	var available: Vector2 = page.size - margin * 2
	if available.x < COLUMNS * 16 or available.y < 16:
		return
	var side: int = maxi(16, floori((available.x - GAP * (COLUMNS - 1)) / COLUMNS / 2) * 2)
	var rows: int = maxi(1, floori((available.y + GAP) / (side + GAP)))
	var count: int = rows * COLUMNS
	var added: bool = false
	while get_child_count() < count:
		var slot: Panel = SLOT.instantiate()
		slot.name = "Slot%d" % (get_child_count() + 1)
		add_child(slot)
		if Engine.is_editor_hint():
			slot.owner = get_tree().edited_scene_root
		added = true
	for index in range(get_child_count()):
		var slot: Control = get_child(index)
		slot.visible = index < count
		slot.custom_minimum_size = Vector2.ONE * side
	var extent := Vector2(COLUMNS * side + (COLUMNS - 1) * GAP, rows * side + (rows - 1) * GAP)
	position = Vector2(floorf((page.size.x - extent.x) / 4) * 2, margin.y)
	size = extent
	queue_sort()
	if added:
		slots_changed.emit()
