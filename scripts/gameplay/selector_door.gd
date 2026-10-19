@tool
extends Node3D
## The invisible interaction target drives light inside the physical doorway.

var highlight_tween: Tween
var highlighted: bool = false
@export var interaction_half_size := Vector2(0.65, 1.0)
## The staircase component owns its light; the door forwards hover parameters here.
@export_node_path("Node3D") var staircase_path: NodePath = NodePath("ExitStairs")
@export var hover_glow_color := Color(0.58, 0.76, 1.0)
@export_range(0.0, 1.0) var hover_glow_intensity: float = 0.015
var idle_text_color: Color
var idle_outline_color: Color
var idle_depth_color: Color
var idle_depth_strength: float

func _ready() -> void:
	idle_text_color = $Sign.modulate
	idle_outline_color = $Sign.outline_modulate
	# Uniform self-lit glyphs: nearby torch/light placement cannot light only
	# part of a label. Both glyph fill and outline follow the door's glow color.
	$Sign.shaded = false
	var stairs: Node = get_node_or_null(staircase_path)
	if stairs:
		idle_depth_color = stairs.depth_color
		idle_depth_strength = stairs.depth_strength
		stairs.glow_intensity = 0.0
		if has_node("Glow"):
			$Glow.light_energy = 0.0
	if has_node("InnerGlow"):
		$InnerGlow.material_override = $InnerGlow.material_override.duplicate()
		if stairs:
			$InnerGlow.material_override.set_shader_parameter("strength", 0.0)

func set_highlight(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	var stairs: Node = get_node_or_null(staircase_path)
	if highlight_tween and highlight_tween.is_valid():
		highlight_tween.kill()
	highlight_tween = create_tween().set_parallel(true)
	if stairs:
		stairs.glow_color = hover_glow_color
		highlight_tween.tween_property(stairs, "glow_intensity", hover_glow_intensity if value else 0.0, 0.20)
		# The depth pass can hide illuminated stone entirely. Soften it during
		# hover and tint its opaque end cap gently toward the same light color.
		highlight_tween.tween_property(stairs, "depth_strength", idle_depth_strength * 0.35 if value else idle_depth_strength, 0.20)
		highlight_tween.tween_property(stairs, "depth_color", idle_depth_color.lerp(hover_glow_color, 0.12) if value else idle_depth_color, 0.20)
	else:
		$Glow.light_color = hover_glow_color
		highlight_tween.tween_property($Glow, "light_energy", 3.0 if value else 0.12, 0.20)
	if has_node("InnerGlow"):
		$InnerGlow.material_override.set_shader_parameter("glow_color", hover_glow_color)
		highlight_tween.tween_property($InnerGlow.material_override, "shader_parameter/strength", 0.32 if value else (0.0 if stairs else 0.015), 0.20)
	highlight_tween.tween_property($Sign, "modulate", hover_glow_color if value else idle_text_color, 0.20)
	highlight_tween.tween_property($Sign, "outline_modulate", hover_glow_color if value else idle_outline_color, 0.20)
