extends Control

signal new_run_requested
signal run_chosen(id: String)
signal back_requested

const PORTRAIT = preload("res://components/character_preview/character_preview.tscn")
const SLOT = preload("res://components/item_slot/item_slot.tscn")
const ICON_BUTTON = preload("res://components/menu_button/simple_menu_icon_button.tscn")
const HOLD_ICON_BUTTON = preload("res://components/menu_button/hold_simple_menu_icon_button.tscn")
const ROW = preload("res://scripts/descent_row.gd")
var saves = preload("res://scripts/run_saves.gd").new()
@onready var rows: VBoxContainer = $Margin/Layout/Scroll/Rows
@onready var message: Label = $Margin/Layout/Message
@onready var inventory_preview: Control = $InventoryPreview

func _ready() -> void:
	$Margin/Layout/Actions/NewRun.pressed.connect(func() -> void: new_run_requested.emit())
	$Margin/Layout/Actions/Back.pressed.connect(func() -> void: back_requested.emit())
	inventory_preview.closed.connect(func() -> void: $Margin.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			inventory_preview.hide()
			$Margin.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	)

func refresh() -> void:
	inventory_preview.hide()
	$Margin.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var entries: Array[Dictionary] = saves.unfinished()
	message.hide()
	for entry: Dictionary in entries:
		_add_run(entry)
	$Margin/Layout/Actions/NewRun.grab_focus()

func show_error(text: String) -> void:
	message.text = text
	message.show()

func _add_run(entry: Dictionary) -> void:
	var state: Dictionary = entry.state
	var row = ROW.new()
	row.name = "Run_" + entry.id
	row.custom_minimum_size = Vector2(0, 144)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(row)
	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 16
	layout.offset_top = 16
	layout.offset_right = -16
	layout.offset_bottom = -16
	layout.add_theme_constant_override("separation", 24)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(layout)
	var portrait = PORTRAIT.instantiate()
	portrait.custom_minimum_size = Vector2(104, 104)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.texture = PackArt.character_head(state.class_key)
	layout.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 8)
	layout.add_child(info)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 24)
	info.add_child(heading)
	var title := Label.new()
	title.text = PackCatalog.classes()[state.class_key]["name"]
	title.add_theme_font_size_override("font_size", 24)
	heading.add_child(title)
	row.text_labels.append(title)
	var details := Label.new()
	var seconds: int = int(entry.get("elapsed", 0.0))
	details.text = "Floor %d / %d    •    %02d:%02d:%02d played" % [state.fight + 1, PackRun.FLOORS, seconds / 3600, (seconds / 60) % 60, seconds % 60]
	details.add_theme_color_override("font_color", get_theme_color("header", "PackSurface"))
	heading.add_child(details)
	row.text_labels.append(details)
	var items := HBoxContainer.new()
	items.name = "Relics"
	items.add_theme_constant_override("separation", 8)
	info.add_child(items)
	for index in range(mini(8, state.relics.size())):
		var relic: String = state.relics[index]
		var slot = SLOT.instantiate()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.occupied = true
		items.add_child(slot)
		var art := TextureRect.new()
		art.texture = PackArt.relic(relic)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 16
		art.offset_top = 16
		art.offset_right = -16
		art.offset_bottom = -16
		slot.add_child(art)
	if state.relics.is_empty():
		var empty := Label.new()
		empty.text = "No relics"
		items.add_child(empty)
		row.text_labels.append(empty)
	if state.relics.size() > 8:
		var more := Label.new()
		more.text = "+%d more" % (state.relics.size() - 8)
		items.add_child(more)
		row.text_labels.append(more)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_theme_constant_override("separation", 4)
	layout.add_child(actions)
	var delete_button: Button = HOLD_ICON_BUTTON.instantiate()
	delete_button.name = "Delete"
	delete_button.icon = load("res://assets/ui/icons/minimal-controls/close.png")
	delete_button.theme_type_variation = &"DangerSimpleMenuIconButton"
	delete_button.tooltip_text = "Hold for 1.2 seconds to delete this run"
	delete_button.accessibility_name = "Delete %s run" % title.text
	delete_button.accessibility_description = "Hold for 1.2 seconds to permanently delete this saved run. Release early to cancel."
	delete_button.connect("confirmed", _delete_run.bind(entry.id))
	actions.add_child(delete_button)
	var preview_button: Button = ICON_BUTTON.instantiate()
	preview_button.name = "Inventory"
	preview_button.icon = load("res://assets/ui/icons/navigation-v4/backpack.png")
	preview_button.tooltip_text = "Preview inventory"
	preview_button.accessibility_name = "Preview %s inventory, floor %d" % [title.text, state.fight + 1]
	preview_button.accessibility_description = "Open a read-only preview of this run's inventory."
	preview_button.pressed.connect(_open_inventory.bind(entry, preview_button))
	actions.add_child(preview_button)
	var resume_button: Button = ICON_BUTTON.instantiate()
	resume_button.name = "Resume"
	resume_button.icon = load("res://assets/ui/icons/minimal-controls/next.png")
	resume_button.theme_type_variation = &"SuccessSimpleMenuIconButton"
	resume_button.tooltip_text = "Resume run"
	resume_button.accessibility_name = "Resume %s, floor %d" % [title.text, state.fight + 1]
	resume_button.accessibility_description = "Continue this saved run."
	resume_button.pressed.connect(func() -> void: run_chosen.emit(entry.id))
	actions.add_child(resume_button)
	row.accessibility_name = "%s, %s" % [title.text, details.text]

func _open_inventory(entry: Dictionary, button: Control) -> void:
	inventory_preview.open(entry, button)
	$Margin.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED

func _delete_run(id: String) -> void:
	if not saves.remove(id):
		show_error("Could not delete this descent.")
		return
	refresh()
