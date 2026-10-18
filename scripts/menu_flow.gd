class_name PackMenuFlow
extends Control

signal class_chosen(key: String)
signal saved_run_chosen(id: String)
signal resume_requested
signal settings_changed

@onready var home: Control = $MainMenu
@onready var selection: Control = $ClassSelection
@onready var runs: Control = $RunSelection
@onready var options: Control = $Options
@onready var play_button: Button = $MainMenu/PlayButton
var options_return_focus: Control
var loading_screen: CanvasLayer
@onready var quit_button: Button = $MainMenu/QuitButton
@onready var home_title: TextureRect = $MainMenu/HomeTitle
var class_buttons: Dictionary = {}
@onready var back_button: Button = $Options/%BackButton
@onready var reset_button: Button = $Options/%ResetButton
@onready var option_tabs: TabContainer = $Options/%Tabs
const BINDINGS = preload("res://scripts/keybindings.gd")
@onready var window_mode: OptionButton = $Options/%WindowMode
@onready var vsync_toggle: CheckButton = $Options/%VsyncToggle
@onready var name_display: OptionButton = $Options/%NameDisplay
@onready var character_name: LineEdit = $Options/%CharacterName
var keybindings: Dictionary = BINDINGS.DEFAULTS.duplicate()
var capturing_action: String = ""
var display_sliders: Dictionary = {}
var display_labels: Dictionary = {}
var adjustment: ColorRect
@onready var flash_toggle: CheckButton = $Options/%FlashToggle
@onready var tips_toggle: CheckButton = $Options/%TipsToggle
@onready var run_time_toggle: CheckButton = $Options/%RunTimeToggle
@onready var resolution: OptionButton = $Options/%Resolution
@onready var combat_speed: HSlider = $Options/%CombatSpeed
var combat_sliders: Dictionary = {}
var combat_labels: Dictionary = {}
@onready var tooltip_lock_slider: HSlider = $Options/%TooltipLockSlider
@onready var tooltip_lock_value: Label = $Options/%TooltipLockValue
var title_font: Font = preload("res://assets/fonts/ui_pixel.tres")
var menu_font: FontFile = preload("res://assets/fonts/ui_pixel.tres")
@onready var audio: PackMenuAudio = $Audio
var volume_sliders: Dictionary = {}
var volume_labels: Dictionary = {}
var from_game: bool = false
const DEFAULT_SETTINGS: Dictionary = {"hold_destructive_actions": true, "show_run_time": true, "fullscreen": false, "window_mode": 0, "vsync": true, "brightness": 100, "contrast": 100, "name_display": 0, "character_name": "Delver", "flash": true, "tooltips": true, "resolution": 1, "volume": 80, "music": 70, "fx": 60, "ambience": 15, "combat_speed": 1.0, "player_response_delay": 1.5, "enemy_response_delay": 1.5, "tooltip_lock_delay": 1.0}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
const SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1600, 900)]

func _ready() -> void:
	_load_settings()
	# Explicit launcher dimensions take precedence over saved settings this session.
	var launch_args := OS.get_cmdline_args()
	var resolution_arg := launch_args.find("--resolution")
	if resolution_arg >= 0 and resolution_arg + 1 < launch_args.size():
		var dimensions := launch_args[resolution_arg + 1].split("x")
		if dimensions.size() == 2:
			var launch_size := Vector2i(int(dimensions[0]), int(dimensions[1]))
			var size_index := SIZES.find(launch_size)
			if size_index >= 0:
				settings["resolution"] = size_index
	if launch_args.has("--windowed"):
		settings["window_mode"] = 0
		settings["fullscreen"] = false
	BINDINGS.apply(keybindings)
	_create_display_adjustment()
	audio.apply_settings(settings)
	visibility_changed.connect(_sync_music)
	play_button.pressed.connect(_transition_to_classes)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	selection.back_requested.connect(func() -> void: _navigate(show_runs))
	runs.back_requested.connect(_transition_to_home)
	runs.new_run_requested.connect(func() -> void: _navigate(show_classes))
	runs.run_chosen.connect(func(id: String) -> void: saved_run_chosen.emit(id))
	back_button.pressed.connect(_options_back)
	_bind_classes()
	_bind_options()
	show_home()
	_apply_display()
	if DisplayServer.get_name() != "headless" and get_window().mode == Window.MODE_WINDOWED:
		var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen)
		get_window().position = usable.position + (usable.size - get_window().size) / 2

func _bind_classes() -> void:
	class_buttons = selection.buttons
	selection.class_chosen.connect(_choose_class)

