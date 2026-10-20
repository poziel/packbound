class_name PackMenuAudio
extends Node

signal click_played

const BUS_NAMES: Dictionary = {"volume": "Master", "music": "Music", "fx": "FX", "ambience": "Ambience"}
const CROSSFADE_SECONDS: float = 1.0
const GAMEPLAY_DIRECTORY: String = "res://assets/audio/music/gameplay/"
@onready var music: AudioStreamPlayer = $MenuMusic
@onready var gameplay_music: AudioStreamPlayer = $GameplayMusic
@onready var next_track_timer: Timer = $NextTrackTimer
@onready var fx: AudioStreamPlayer = $MenuFX
@onready var item_hover_fx: AudioStreamPlayer = $ItemHoverFX
@onready var ui_hover_fx: AudioStreamPlayer = $UIHoverFX
@onready var item_pickup_fx: AudioStreamPlayer = $ItemPickupFX
@onready var item_drop_fx: AudioStreamPlayer = $ItemDropFX
@onready var ambience_layers: Array[AudioStreamPlayer] = [$AmbienceOne, $AmbienceTwo]
var music_started: bool = false
var gameplay_started: bool = false
var menu_active: bool = true
var gameplay_tracks: Array[String] = []
var last_track: String = ""
var transition: Tween
var random: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	for bus_name: String in ["Music", "FX", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	var song: AudioStreamMP3 = music.stream.duplicate()
	song.loop = true
	song.loop_offset = 0.0
	music.stream = song
	random.randomize()
	# ResourceLoader lists imported resources in both the editor and exported packs.
	for file: String in ResourceLoader.list_directory(GAMEPLAY_DIRECTORY):
		if file.ends_with(".ogg"):
			gameplay_tracks.append(GAMEPLAY_DIRECTORY + file)
	gameplay_tracks.sort()
	gameplay_music.volume_linear = 0.0
	gameplay_music.finished.connect(_gameplay_finished)
	next_track_timer.timeout.connect(_play_random_track)
	for layer in ambience_layers:
		var ambience: AudioStreamOggVorbis = layer.stream.duplicate()
		ambience.loop = true
		layer.stream = ambience
		layer.volume_linear = 0.0
	# Listen to activation signals, so keyboard/controller input sounds like a click too.
	# The initial walk covers gameplay controls created before the front end.
	get_tree().node_added.connect(_connect_button)
	_connect_existing_buttons(get_tree().root)

func apply_settings(settings: Dictionary) -> void:
	for key: String in BUS_NAMES:
		var index: int = AudioServer.get_bus_index(BUS_NAMES[key])
		var gain: float = clampf(float(settings[key]) / 100.0, 0.0, 1.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(gain, 0.0001)))
		AudioServer.set_bus_mute(index, gain <= 0.0)

func set_menu_active(active: bool) -> void:
	# AudioStreamPlayer reports playing=false while paused; do not restart it.
	if active and not music_started:
		music.play()
		music_started = true
		return
	if active == menu_active:
		return
	menu_active = active
	if transition and transition.is_valid():
		transition.kill()
	if active:
		music.stream_paused = false
	else:
		gameplay_music.stream_paused = false
		if not gameplay_started:
			gameplay_started = true
			next_track_timer.start(random.randf_range(3.0, 4.0))
			for layer in ambience_layers:
				layer.play()
		for layer in ambience_layers:
			layer.stream_paused = false
	# Preserve remaining silence while in the lobby. Options do not change context.
	next_track_timer.paused = active
	transition = create_tween().set_parallel(true)
	transition.tween_property(music, "volume_linear", 1.0 if active else 0.0, CROSSFADE_SECONDS)
	transition.tween_property(gameplay_music, "volume_linear", 0.0 if active else 1.0, CROSSFADE_SECONDS)
	# Two layers share headroom; their combined level remains restrained.
	for layer in ambience_layers:
		transition.tween_property(layer, "volume_linear", 0.0 if active else 0.5, CROSSFADE_SECONDS)
	transition.chain().tween_callback(_finish_transition.bind(active))

func _finish_transition(active: bool) -> void:
	music.stream_paused = not active
	gameplay_music.stream_paused = active
	for layer in ambience_layers:
		layer.stream_paused = active

func _play_random_track() -> void:
	if menu_active or gameplay_tracks.is_empty():
		return
	var candidates: Array[String] = gameplay_tracks.duplicate()
	if candidates.size() > 1:
		candidates.erase(last_track)
	last_track = candidates[random.randi_range(0, candidates.size() - 1)]
	gameplay_music.stream = load(last_track)
	gameplay_music.play()

func _gameplay_finished() -> void:
	next_track_timer.start(random.randf_range(10.0, 30.0))
	next_track_timer.paused = menu_active

func play_click() -> void:
	fx.play()
	click_played.emit()

func play_item_hover() -> void:
	preload("res://systems/audio/sound_playback.gd").play_random_pitch(item_hover_fx)

func play_ui_hover(button: Control) -> void:
	if button.is_visible_in_tree() and not button.get_meta("item_hover_audio", false) and not (button is BaseButton and button.disabled):
		preload("res://systems/audio/sound_playback.gd").play_random_pitch(ui_hover_fx)

func play_item_pickup() -> void:
	preload("res://systems/audio/sound_playback.gd").play_random_pitch(item_pickup_fx)

func play_item_drop() -> void:
	preload("res://systems/audio/sound_playback.gd").play_random_pitch(item_drop_fx)

func _connect_existing_buttons(node: Node) -> void:
	_connect_button(node)
	for child in node.get_children():
		_connect_existing_buttons(child)

func _connect_button(node: Node) -> void:
	if node is BaseButton:
		var hover: Callable = play_ui_hover.bind(node)
		if not node.mouse_entered.is_connected(hover):
			node.mouse_entered.connect(hover)
	if node is BaseButton and not node.pressed.is_connected(play_click):
		node.pressed.connect(play_click)
	if node is OptionButton and not node.item_selected.is_connected(_on_item_selected):
		node.item_selected.connect(_on_item_selected)

func _on_item_selected(_index: int) -> void:
	play_click()
