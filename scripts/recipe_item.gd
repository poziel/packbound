extends Control
## Borderless, full-size item art with the same UVs and mask as the backpack.
signal inspected(key: String, recipes: bool)
const ART = preload("res://scripts/item_art_renderer.gd")
const OUTLINE = preload("res://scripts/recipe_item_outline.gdshader")
var item: Dictionary = {}
var hovered: bool = false

func _ready() -> void:
	mouse_entered.connect(func() -> void: hovered = true; _refresh_outline())
	mouse_exited.connect(func() -> void: hovered = false; _refresh_outline())
	focus_entered.connect(_refresh_outline)
	focus_exited.connect(_refresh_outline)

func _refresh_outline() -> void:
	if hovered or has_focus():
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE
		outline.set_shader_parameter("accent", get_theme_color("icon_normal_color", "IconButton"))
		material = outline
	else:
		material = null

func setup(value: Dictionary) -> void:
	item = value
	custom_minimum_size = ART.footprint(item["shape"])
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	accessibility_name = str(item["name"])
	accessibility_description = "Inspect item. Alt-click to view crafting recipes."
	queue_redraw()

func _draw() -> void:
	if not item.is_empty():
		ART.draw(self, item, custom_minimum_size, PackArt.item(item["key"]), PackRun.offsets(item), int(item["rotation"]))

func _has_point(point: Vector2) -> bool:
	for cell: Vector2i in PackRun.offsets(item):
		if Rect2(Vector2(cell) * ART.STEP, Vector2.ONE * ART.CELL).has_point(point):
			return true
	return false

func set_interactive(value: bool) -> void:
	if not value:
		hovered = false
		material = null
	mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE

func _gui_input(event: InputEvent) -> void:
	var mouse: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var keyboard: bool = event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	if mouse or keyboard:
		inspected.emit(str(item["key"]), event.alt_pressed)
		accept_event()
