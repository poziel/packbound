extends Control
## F6: exercise live overflow, focus following and both scrollbar directions.

const SCROLLER: PackedScene = preload("pixel_scroll_container.tscn")
var list: VBoxContainer
var scroller: ScrollContainer
var count_label: Label
var item_count: int = 0


func _ready() -> void:
	theme = preload("res://themes/gameplay/theme.tres")
	var background: ColorRect = ColorRect.new()
	background.color = Color("10121b")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_label("PIXEL SCROLLBAR", Vector2(48, 26), 36, Color("d7ba7e"))
	_label("Wheel / drag the grip / click the track / focus following", Vector2(48, 76), 20)
	_label("LIVE ITEM LIST", Vector2(48, 132), 24, Color("d7ba7e"))
	_label("BATTLE RECORD", Vector2(696, 132), 24, Color("d7ba7e"))
	scroller = SCROLLER.instantiate()
	scroller.name = "ItemScroll"
	scroller.position = Vector2(48, 174)
	scroller.size = Vector2(588, 420)
	add_child(scroller)
	list = VBoxContainer.new()
	list.name = "Items"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroller.add_child(list)
	for index in range(18):
		_add_item()
	var record: RichTextLabel = RichTextLabel.new()
	record.name = "Record"
	record.position = Vector2(696, 174)
	record.size = Vector2(536, 420)
	record.bbcode_enabled = true
	for index in range(24):
		record.text += "[color=#d7ba7e]TURN %02d[/color]  The descent continues.\nRecovered supplies. Your pack holds.\n\n" % (index + 1)
	add_child(record)
	_button("Add item", Vector2(48, 614), _add_item)
	_button("Remove item", Vector2(232, 614), _remove_item)
	_button("Clear list", Vector2(416, 614), _clear_items)
	count_label = _label("", Vector2(48, 674), 20)
	_update_count()
	_label("HORIZONTAL", Vector2(696, 614), 20, Color("d7ba7e"))
	var horizontal: ScrollContainer = SCROLLER.instantiate()
	horizontal.name = "HorizontalScroll"
	horizontal.position = Vector2(696, 648)
	horizontal.size = Vector2(536, 96)
	horizontal.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	horizontal.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(horizontal)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	horizontal.add_child(row)
	for index in range(10):
		var slot: Button = Button.new()
		slot.text = "SLOT %02d" % (index + 1)
		slot.custom_minimum_size = Vector2(144, 60)
		row.add_child(slot)


func _add_item() -> void:
	item_count += 1
	var item: Button = Button.new()
	item.text = "%02d    %s" % [item_count, ["Iron Charm", "Grave Bandage", "Ember Grimoire", "Cracked Shield"][posmod(item_count - 1, 4)]]
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size.y = 56
	list.add_child(item)
	_update_count()


func _remove_item() -> void:
	if list.get_child_count() > 0:
		var item: Node = list.get_child(-1)
		list.remove_child(item)
		item.queue_free()
	_update_count()


func _clear_items() -> void:
	for item: Node in list.get_children():
		list.remove_child(item)
		item.queue_free()
	_update_count()


func _update_count() -> void:
	if count_label != null:
		count_label.text = "%d items / scrollbar hides when the list fits" % list.get_child_count()


func _label(text: String, at: Vector2, font_size: int, color: Color = Color("b5b0c3")) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _button(text: String, at: Vector2, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(172, 44)
	button.pressed.connect(action)
	add_child(button)
