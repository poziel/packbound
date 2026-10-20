@tool
class_name PackItemSlot
extends Panel
## Presentational item socket. Dragging and inspection belong to its consumer.

const FRAME = preload("res://components/inventory/item_slot/item_frame.gd")
const CORNER_LAYER = preload("res://components/inventory/item_slot/corner_number.gd")

## Optional numbered tile variant. Zero uses the plain tile with no compartment.
@export_range(0, 9, 1) var corner_number: int = 0:
	set(value):
		corner_number = clampi(value, 0, 9)
		queue_redraw()
		if is_node_ready():
			_refresh_corner()

@export var occupied: bool = false:
	set(value):
		occupied = value
		queue_redraw()
		if is_node_ready():
			_refresh_corner()
@export var accent: Color = Color("a9bbc5"):
	get:
		return _appearance_value("accent", Color("a9bbc5"))
	set(value):
		_appearance_overrides["accent"] = value
		queue_redraw()
## Replace an exposed cell-side border segment with a caret, texture or draw callback.
## Transparent inherits the normal rarity/accent rim; opaque colors override only the border.
@export var border_color: Color = Color.TRANSPARENT:
	get:
		return _appearance_value("border_color", Color.TRANSPARENT)
	set(value):
		_appearance_overrides["border_color"] = value
		queue_redraw()
		if is_node_ready():
			_refresh_corner()
@export var border_segments: Array[Dictionary] = []:
	set(value):
		border_segments = value
		queue_redraw()

var hovered: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	var number_layer := Control.new()
	number_layer.name = "CornerNumber"
	number_layer.set_script(CORNER_LAYER)
	number_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(number_layer)
	number_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# This child draws after Art so the tile compartment is never obscured.
	number_layer.visible = occupied and corner_number > 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	mouse_entered.connect(func() -> void: hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: hovered = false; queue_redraw())
	resized.connect(queue_redraw)

func _draw() -> void:
	FRAME.draw_frame(self, [Vector2i.ZERO], size, 0, accent, occupied, occupied and hovered, border_segments, border_color)
	_refresh_corner()

func _refresh_corner() -> void:
	var number_layer: Control = get_node_or_null("CornerNumber")
	if number_layer != null:
		number_layer.visible = occupied and corner_number > 0
		number_layer.queue_redraw()


# Shared appearance comes from the surrounding Theme. Setting an exported
# appearance property explicitly opts only that property out of inheritance.
# Stored separately so even an explicit value equal to the script default survives saving.
@export_storage var _appearance_overrides: Dictionary = {}

func _appearance_value(item: String, fallback: Variant) -> Variant:
	if _appearance_overrides.has(item):
		return _appearance_overrides[item]
	var kind: StringName = theme_type_variation if not theme_type_variation.is_empty() else &"PackItemSlot"
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
	queue_redraw()

func _validate_property(property: Dictionary) -> void:
	if property["name"] in ["accent", "border_color"] and not _appearance_overrides.has(property["name"]):
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_STORAGE

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw.call_deferred()