func _choose_class(key: String) -> void:
	if is_instance_valid(loading_screen) and loading_screen.active:
		return
	class_chosen.emit(key)

func _transition_to_classes() -> void:
	_navigate(show_runs)

func show_runs() -> void:
	show()
	home.hide()
	selection.hide()
	options.hide()
	runs.show()
	runs.refresh()

func _transition_to_home() -> void:
	_navigate(func() -> void:
		show_home()
		play_button.grab_focus()
	)

func _navigate(destination: Callable) -> void:
	if is_instance_valid(loading_screen):
		loading_screen.play(destination)
	else:
		destination.call()

func _bind_options() -> void:
	reset_button.connect("confirmed", _reset_options)
	options.get_node("%HoldDestructiveToggle").toggled.connect(func(value: bool) -> void: _set_option("hold_destructive_actions", value))
	option_tabs.tab_changed.connect(func(_index: int) -> void: audio.play_click())
	window_mode.item_selected.connect(func(value: int) -> void: _set_option("window_mode", value))
	vsync_toggle.toggled.connect(func(value: bool) -> void: _set_option("vsync", value))
	name_display.item_selected.connect(func(value: int) -> void: _set_option("name_display", value))
	character_name.text_changed.connect(func(value: String) -> void: _set_option("character_name", value))
	for key: String in ["brightness", "contrast"]:
		var slider: HSlider = options.get_node("%" + key.to_pascal_case() + "Slider")
		display_sliders[key] = slider
		display_labels[key] = options.get_node("%" + key.to_pascal_case() + "Value")
		slider.value_changed.connect(func(value: float) -> void: _set_option(key, int(value)))
	for action: String in BINDINGS.DEFAULTS:
		var button: Button = options.get_node("%" + action)
		button.pressed.connect(_begin_keybind.bind(action))
	option_tabs.tab_changed.connect(func(_index: int) -> void: _cancel_keybind())
	flash_toggle.toggled.connect(func(value: bool) -> void: _set_option("flash", value))
	tips_toggle.toggled.connect(func(value: bool) -> void: _set_option("tooltips", value))
	run_time_toggle.toggled.connect(func(value: bool) -> void: _set_option("show_run_time", value))
	resolution.item_selected.connect(func(value: int) -> void: _set_option("resolution", value))
	for key: String in ["combat_speed", "player_response_delay", "enemy_response_delay"]:
		var slider: HSlider = options.get_node("%" + key.to_pascal_case())
		combat_sliders[key] = slider
		combat_labels[key] = options.get_node("%" + key.to_pascal_case() + "Value")
		slider.value_changed.connect(func(value: float) -> void: _set_option(key, value))
		slider.drag_ended.connect(func(_changed: bool) -> void: audio.play_click())
	tooltip_lock_slider.value_changed.connect(func(value: float) -> void: _set_option("tooltip_lock_delay", value))
	tooltip_lock_slider.drag_ended.connect(func(_changed: bool) -> void: audio.play_click())
	for key: String in PackMenuAudio.BUS_NAMES:
		var slider: HSlider = options.get_node("%" + key.to_pascal_case() + "Slider")
		var label: Label = options.get_node("%" + key.to_pascal_case() + "Value")
		volume_sliders[key] = slider
		volume_labels[key] = label
		slider.value_changed.connect(_volume_changed.bind(key))
		slider.drag_ended.connect(func(_changed: bool) -> void: audio.play_click())
	for select: OptionButton in [resolution, window_mode, name_display]:
		_style_popup(select.get_popup())
	_sync_options()

func _sync_options() -> void:
	options.get_node("%HoldDestructiveToggle").set_pressed_no_signal(bool(settings["hold_destructive_actions"]))
	reset_button.call("set_hold_required", bool(settings["hold_destructive_actions"]))
	window_mode.select(int(settings["window_mode"]))
	vsync_toggle.set_pressed_no_signal(bool(settings["vsync"]))
	name_display.select(int(settings["name_display"]))
	character_name.editable = int(settings["name_display"]) == 1
	if character_name.text != str(settings["character_name"]):
		character_name.text = str(settings["character_name"])
	for key: String in display_sliders:
		display_sliders[key].set_value_no_signal(float(settings[key]))
		display_labels[key].text = "%d%%" % settings[key]
	for action: String in BINDINGS.DEFAULTS:
		var button: Button = options.get_node("%" + action)
		button.text = "Press a key…" if capturing_action == action else OS.get_keycode_string(int(keybindings[action]))
		button.accessibility_name = BINDINGS.LABELS[action] + ": " + button.text
	flash_toggle.set_pressed_no_signal(bool(settings["flash"]))
	tips_toggle.set_pressed_no_signal(bool(settings["tooltips"]))
	run_time_toggle.set_pressed_no_signal(bool(settings["show_run_time"]))
	resolution.select(int(settings["resolution"]))
	resolution.disabled = int(settings["window_mode"]) != 0
	for key: String in combat_sliders:
		combat_sliders[key].set_value_no_signal(float(settings[key]))
		combat_labels[key].text = ("%s×" % str(settings[key])) if key == "combat_speed" else ("%.1f s" % settings[key])
	tooltip_lock_slider.set_value_no_signal(float(settings["tooltip_lock_delay"]))
	tooltip_lock_value.text = "%.1f s" % settings["tooltip_lock_delay"]
	tooltip_lock_slider.editable = bool(settings["tooltips"])
	for key: String in PackMenuAudio.BUS_NAMES:
		volume_sliders[key].set_value_no_signal(float(settings[key]))
		volume_labels[key].text = "%d%%" % settings[key]

