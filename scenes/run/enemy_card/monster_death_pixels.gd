extends Node2D
## Sample the opaque body, so debris starts inside the creature and keeps its palette.
var pieces: Array[Dictionary] = []
var elapsed: float = 0.0
var speed: float = 1.0
var paused: bool = false
const DURATION: float = 0.42

func burst(texture: Texture2D, bounds: Rect2, playback_speed: float) -> void:
	clear()
	speed = playback_speed
	if texture == null:
		return
	var image: Image = texture.get_image()
	var used: Rect2i = image.get_used_rect()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index in range(80):
		for attempt in range(24):
			var pixel := Vector2i(rng.randi_range(used.position.x, used.end.x - 1), rng.randi_range(used.position.y, used.end.y - 1))
			var color: Color = image.get_pixelv(pixel)
			if color.a < 0.5:
				continue
			var point: Vector2 = bounds.position + (Vector2(pixel - used.position) / Vector2(used.size)) * bounds.size
			pieces.append({"origin": point, "velocity": Vector2(rng.randf_range(-150, 150), rng.randf_range(-210, 30)), "color": color, "size": rng.randi_range(2, 5)})
			break
	queue_redraw()

func clear() -> void:
	pieces.clear()
	elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if paused or pieces.is_empty():
		return
	elapsed += delta * speed
	if elapsed >= DURATION:
		clear()
	queue_redraw()

func _draw() -> void:
	for piece: Dictionary in pieces:
		var point: Vector2 = piece.origin + piece.velocity * elapsed + Vector2(0, 260) * elapsed * elapsed
		var color: Color = piece.color
		color.a *= 1.0 - smoothstep(0.16, DURATION, elapsed)
		draw_rect(Rect2(point.round(), Vector2.ONE * piece.size), color)
