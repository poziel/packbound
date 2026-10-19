extends Panel

var text_labels: Array[Label] = []
var active: bool = false
var _initialized: bool = false
var _styling: bool = false

func _ready() -> void:
	theme_changed.connect(func() -> void:
		if not _styling:
			_initialized = false
	)

func _process(_delta: float) -> void:
	var hovered: Control = get_viewport().gui_get_hovered_control()
	var highlighted: bool = has_focus() or (hovered != null and (hovered == self or is_ancestor_of(hovered)))
	if _initialized and highlighted == active:
		return
	_initialized = true
	active = highlighted
	var border: Color = get_theme_color("header", "PackSurface")
	var background: Color = get_theme_color("background", "PackSurface")
	var style := StyleBoxFlat.new()
	style.bg_color = border if active else background
	style.border_color = border
	style.set_border_width_all(2)
	style.anti_aliasing = false
	_styling = true
	add_theme_stylebox_override("panel", style)
	for label: Label in text_labels:
		label.add_theme_color_override("font_color", get_theme_color("font_color", "Label") if active else border)
	_styling = false
