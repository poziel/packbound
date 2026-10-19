@tool
extends TabContainer
## Retain native tabs, icons and keyboard navigation with the PixelButton skin.

@export var face_color: Color = Color("46566c"):
	set(value):
		face_color = value
		if is_inside_tree():
			_apply_skin.call_deferred()

func _enter_tree() -> void:
	_apply_skin.call_deferred()

func _validate_property(property: Dictionary) -> void:
	if property["name"] == "theme":
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_STORAGE

func _apply_skin() -> void:
	if not is_inside_tree():
		return
	var sample: PackPixelButton = PackPixelButton.new()
	sample.face_color = face_color
	sample.size = Vector2(64, 64)
	# Keep the existing icon-tab margins, including the skin's lower extrusion.
	sample.content_padding = Vector2i(36, 14)
	var styles: Dictionary = sample.create_styleboxes(Vector2i(64, 64))
	var skin: Theme = Theme.new()
	var mapping: Dictionary = {"tab_unselected": "normal", "tab_hovered": "hover", "tab_selected": "pressed", "tab_disabled": "disabled", "tab_focus": "focus"}
	for tab_state: String in mapping:
		var style: StyleBoxTexture = styles[mapping[tab_state]]
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_texture_margin(side, 16)
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		skin.set_stylebox(tab_state, "TabContainer", style)
	for state: String in ["font_selected_color", "font_unselected_color", "font_hovered_color"]:
		skin.set_color(state, "TabContainer", sample.ink_color)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = skin
	sample.free()
