extends Control

signal closed

const SLOT = preload("res://components/item_slot/item_slot.tscn")
var run: PackRun
var return_focus: Control
@onready var board: BackpackBoard = $Panel/Margin/Layout/Scroll/Contents/Board
@onready var unused: GridContainer = $Panel/Margin/Layout/Scroll/Contents/Storage/Items

func _ready() -> void:
	$Panel/Margin/Layout/Close.pressed.connect(close)
	var panel_style: StyleBox = $Panel.get_theme_stylebox("panel").duplicate()
	if panel_style is StyleBoxTexture:
		panel_style.modulate_color = Color.WHITE
	$Panel.add_theme_stylebox_override("panel", panel_style)

func open(saved: Dictionary, focus_target: Control) -> void:
	return_focus = focus_target
	run = PackRun.new()
	preload("res://scripts/run_saves.gd").new().restore(run, saved)
	board.run = run
	board.refresh()
	$Panel/Margin/Layout/Title.text = "%s / INVENTORY" % PackCatalog.classes()[run.class_key]["name"]
	for child in unused.get_children():
		unused.remove_child(child)
		child.queue_free()
	for item: Dictionary in run.items:
		if item.cell != null:
			continue
		var slot = SLOT.instantiate()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.occupied = true
		slot.tooltip_text = item.name
		unused.add_child(slot)
		var art := TextureRect.new()
		art.texture = PackArt.item(item.key)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 8
		art.offset_top = 8
		art.offset_right = -8
		art.offset_bottom = -8
	$Panel/Margin/Layout/Scroll/Contents/Storage/Empty.visible = unused.get_child_count() == 0
	show()
	$Panel/Margin/Layout/Close.grab_focus()

func close() -> void:
	hide()
	closed.emit()
	if is_instance_valid(return_focus):
		return_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
