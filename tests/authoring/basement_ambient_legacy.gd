extends Node3D
## Legacy controller retained for the original one-time geometry migration.
## The live basement now instances components/torch/candle.tscn directly.

const PixelFlame = preload("res://scripts/pixel_flame.gd")

@export_range(1.0, 24.0, 1.0) var flame_fps: float = 10.0
@export_range(0.0, 0.2, 0.01) var light_flicker: float = 0.06
var flames: Array[Dictionary] = []
var candle_lights: Array[Dictionary] = []
var time: float = 0.0

func _ready() -> void:
	for node: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if bool(node.get_meta("pixel_flame", false)) and node.material_override is StandardMaterial3D:
			flames.append(PixelFlame.attach(node, node.get_parent(), float(node.get_meta("flame_scale", 0.5))))
	for light: OmniLight3D in find_children("*", "OmniLight3D", true, false):
		if bool(light.get_meta("candle_light", false)):
			candle_lights.append({"light": light, "energy": light.light_energy})

func _process(delta: float) -> void:
	if is_visible_in_tree():
		advance_ambient(delta)

func advance_ambient(delta: float) -> void:
	time += delta
	var tick: float = floorf(time * flame_fps)
	for index in range(flames.size()):
		PixelFlame.animate(flames[index], tick, index)
	for index in range(candle_lights.size()):
		var entry: Dictionary = candle_lights[index]
		var flutter: float = sin(time * 3.3 + index * 2.0) + sin(time * 7.1) * 0.35
		entry["light"].light_energy = float(entry["energy"]) * (1.0 + flutter * light_flicker)
