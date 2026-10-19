@tool
class_name PixelSearchField
extends LineEdit
## Reusable pixel search input. Optional list binding filters direct Control rows.
## Native text_changed/text_submitted signals remain available for custom data lists.

signal results_filtered(visible_count: int, total_count: int)

@export_group("Pixel Style")
@export var surface_color: Color = Color("171e29"):
	get:
		return _appearance_value("surface_color", Color("171e29"))
	set(value):
		_appearance_overrides["surface_color"] = value
		_refresh_skin()
@export var accent_color: Color = Color("b8b879"):
	get:
		return _appearance_value("accent_color", Color("b8b879"))
	set(value):
		_appearance_overrides["accent_color"] = value
		_refresh_skin()
@export var ink_color: Color = Color("eeeedb"):
	get:
		return _appearance_value("ink_color", Color("eeeedb"))
	set(value):
		_appearance_overrides["ink_color"] = value
		_refresh_skin()
@export_range(1, 3, 1) var pixel_size: int = 2:
	get:
		return _appearance_value("pixel_size", 2)
	set(value):
		_appearance_overrides["pixel_size"] = clampi(value, 1, 3)
		_refresh_skin()

@export_group("List Filtering")
## Optional VBoxContainer/GridContainer of rows. Leave empty to use signals only.
@export_node_path("Container") var list_path: NodePath:
	set(value):
		list_path = value
		if is_node_ready() and not Engine.is_editor_hint():
			_bind_list()
## Optional Label outside the list; shown only when no rows match.
@export_node_path("Label") var empty_state_path: NodePath
## Rows can provide this metadata instead of searching their descendant labels.
@export var search_metadata: StringName = &"search_text"

var _list: Container
var _row_visibility: Dictionary = {}
var _skin_signature: String = ""
var _search_icon: Texture2D
var _hovered: bool = false

func _ready() -> void:
	_refresh_skin()
	if Engine.is_editor_hint():
		return
	text_changed.connect(_on_text_changed)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	_bind_list()

func _exit_tree() -> void:
	_unbind_list()

func _set_hovered(value: bool) -> void:
	_hovered = value
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not has_focus() or is_menu_visible() or not event.is_action_pressed("ui_cancel"):
		return
	if editable and not text.is_empty():
		set_query("")
		edit()
	else:
		release_focus()
	get_viewport().set_input_as_handled()

## Use this when changing the query from code; LineEdit.text does not emit text_changed.
func set_query(value: String) -> void:
	if text == value:
		return
	text = value
	caret_column = text.length()
	text_changed.emit(text)

func _on_text_changed(_value: String) -> void:
	refresh_filter()

## Case-insensitive partial matches. Every whitespace-separated word must match.
func matches(candidate: String) -> bool:
	var haystack: String = candidate.to_lower()
	for word: String in _query_words():
		if not haystack.contains(word):
			return false
	return true

func _query_words() -> PackedStringArray:
	return text.to_lower().replace("\t", " ").replace("\n", " ").replace("\r", " ").split(" ", false)

func _unbind_list() -> void:
	if is_instance_valid(_list) and _list.child_order_changed.is_connected(_schedule_filter):
		_list.child_order_changed.disconnect(_schedule_filter)
	for row: Variant in _row_visibility:
		if is_instance_valid(row):
			row.visible = _row_visibility[row]
	_row_visibility.clear()
	_list = null

func _bind_list() -> void:
	_unbind_list()
	if list_path.is_empty():
		return
	_list = get_node_or_null(list_path) as Container
	if _list == null or _list.is_ancestor_of(self):
		_list = null
		push_warning("PixelSearchField: List Path must point to a separate row container.")
		return
	_list.child_order_changed.connect(_schedule_filter)
	refresh_filter()

func _schedule_filter() -> void:
	refresh_filter.call_deferred()

## Call after changing row text or metadata. Added/removed rows refresh automatically.
## Initially hidden rows stay hidden. search_excluded metadata also excludes a row.
func refresh_filter() -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_list):
		return
	var empty_label: Label = get_node_or_null(empty_state_path) as Label if not empty_state_path.is_empty() else null
	var rows: Array[Node] = _list.get_children()
	for previous: Variant in _row_visibility.keys():
		if not is_instance_valid(previous):
			_row_visibility.erase(previous)
		elif previous not in rows:
			previous.visible = _row_visibility[previous]
			_row_visibility.erase(previous)
	var count: int = 0
	var total: int = 0
	var words: PackedStringArray = _query_words()
	for child: Node in rows:
		if not child is Control or child == empty_label:
			continue
		var row: Control = child
		if not _row_visibility.has(row):
			_row_visibility[row] = row.visible
		var eligible: bool = _row_visibility[row] and not bool(row.get_meta(&"search_excluded", false))
		var matched: bool = eligible
		if eligible:
			total += 1
			var searchable: String = _row_text(row).to_lower()
			for word: String in words:
				if not searchable.contains(word):
					matched = false
					break
		row.visible = matched
		if matched:
			count += 1
	if empty_label != null:
		empty_label.visible = count == 0
		empty_label.text = "No entries yet." if total == 0 else "No matches. Try another search or clear the field."
	results_filtered.emit(count, total)

func _row_text(node: Node) -> String:
	if node.has_meta(search_metadata):
		return str(node.get_meta(search_metadata))
	var parts: PackedStringArray = PackedStringArray()
	if node is Label or node is Button:
		parts.append(node.text)
	elif node is RichTextLabel:
		parts.append(node.get_parsed_text())
	for child: Node in node.get_children():
		parts.append(_row_text(child))
	return " ".join(parts)

