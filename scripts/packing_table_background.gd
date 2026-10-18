extends Control

const FPS: float = 8.0
const CYCLE_SECONDS: float = 16.0

var elapsed: float = 0.0
var current_frame: int = 0
var tracks: Array[AnimatedSprite2D] = []
@onready var artwork: Node2D = $Artwork

func _ready() -> void:
	resized.connect(_center_artwork)
	_center_artwork()
	for child in $Artwork.get_children():
		if child is AnimatedSprite2D:
			tracks.append(child)
	visibility_changed.connect(_sync_visibility)
	_sync_visibility()

func _center_artwork() -> void:
	# Keep the original pixel scale and registration while the inset clips the edges.
	var art_size: Vector2 = $Artwork/Base.texture.get_size() * artwork.scale
	artwork.position = ((size - art_size) * 0.5).round()

func _process(delta: float) -> void:
	# One clock preserves the registered flap, smoke and light at loop boundaries.
	elapsed = fmod(elapsed + delta, CYCLE_SECONDS)
	var next_frame: int = floori(elapsed * FPS)
	if next_frame == current_frame:
		return
	current_frame = next_frame
	for track: AnimatedSprite2D in tracks:
		track.frame = current_frame % track.sprite_frames.get_frame_count(track.animation)

func _sync_visibility() -> void:
	set_process(is_visible_in_tree())
