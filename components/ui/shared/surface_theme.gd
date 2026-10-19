@tool
extends Node
## Opt-in bindings to shared PackSurface theme tokens. Keeps authored layouts editable.
@export var reference_padding: int = 22
@export var padding_bindings: Dictionary = {}
@export var background_nodes: Array[NodePath] = []
@export var panel_nodes: Array[NodePath] = []
@export var frame_nodes: Array[NodePath] = []
@export var tab_nodes: Array[NodePath] = []
var _offsets: Dictionary = {}
var _syncing := false
var _signature: String = ""

func _ready() -> void:
	var root: Control = get_parent()
	for path: String in padding_bindings:
		var control: Control = root.get_node(path)
		_offsets[path] = Vector4(control.offset_left, control.offset_top, control.offset_right, control.offset_bottom)
	root.theme_changed.connect(_sync)
	_sync()

func _sync() -> void:
	if _syncing or not is_node_ready():
		return
	_syncing = true
	var root: Control = get_parent()
	var delta: int = root.get_theme_constant("content_padding", "PackSurface") - reference_padding
	var background: Color = root.get_theme_color("background", "PackSurface")
	var header: Color = root.get_theme_color("header", "PackSurface")
	var signature := str([delta, background, header])
	if signature == _signature:
		_syncing = false
		return
	_signature = signature
	for path: String in padding_bindings:
		var c: Control = root.get_node(path)
		var old: Vector4 = _offsets[path]
		var sides: PackedStringArray = str(padding_bindings[path]).split(",")
		c.offset_left = old.x + (delta if "left" in sides else -delta if "move_right" in sides else 0)
		c.offset_top = old.y + (delta if "top" in sides or "move_down" in sides else 0)
		c.offset_right = old.z - (delta if "right" in sides or "move_right" in sides else 0)
		c.offset_bottom = old.w + (delta if "move_down" in sides else -delta if "bottom" in sides else 0)
	for path in background_nodes:
		root.get_node(path).color = background
	for path in panel_nodes:
		var panel: Control = root.get_node(path)
		var style: StyleBox = panel.get_theme_stylebox("panel").duplicate()
		var alpha: float = style.get("bg_color").a
		style.set("bg_color", Color(background, alpha))
		panel.add_theme_stylebox_override("panel", style)
	for path in tab_nodes:
		var tabs: TabContainer = root.get_node(path)
		for slot: String in ["tab_selected", "tab_unselected", "tab_hovered"]:
			var style: StyleBox = tabs.get_theme_stylebox(slot).duplicate()
			var alpha: float = style.get("bg_color").a
			style.set("bg_color", Color(background, alpha) if slot == "tab_selected" else header)
			style.set("top_corner_color", header if slot == "tab_selected" else Color.TRANSPARENT)
			tabs.add_theme_stylebox_override(slot, style)
	for path in frame_nodes:
		var panel: Control = root.get_node(path)
		var style: StyleBox = panel.get_theme_stylebox("panel").duplicate()
		style.set("border_color", header)
		panel.add_theme_stylebox_override("panel", style)
	_syncing = false
