@tool
extends Node3D
## Camera-carried light. Power is an external control, not a fuel simulation.

@export_range(0.0, 1.0, 0.01) var power: float = 1.0:
	set(value):
		power = clampf(value, 0.0, 1.0)
		_refresh()
@export var light_color: Color = Color(1.0, 0.84, 0.55):
	set(value):
		light_color = value
		_refresh()
@export_range(0.0, 16.0, 0.05) var intensity: float = 5.5:
	set(value):
		intensity = maxf(value, 0.0)
		_refresh()
@export_range(1.0, 40.0, 0.5) var radius: float = 18.0:
	set(value):
		radius = maxf(value, 1.0)
		_refresh()
@export_range(10.0, 60.0, 1.0) var beam_angle: float = 30.0:
	set(value):
		beam_angle = value
		_refresh()
@export_range(0.0, 4.0, 0.05) var spill_intensity: float = 1.2:
	set(value):
		spill_intensity = maxf(value, 0.0)
		_refresh()
@export_range(1.0, 15.0, 0.5) var spill_radius: float = 9.0:
	set(value):
		spill_radius = maxf(value, 1.0)
		_refresh()
@export_range(0.0, 0.1, 0.005) var flicker_amount: float = 0.025:
	set(value):
		flicker_amount = value
		_refresh()
@export var animate_in_editor: bool = false
var elapsed: float = 0.0

func _ready() -> void:
	_refresh()

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or animate_in_editor:
		advance_flicker(delta)

func advance_flicker(delta: float) -> void:
	elapsed += delta
	_refresh()

func _refresh() -> void:
	if not is_inside_tree() or not has_node("Light") or not has_node("Spill"):
		return
	var light: SpotLight3D = $Light
	light.light_color = light_color
	light.spot_range = radius
	light.spot_angle = beam_angle
	light.visible = power > 0.0 and intensity > 0.0
	var flutter: float = (sin(elapsed * 2.1) + sin(elapsed * 4.7) * 0.3) / 1.3
	var strength: float = power * (1.0 + flutter * flicker_amount)
	light.light_energy = intensity * strength
	var spill: OmniLight3D = $Spill
	spill.light_color = light_color
	spill.omni_range = spill_radius
	spill.visible = power > 0.0 and spill_intensity > 0.0
	spill.light_energy = spill_intensity * strength
