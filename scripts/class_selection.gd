extends Control

signal class_chosen(key: String)
signal back_requested

@onready var scroll: ScrollContainer = $RosterScroll
@onready var grid: GridContainer = $RosterScroll/Margin/Characters
@onready var inspector: PackInspector = $Inspector
@onready var back: Button = $Back
var buttons: Dictionary = {}

func _ready() -> void:
	back.pressed.connect(func() -> void: back_requested.emit())
	visibility_changed.connect(_visibility_changed)
	scroll.get_v_scroll_bar().value_changed.connect(_scrolled)
	for child in grid.get_children():
		if not child is Button or child.disabled:
			continue
		var button: Button = child
		buttons[button.class_key] = button
		button.pressed.connect(_choose.bind(button))
		button.focus_entered.connect(_focus.bind(button))
		inspector.register(button, _character_inspection.bind(button.class_key))
	for index in range(maxi(0, 18 - grid.get_child_count())):
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(144, 96)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(cell)
		var empty = preload("res://components/character_preview/character_preview.tscn").instantiate()
		empty.name = "FutureDelver%d" % index
		empty.texture = null
		empty.position = Vector2(32, 0)
		empty.size = Vector2(80, 80)
		empty.modulate.a = 0.3
		empty.focus_mode = Control.FOCUS_NONE
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(empty)
	_wire_navigation()

func _wire_navigation() -> void:
	var tiles: Array = buttons.values()
	for index in range(tiles.size()):
		var tile: Button = tiles[index]
		var above: Control = tiles[index - grid.columns] if index >= grid.columns else tile
		var below: Control = tiles[index + grid.columns] if index + grid.columns < tiles.size() else back
		var left: Control = tiles[index - 1] if index % grid.columns > 0 else tile
		var right: Control = tiles[index + 1] if index % grid.columns < grid.columns - 1 and index + 1 < tiles.size() else tile
		tile.focus_neighbor_top = tile.get_path_to(above)
		tile.focus_neighbor_bottom = tile.get_path_to(below)
		tile.focus_neighbor_left = tile.get_path_to(left)
		tile.focus_neighbor_right = tile.get_path_to(right)
	if not tiles.is_empty():
		back.focus_neighbor_top = back.get_path_to(tiles.back())

func _choose(button: Button) -> void:
	inspector.clear()
	class_chosen.emit(button.class_key)

func _focus(button: Button) -> void:
	scroll.ensure_control_visible(button)

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		inspector.clear()

func _scrolled(_value: float) -> void:
	inspector.clear()

func _process(_delta: float) -> void:
	inspector.enabled = is_visible_in_tree()
	var flow: Node = get_parent()
	if flow is PackMenuFlow:
		inspector.enabled = inspector.enabled and bool(flow.settings["tooltips"]) and (not is_instance_valid(flow.loading_screen) or not flow.loading_screen.active)
		inspector.lock_delay = float(flow.settings["tooltip_lock_delay"])

func _character_inspection(key: String) -> Dictionary:
	var character: Dictionary = PackCatalog.classes()[key]
	var starting := PackRun.new()
	starting.reset(0, key)
	var stats: String = "%d HP / %d mana" % [starting.max_hp, starting.starting_resources()["mana"]]
	if starting.undead_companions > 0:
		stats += " / %d thrall" % starting.undead_companions
	var loadout := PackedStringArray()
	for item: String in character["starters"]:
		loadout.append(PackCatalog.item(item)["name"])
	return {"key": "class_" + key, "title": character["name"] + " / " + character["mechanic"], "icon": PackArt.character_head(key), "body": character["detail"] + "\n\n" + stats + "\n\nStarting items\n" + "\n".join(loadout)}
