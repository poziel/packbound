@tool
extends ImageTexture
## Small native input skins, using the gameplay slate, parchment and gold palette.
@export_enum("Switch off", "Switch on", "Slider", "Slider active", "Select arrow") var kind: int = 0:
	set(value):
		kind = value
		_rebuild()

@export var edge_color := Color("596273"):
	set(value):
		edge_color = value
		_rebuild()

@export var surface_color := Color("171e29"):
	set(value):
		surface_color = value
		_rebuild()

@export var ink_color := Color("eeeeda"):
	set(value):
		ink_color = value
		_rebuild()

@export var accent_color := Color("d7ba7e"):
	set(value):
		accent_color = value
		_rebuild()

@export var active_color := Color("536b47"):
	set(value):
		active_color = value
		_rebuild()

func _init() -> void:
	_rebuild()

func _rebuild() -> void:
	var dimensions := Vector2i(48, 32) if kind < 2 else Vector2i(20, 28)
	if kind == 4:
		dimensions = Vector2i(20, 16)
	var picture := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	picture.fill(Color.TRANSPARENT)
	var edge := edge_color
	var surface := surface_color
	var ink := ink_color
	var gold := accent_color
	if kind < 2:
		picture.fill_rect(Rect2i(2, 4, 44, 24), edge)
		picture.fill_rect(Rect2i(4, 6, 40, 20), active_color if kind == 1 else surface)
		var x := 28 if kind == 1 else 6
		picture.fill_rect(Rect2i(x, 8, 14, 16), gold if kind == 1 else ink)
	elif kind < 4:
		picture.fill_rect(Rect2i(2, 2, 16, 24), edge)
		picture.fill_rect(Rect2i(4, 4, 12, 20), gold if kind == 3 else ink)
		picture.fill_rect(Rect2i(9, 9, 2, 10), surface)
	else:
		for row in range(4):
			picture.fill_rect(Rect2i(2 + row * 2, 4 + row * 2, 16 - row * 4, 2), ink)
	set_image(picture)

func _validate_property(property: Dictionary) -> void:
	# Rebuild pixels from editable palette properties instead of baking image data.
	if property.name == "image":
		property.usage &= ~PROPERTY_USAGE_STORAGE
