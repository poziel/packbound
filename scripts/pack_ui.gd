class_name PackUI
extends RefCounted

const INK: Color = Color("e2e4d3")
const MUTED: Color = Color("8ba49b")
const GOLD: Color = Color("d7ba7e")
const RED: Color = Color("ed8b92")
const GREEN: Color = Color("afd69d")

static func label(parent: Node, text: String, rect: Rect2, font_size: int = 16, color: Color = INK, wrap: bool = false) -> Label:
	var node: Label = Label.new()
	parent.add_child(node)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.position = rect.position
	node.size = rect.size
	node.text = text
	return node

static func image(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var node: TextureRect = TextureRect.new()
	parent.add_child(node)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture = texture
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	return node

static func button(parent: Node, text: String, rect: Rect2, primary: bool = false, icon_index: int = -1) -> Button:
	var node: Button = Button.new()
	parent.add_child(node)
	node.text = text
	node.add_theme_font_size_override("font_size", 17)
	node.add_theme_color_override("font_color", Color("142725") if primary else INK)
	node.add_theme_color_override("font_hover_color", Color("142725") if primary else INK)
	node.add_theme_color_override("font_disabled_color", MUTED.darkened(0.3))
	node.add_theme_stylebox_override("normal", PackArt.style(GOLD if primary else Color("213b3b"), Color("bfaa79") if primary else Color("45645b")))
	node.add_theme_stylebox_override("hover", PackArt.style(Color("edcf93") if primary else Color("2e4e49"), GOLD, 2))
	node.add_theme_stylebox_override("pressed", PackArt.style(Color("b99b61") if primary else Color("142c2c"), GOLD, 2))
	node.add_theme_stylebox_override("disabled", PackArt.style(Color("1c3233"), Color("334a44")))
	node.add_theme_stylebox_override("focus", PackArt.style(Color(0, 0, 0, 0), Color("e4deb2"), 2))
	if icon_index >= 0:
		node.icon = PackArt.control(icon_index)
		node.add_theme_constant_override("icon_max_width", 24)
	node.position = rect.position
	node.size = rect.size
	return node

static func layer(parent: Node, name_text: String) -> Control:
	var node: Control = Control.new()
	node.name = name_text
	parent.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return node

static func bar(parent: Node, rect: Rect2, color: Color) -> PixelStatBar:
	var node: PixelStatBar = preload("res://components/pixel_stat_bar/pixel_stat_bar.tscn").instantiate()
	node.accent_color = color
	parent.add_child(node)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	return node
