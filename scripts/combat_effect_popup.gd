extends RefCounted
## Shared visual-only randomness; never consumes the run's gameplay RNG.

static func append(popups: Array[Dictionary], key: String, amount: int, sample: Callable, bounds: Rect2, rng: RandomNumberGenerator, speed: float = 1.0, lane: int = 0) -> void:
	if amount == 0 or not PackKeywords.has_icon(key):
		return
	var anchor: Vector2 = sample.call()
	var best_distance: float = -1.0
	# Prefer a spread of origins while retaining the sampler's center bias.
	for attempt: int in range(16):
		var candidate: Vector2 = sample.call()
		candidate = candidate.clamp(bounds.position, bounds.end)
		var separation: float = 10000.0
		for other: Dictionary in popups:
			separation = minf(separation, candidate.distance_to(other["anchor"]))
		if separation > best_distance:
			anchor = candidate
			best_distance = separation
		if separation >= 32:
			break
	popups.append({"anchor": anchor.round(), "key": key, "amount": amount,
		"elapsed": -lane * 0.19, "speed": clampf(speed, 0.75, 1.35),
		"duration": rng.randf_range(1.65, 1.95), "height": rng.randf_range(42, 62),
		"drift": rng.randf_range(-9, 9)})

static func advance(popups: Array[Dictionary], delta: float) -> void:
	for index: int in range(popups.size() - 1, -1, -1):
		popups[index]["elapsed"] += delta * float(popups[index]["speed"])
		if popups[index]["elapsed"] >= popups[index]["duration"]:
			popups.remove_at(index)

static func draw(target: Control, popups: Array[Dictionary]) -> void:
	var font: Font = target.get_theme_font("font")
	for popup: Dictionary in popups:
		var t: float = float(popup["elapsed"]) / float(popup["duration"])
		if t < 0:
			continue
		# Reach readable size early, hold it, then gently shrink away.
		var scale: float = lerpf(0.35, 1.4, smoothstep(0.0, 0.18, t))
		if t > 0.62:
			scale = lerpf(1.4, 0.0, smoothstep(0.62, 1.0, t))
		var at: Vector2 = popup["anchor"] + Vector2(float(popup["drift"]) * t, -float(popup["height"]) * t)
		var label: String = str(popup["amount"])
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		target.draw_set_transform(at.round(), 0, Vector2.ONE * scale)
		var origin: Vector2 = Vector2(-(width + 17) / 2, 6)
		var color: Color = PackKeywords.color(popup["key"])
		var texture: Texture2D = PackKeywords.icon(popup["key"])
		var icon_rect := Rect2(origin + Vector2(width + 1, -15), Vector2(16, 16))
		# Offset the silhouettes by one display pixel regardless of animation scale.
		for y: int in range(-1, 2):
			for x: int in range(-1, 2):
				if x == 0 and y == 0:
					continue
				var offset := Vector2(x, y) / maxf(scale, 0.01)
				target.draw_string(font, origin + offset, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.BLACK)
				target.draw_texture_rect(texture, Rect2(icon_rect.position + offset, icon_rect.size), false, Color.BLACK)
		target.draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
		target.draw_texture_rect(texture, icon_rect, false, color)
	target.draw_set_transform(Vector2.ZERO)
