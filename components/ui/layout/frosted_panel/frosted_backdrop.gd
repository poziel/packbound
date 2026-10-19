@tool
extends Control
## Background-only blur. Foreground controls remain separate, sharp canvas items.

@export var tint := Color(0.063, 0.082, 0.122, 1):
	set(value):
		tint = value
		_sync_material()
@export_range(0, 1, 0.01) var opacity: float = 0.82:
	set(value):
		opacity = value
		_sync_material()
@export_range(0, 12, 0.5) var blur_radius: float = 4.0:
	set(value):
		blur_radius = value
		_sync_material()
@export_range(0, 24, 1) var corner_radius: int = 8:
	set(value):
		corner_radius = value
		_sync_material()
@export_range(0, 5, 1) var border_width: int = 2:
	set(value):
		border_width = value
		_sync_material()

func _ready() -> void:
	resized.connect(_sync_material)
	theme_changed.connect(_sync_material)
	_sync_material()

func _sync_material() -> void:
	if not is_node_ready():
		return
	var shader_material: ShaderMaterial = $Surface.material
	shader_material.set_shader_parameter("panel_size", size)
	shader_material.set_shader_parameter("tint", get_theme_color("background", "PackSurface") if has_theme_color("background", "PackSurface") else tint)
	shader_material.set_shader_parameter("opacity", opacity)
	shader_material.set_shader_parameter("blur_radius", blur_radius)
	shader_material.set_shader_parameter("corner_radius", float(corner_radius))
	shader_material.set_shader_parameter("border_width", float(border_width))
