@tool
extends Control
## Framed head portrait. Its consumer supplies artwork and hover inspection.

const FRAME = preload("res://components/inventory/item_slot/item_frame.gd")
const PADDING: float = 3.0

@export var texture: Texture2D:
	set(value):
		texture = value
		_update_art()
@export var accent_color: Color = Color("c5b48a"):
	set(value):
		accent_color = value
		queue_redraw()

## Replace an exposed cell-side border segment with a caret, texture or draw callback.
@export var border_segments: Array[Dictionary] = []:
	set(value):
		border_segments = value
		queue_redraw()

var hovered: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_update_art)
	mouse_entered.connect(func() -> void: hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: hovered = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_update_art()

func _update_art() -> void:
	var art: TextureRect = get_node_or_null("Art")
	if art == null:
		return
	art.texture = texture
	if texture == null:
		return
	var available: Vector2 = (size - Vector2.ONE * PADDING * 2).max(Vector2.ONE)
	var source: Vector2 = texture.get_size()
	var factor: float = minf(available.x / source.x, available.y / source.y)
	# Fill the available interior; nearest filtering preserves hard pixel edges.
	art.size = (source * factor).floor()
	art.position = ((size - art.size) * 0.5).floor()
	queue_redraw()

func _draw() -> void:
	FRAME.draw_frame(self, [Vector2i.ZERO], size, 0, accent_color, true, hovered or has_focus(), border_segments)