func _reset_options() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	keybindings = BINDINGS.DEFAULTS.duplicate()
	BINDINGS.apply(keybindings)
	_cancel_keybind()
	_sync_options()
	audio.apply_settings(settings)
	_apply_display()
	_save_settings()
	settings_changed.emit()

func _style_popup(popup: PopupMenu) -> void:
	popup.theme = options.theme
	popup.add_theme_font_size_override("font_size", 24)

func _volume_changed(value: float, key: String) -> void:
	volume_labels[key].text = "%d%%" % value
	_set_option(key, int(value))

func _sync_music() -> void:
	if is_instance_valid(audio):
		audio.set_menu_active(is_visible_in_tree() and not from_game)

func show_home() -> void:
	runs.hide()
	from_game = false
	show()
	home.show()
	selection.hide()
	options.hide()
	_sync_music()

func show_classes() -> void:
	runs.hide()
	show()
	home.hide()
	selection.show()
	options.hide()

func show_options(return_to_game: bool = false) -> void:
	runs.hide()
	from_game = return_to_game
	show()
	home.hide()
	selection.hide()
	options.show()
	_sync_options()
	option_tabs.get_tab_bar().grab_focus()
	_sync_music()

func _options_back() -> void:
	_cancel_keybind()
	if from_game:
		hide()
		resume_requested.emit()
	else:
		show_home()
		if is_instance_valid(options_return_focus):
			options_return_focus.grab_focus()
		else:
			play_button.grab_focus()

func _set_option(key: String, value: Variant) -> void:
	if key == "combat_speed":
		value = snappedf(clampf(float(value), 0.5, 10.0), 0.5)
	if key in ["player_response_delay", "enemy_response_delay"]:
		value = snappedf(clampf(float(value), 0.2, 2.5), 0.1)
	if key == "tooltip_lock_delay":
		value = snappedf(clampf(float(value), 0.3, 2.0), 0.1)
	if key in ["brightness", "contrast"]:
		value = clampi(int(value), 50, 150)
	if key == "window_mode":
		value = clampi(int(value), 0, 2)
		settings["fullscreen"] = int(value) != 0
	if key == "fullscreen":
		settings["window_mode"] = 1 if bool(value) else 0
	if key == "character_name":
		value = str(value).left(24)
	settings[key] = value
	_sync_options()
	if PackMenuAudio.BUS_NAMES.has(key):
		audio.apply_settings(settings)
	if key in ["fullscreen", "window_mode", "resolution", "vsync", "brightness", "contrast"]:
		_apply_display(key in ["fullscreen", "window_mode", "resolution"])
	_save_settings()
	settings_changed.emit()

func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	for name_text in settings:
		config.set_value("options", name_text, settings[name_text])
	for action: String in keybindings:
		config.set_value("keybinds", action, keybindings[action])
	config.save("user://packbound_settings.cfg")

