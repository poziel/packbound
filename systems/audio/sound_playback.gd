extends RefCounted
## Cosmetic randomness is independent of gameplay RNG. Bounds are pitch multipliers.
static var _random := RandomNumberGenerator.new()

static func play_random_pitch(player: Node, minimum: float = 0.9, maximum: float = 1.1, base_pitch: float = 1.0) -> void:
	if not (player is AudioStreamPlayer or player is AudioStreamPlayer2D or player is AudioStreamPlayer3D):
		push_error("Random-pitch playback requires an audio stream player")
		return
	var low: float = maxf(0.01, minf(minimum, maximum))
	var high: float = maxf(low, maxf(minimum, maximum))
	player.pitch_scale = maxf(0.01, base_pitch) * _random.randf_range(low, high)
	player.play()
