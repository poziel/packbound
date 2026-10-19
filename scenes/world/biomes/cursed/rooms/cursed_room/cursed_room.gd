extends "res://scenes/world/rooms/shared/room_definition.gd"
## Saved scenery with a slow, restrained pulse; no geometry generation.

@export_range(0.0, 0.3, 0.01) var light_pulse_amount: float = 0.08
@export_range(0.0, 3.0, 0.05) var ambience_speed: float = 0.6
var elapsed: float = 0.0
var lights: Array[OmniLight3D] = []
var energies: Array[float] = []

func _ready() -> void:
	for light: OmniLight3D in $CurseLights.get_children():
		lights.append(light)
		energies.append(light.light_energy)

func _process(delta: float) -> void:
	elapsed += delta * ambience_speed
	for index: int in lights.size():
		lights[index].light_energy = energies[index] * (1.0 + sin(elapsed + index * 1.7) * light_pulse_amount)