func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://packbound_settings.cfg") == OK:
		for key in settings:
			settings[key] = config.get_value("options", key, settings[key])
	if not config.has_section_key("options", "window_mode"):
		settings["window_mode"] = 1 if bool(settings["fullscreen"]) else 0
	settings["window_mode"] = clampi(int(settings["window_mode"]), 0, 2)
	settings["fullscreen"] = int(settings["window_mode"]) != 0
	settings["name_display"] = clampi(int(settings["name_display"]), 0, 1)
	settings["character_name"] = str(settings["character_name"]).left(24)
	for key: String in ["brightness", "contrast"]:
		settings[key] = clampi(int(settings[key]), 50, 150)
	keybindings = BINDINGS.DEFAULTS.duplicate()
	var loaded: Dictionary = {}
	for action: String in BINDINGS.DEFAULTS:
		var code := int(config.get_value("keybinds", action, BINDINGS.DEFAULTS[action]))
		if code <= 0 or OS.get_keycode_string(code).is_empty() or loaded.values().has(code):
			loaded.clear()
			break
		loaded[action] = code
	if loaded.size() == BINDINGS.DEFAULTS.size():
		keybindings = loaded
	settings["resolution"] = clampi(int(settings["resolution"]), 0, SIZES.size() - 1)
	settings["combat_speed"] = snappedf(clampf(float(settings["combat_speed"]), 0.5, 10.0), 0.5)
	for key: String in ["player_response_delay", "enemy_response_delay"]:
		settings[key] = snappedf(clampf(float(settings[key]), 0.2, 2.5), 0.1)
	settings["tooltip_lock_delay"] = snappedf(clampf(float(settings["tooltip_lock_delay"]), 0.3, 2.0), 0.1)
	for key: String in PackMenuAudio.BUS_NAMES:
		settings[key] = clampi(int(settings[key]), 0, 100)

func _create_display_adjustment() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DisplayAdjustment"
	layer.layer = 100
	add_child(layer)
	adjustment = ColorRect.new()
	adjustment.name = "ColorAdjustment"
	adjustment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	adjustment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://themes/gameplay/display_adjustment.gdshader")
	adjustment.material = shader_material
	layer.add_child(adjustment)

func _apply_display(update_window: bool = true) -> void:
	if is_instance_valid(adjustment):
		adjustment.material.set_shader_parameter("brightness", float(settings["brightness"]) / 100.0)
		adjustment.material.set_shader_parameter("contrast", float(settings["contrast"]) / 100.0)
		adjustment.visible = settings["brightness"] != 100 or settings["contrast"] != 100
	if DisplayServer.get_name() == "headless":
		return
	var modes := [Window.MODE_WINDOWED, Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	var mode: int = modes[int(settings["window_mode"])]
	if update_window and get_window().mode != mode:
		get_window().mode = mode
	if update_window and mode == Window.MODE_WINDOWED:
		var window := get_window()
		var old_size := window.size
		var old_position := window.position
		window.size = SIZES[int(settings["resolution"])]
		window.position = old_position + (old_size - window.size) / 2
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings["vsync"]) else DisplayServer.VSYNC_DISABLED)

func player_name(class_key: String) -> String:
	var custom := str(settings["character_name"]).strip_edges()
	if int(settings["name_display"]) == 1 and not custom.is_empty():
		return custom
	return PackCatalog.classes()[class_key]["name"]

func _begin_keybind(action: String) -> void:
	capturing_action = action
	options.get_node("%KeybindHint").text = "Press a key for %s. Esc cancels." % BINDINGS.LABELS[action].to_lower()
	_sync_options()

func _cancel_keybind() -> void:
	capturing_action = ""
	options.get_node("%KeybindHint").text = "Select a binding, then press a key. Esc cancels.\nRight-click rotates items; Esc cancels dragging or stores a displaced item."
	_sync_options()

func _input(event: InputEvent) -> void:
	if is_instance_valid(loading_screen) and loading_screen.active:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11 and capturing_action.is_empty():
		_set_option("window_mode", 1 if int(settings["window_mode"]) == 0 else 0)
		get_viewport().set_input_as_handled()
		return
	if capturing_action.is_empty() or not options.is_visible_in_tree():
		return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if not event.pressed or event.echo:
			return
		if event.keycode == KEY_ESCAPE:
			_cancel_keybind()
			return
		if event.keycode == KEY_F11:
			options.get_node("%KeybindHint").text = "F11 toggles fullscreen. Choose another key."
			return
		if event.keycode in [KEY_NONE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META] or event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
			options.get_node("%KeybindHint").text = "Choose a single key without modifiers. Esc cancels."
			return
		for action: String in keybindings:
			if action != capturing_action and keybindings[action] == event.keycode:
				options.get_node("%KeybindHint").text = "Already used by %s. Choose another key." % BINDINGS.LABELS[action].to_lower()
				return
		keybindings[capturing_action] = event.keycode
		BINDINGS.apply(keybindings)
		_save_settings()
		_cancel_keybind()
	elif event is InputEventMouseButton and event.pressed:
		_cancel_keybind()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if options.visible:
			_options_back()
		elif selection.visible:
			_navigate(show_runs)
		elif runs.visible:
			_transition_to_home()
		elif home.visible:
			audio.play_click()
			show_options(false)
		get_viewport().set_input_as_handled()