func _validate_property(property: Dictionary) -> void:
	if property["name"] in ["surface_color", "accent_color", "ink_color", "pixel_size"] and not _appearance_overrides.has(property["name"]):
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_STORAGE
	# Generated StyleBoxes exclude cached textures through runtime_pixel_style.gd.

func _refresh_skin() -> void:
	if not is_inside_tree():
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var kind: StringName = theme_type_variation if not theme_type_variation.is_empty() else &"PixelSearchField"
	var clear_icon: Texture2D = get_theme_icon("clear", kind) if has_theme_icon("clear", kind) else preload("clear.svg")
	var search_icon: Texture2D = get_theme_icon("search", kind) if has_theme_icon("search", kind) else preload("search.svg")
	var signature: String = str([surface_color, accent_color, ink_color, pixel_size, clear_icon.get_instance_id(), search_icon.get_instance_id()])
	if signature == _skin_signature:
		return
	_skin_signature = signature
	add_theme_stylebox_override("normal", _frame(false, false))
	add_theme_stylebox_override("read_only", _frame(false, true))
	add_theme_stylebox_override("focus", _frame(true, false))
	add_theme_color_override("font_color", ink_color)
	add_theme_color_override("font_placeholder_color", ink_color.lerp(surface_color, 0.35))
	add_theme_color_override("font_uneditable_color", ink_color.lerp(surface_color, 0.55))
	add_theme_color_override("font_selected_color", ink_color)
	add_theme_color_override("selection_color", accent_color.darkened(0.65))
	add_theme_color_override("caret_color", accent_color.lightened(0.3))
	add_theme_color_override("clear_button_color", ink_color.lerp(surface_color, 0.25))
	add_theme_color_override("clear_button_color_pressed", accent_color)
	add_theme_constant_override("caret_width", pixel_size)
	add_theme_constant_override("minimum_character_width", 8)
	add_theme_icon_override("clear", clear_icon)
	_search_icon = search_icon
	queue_redraw()

func _frame(focused: bool, read_only: bool) -> StyleBoxTexture:
	var picture: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	picture.fill(Color.TRANSPARENT)
	var rim: Color = accent_color.darkened(0.55 if read_only else 0.35)
	for y: int in range(24):
		for x: int in range(24):
			var edge: int = mini(mini(x, 23 - x), mini(y, 23 - y))
			var corner: int = mini(x, 23 - x) + mini(y, 23 - y)
			if corner < 2:
				continue
			if focused:
				if edge == 0 or corner == 2:
					picture.set_pixel(x, y, accent_color.lightened(0.2))
				continue
			var color: Color = surface_color
			if edge == 0 or corner == 2:
				color = Color("0b101a")
			elif edge == 1:
				color = rim if y < 12 else rim.lerp(Color("534971"), 0.55)
			elif edge == 2:
				color = surface_color.darkened(0.35) if y < 12 else surface_color.lightened(0.08)
			picture.set_pixel(x, y, color)
	picture.resize(24 * pixel_size, 24 * pixel_size, Image.INTERPOLATE_NEAREST)
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.set_script(preload("res://components/ui/shared/runtime_pixel_style.gd"))
	style.texture = ImageTexture.create_from_image(picture)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 4 * pixel_size)
	style.content_margin_left = 22 * pixel_size
	style.content_margin_right = 8 * pixel_size
	style.content_margin_top = 6 * pixel_size
	style.content_margin_bottom = 6 * pixel_size
	return style

func _draw() -> void:
	if _search_icon == null:
		return
	var color: Color = accent_color if has_focus() or _hovered else ink_color.lerp(surface_color, 0.35)
	if not editable:
		color = color.lerp(surface_color, 0.5)
	var at: Vector2 = Vector2(7 * pixel_size, floorf((size.y - 10 * pixel_size) / 2))
	draw_texture_rect(_search_icon, Rect2(at, Vector2(10, 10) * pixel_size), false, color)


# Shared appearance comes from the surrounding Theme. Setting an exported
# appearance property explicitly opts only that property out of inheritance.
# Stored separately so even an explicit value equal to the script default survives saving.
@export_storage var _appearance_overrides: Dictionary = {}

func _appearance_value(item: String, fallback: Variant) -> Variant:
	if _appearance_overrides.has(item):
		return _appearance_overrides[item]
	var kind: StringName = theme_type_variation if not theme_type_variation.is_empty() else &"PixelSearchField"
	if fallback is Color and has_theme_color(item, kind):
		return get_theme_color(item, kind)
	if fallback is int and has_theme_constant(item, kind):
		return get_theme_constant(item, kind)
	if fallback is float and has_theme_constant(item, kind):
		return get_theme_constant(item, kind) / 100.0
	if fallback is Vector2i and has_theme_constant(item + "_x", kind):
		return Vector2i(get_theme_constant(item + "_x", kind), get_theme_constant(item + "_y", kind))
	if fallback is Font and has_theme_font(item, kind):
		return get_theme_font(item, kind)
	return fallback

@export_tool_button("Reset Appearance to Theme") var reset_appearance: Callable = reset_appearance_overrides

func reset_appearance_overrides() -> void:
	_appearance_overrides.clear()
	notify_property_list_changed()
	_refresh_skin()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_skin.call_deferred()
