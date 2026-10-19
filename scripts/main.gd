extends Control

var run: PackRun = PackRun.new()
var run_saves = preload("res://scripts/run_saves.gd").new()
var active_run_id: String = ""
var autosave_seconds: float = 0.0
var waiting_at_entrance: bool = false
var transition_popups: Control
@onready var gameplay_background: Control = $GameplayBackground
@onready var combat: Control = $Combat
@onready var playback: PackCombatPlayback = $CombatPlayback
@onready var front: PackMenuFlow = $MenuFlow
@onready var loading_screen: CanvasLayer = $LoadingScreen
@onready var combat_audio: AudioStreamPlayer = $CombatAudio
@onready var player_hit_audio: AudioStreamPlayer = $PlayerHitAudio
@onready var player_shield_hit_audio: AudioStreamPlayer = $PlayerShieldHitAudio
@onready var player_shield_break_audio: AudioStreamPlayer = $PlayerShieldBreakAudio
@onready var enemy_death_audio: AudioStreamPlayer = $EnemyDeathAudio
@onready var board: BackpackBoard = $Combat/CharacterPanel/Tabs/Backpack/Inventory
@onready var enemy_card: PackEnemyCard = $Combat/BattleArea/EnemyScroll/EnemyRoster/EnemyCard
@onready var enemy_art: TextureRect = $Combat/BattleArea/EnemyScroll/EnemyRoster/EnemyCard/EnemyArt
@onready var enemy_vitals: VBoxContainer = $Combat/BattleArea/EnemyScroll/EnemyRoster/EnemyCard/Vitals
@onready var enemy_hp: Label = $Combat/BattleArea/EnemyScroll/EnemyRoster/EnemyCard/Vitals/EnemyBar/ValueLabel
@onready var enemy_bar: PixelStatBar = $Combat/BattleArea/EnemyScroll/EnemyRoster/EnemyCard/Vitals/EnemyBar
@onready var enemy_shield_bar: PixelStatBar = $Combat/BattleArea/EnemyScroll/EnemyRoster/EnemyCard/Vitals/EnemyShieldBar
@onready var enemy_detail: RichTextLabel = $Combat/BattleArea/EnemyScroll/EnemyRoster/EnemyCard/EnemyDetail
@onready var hp_label: Label = $Combat/CharacterPanel/Tabs/Backpack/Player/HpBar/ValueLabel
@onready var hp_bar: PixelStatBar = $Combat/CharacterPanel/Tabs/Backpack/Player/HpBar
@onready var character_tabs: TabContainer = $Combat/CharacterPanel/Tabs
@onready var character_portrait: Control = $Combat/CharacterPanel/Tabs/Backpack/Player/Portrait
@onready var mana_bar: PixelStatBar = $Combat/CharacterPanel/Tabs/Backpack/Player/ManaBar
@onready var stamina_bar: PixelStatBar = $Combat/CharacterPanel/Tabs/Backpack/Player/StaminaBar
var class_status: String = ""
@onready var momentum_bar: PixelStatBar = $Combat/CharacterPanel/Tabs/Backpack/Player/MomentumBar
var hovered_enemy_status: String = ""
var updating_enemy_status_hover: bool = false
@onready var encounter_label: Label = $Combat/CharacterPanel/EncounterLabel
@onready var timer_label: Label = $Combat/CharacterPanel/TimerLabel
var values: Dictionary = {}
@onready var action: Button = $Combat/ActionFrame/Action
var relic_slots: Array[Panel] = []
@onready var modal: Control = $Overlay
@onready var pause_screen: Control = $Overlay/PauseScreen
@onready var application_frame: Control = $ApplicationFrame
@onready var settings_dock: Control = $ApplicationFrame/SettingsDock
@onready var settings_button: Button = $ApplicationFrame/SettingsDock/SettingsButton
var modal_kind: String = ""
var pause_menu_resume_combat: bool = false
var options_from_pause_menu: bool = false
var reward_is_relic: bool = false
@onready var modal_title: Label = $Overlay/DeathScreen/Title
@onready var modal_body: RichTextLabel = $Overlay/DeathScreen/Summary
var choice_buttons: Array[Button] = []
var choice_art: Array[TextureRect] = []
var choice_names: Array[Label] = []
var choice_details: Array[RichTextLabel] = []
var choice_shapes: Array[Control] = []
var result_buttons: Array[Button] = []
@onready var result_log: Control = $Overlay/ResultLog
var pause_buttons: Array[Button] = []
@onready var close_button: Button = $Overlay/CloseButton
@onready var reward_panel: Panel = $Overlay/RewardPanel
@onready var reward_title: Label = $Overlay/RewardPanel/Title
@onready var reward_body: Label = $Overlay/RewardPanel/Body
@onready var reward_close_button: Button = $Overlay/RewardPanel/CloseButton
@onready var inspector: PackInspector = $Inspector
@onready var history_view: RichTextLabel = $Combat/CharacterPanel/Tabs/Logs/History
@onready var stage_number: Label = $Combat/CharacterPanel/Tabs/Logs/Navigation/StageNumber
@onready var stage_monster: Label = $Combat/CharacterPanel/Tabs/Logs/Navigation/StageMonster
@onready var previous_stage: Button = $Combat/CharacterPanel/Tabs/Logs/Navigation/Previous
@onready var next_stage: Button = $Combat/CharacterPanel/Tabs/Logs/Navigation/Next
# -1 follows the current stage as the descent advances.
var log_stage_index: int = -1
@onready var storage: PackStorage = $Combat/BattleArea/Storage
@onready var storage_button: Button = combat.get_node("ActionFrame").get_node("%StorageButton")
@onready var item_reward_button: Button = combat.get_node("ActionFrame").get_node("%ItemRewardButton")
@onready var relic_reward_button: Button = combat.get_node("ActionFrame").get_node("%RelicRewardButton")
@onready var floor_flow: Control = $FloorFlow

var elapsed: float = 0.0
var busy: bool = false
var playback_speed: float = 1.0
const RESPONSE_DELAY: float = 1.5
var combat_sequence: int = 0

func _ready() -> void:
	transition_popups = Control.new()
	transition_popups.set_script(preload("res://scripts/combat_popup_overlay.gd"))
	transition_popups.name = "TransitionPopups"
	transition_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_popups.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	transition_popups.z_index = 100
	combat.add_child(transition_popups)
	hp_bar.animate_damage = true
	enemy_bar.animate_damage = true
	get_window().min_size = Vector2i(800, 450)
	# Standalone cards retain their preview bars; gameplay projects the HUD.
	enemy_vitals.reparent(combat.get_node("BattleArea"), false)
	enemy_vitals.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for bar: PixelStatBar in [enemy_bar, enemy_shield_bar]:
		bar.custom_minimum_size = Vector2(0, 48)
		bar.number_size = hp_bar.number_size
		bar.bar_height = hp_bar.bar_height
	enemy_vitals.move_child(enemy_vitals.get_node("Statuses"), 0)
	RenderingServer.frame_pre_draw.connect(_sync_enemy_vitals)
	gameplay_background.transition_changed.connect(_sync_enemy_vitals)
	enemy_card.visibility_changed.connect(_sync_enemy_vitals)
	_bind_gameplay()
	floor_flow.door_chosen.connect(_door_chosen)
	floor_flow.activity_chosen.connect(_room_action)
	floor_flow.inspection_target.connect(func(target: Control, data: Dictionary) -> void:
		inspector.register(target, func() -> Dictionary: return data)
		target.tree_exiting.connect(func() -> void:
			inspector.sources = inspector.sources.filter(func(entry: Dictionary) -> bool: return entry.target != target)))
	enemy_card.hit_started.connect(combat_audio.play)
	enemy_card.death_started.connect(enemy_death_audio.play)
	_bind_dialogs()
	gameplay_background.enemy_hover = $Combat/EnemyHover
	enemy_card.bind_world_art(gameplay_background.enemy, gameplay_background.enemy_screen_bounds)
	_bind_inspection()
	gameplay_background.reveal_changed.connect(func(amount: float) -> void: enemy_card.modulate.a = amount)
	front.loading_screen = loading_screen
	front.class_chosen.connect(_transition_start_run)
	front.saved_run_chosen.connect(_transition_resume_run)
	get_tree().auto_accept_quit = false
	front.resume_requested.connect(_resume_options)
	front.settings_changed.connect(_settings_changed)
	combat.hide()
	modal.hide()
	front.options_return_focus = settings_button
	settings_button.pressed.connect(_settings_pressed)
	for screen: Control in [combat, modal, front]:
		screen.visibility_changed.connect(_sync_settings_dock)
	front.home.visibility_changed.connect(_sync_settings_dock)
	_sync_settings_dock()
	_settings_changed()

func _process(delta: float) -> void:
	if combat.visible:
		floor_flow.refresh(run, gameplay_background, busy or modal.visible or front.visible or not board.dragging.is_empty() or storage.visible)
	else:
		floor_flow.hide()
	if combat.visible and not active_run_id.is_empty():
		autosave_seconds += delta
		if autosave_seconds >= 5.0:
			_save_run()
	_sync_settings_dock()
	inspector.enabled = not loading_screen.active and not gameplay_background.transitioning and combat.visible and (not modal.visible or modal_kind in ["reward", "result_log"]) and board.dragging.is_empty() and bool(front.settings["tooltips"])
	board.craft_inspection_active = not inspector.windows.is_empty() and inspector.windows[0].key.begins_with("crafts_")
	if combat.visible and not waiting_at_entrance and not playback.paused and modal_kind != "pause" and run.phase not in [PackRun.Phase.VICTORY, PackRun.Phase.DEFEAT]:
		elapsed += delta
	timer_label.text = "%02d:%02d" % [floori(elapsed / 60.0), int(elapsed) % 60]

func _sync_settings_dock() -> void:
	var on_title: bool = front.is_visible_in_tree() and front.home.is_visible_in_tree()
	settings_dock.visible = on_title or (combat.visible and (not modal.visible or modal_kind == "reward") and not front.visible)
	settings_button.disabled = not on_title and (gameplay_background.transitioning or (busy and not playback.active))
	settings_button.tooltip_text = "Open options" if on_title else "Open pause screen"
	settings_button.accessibility_name = "Options" if on_title else "Settings and pause menu"

func _sync_enemy_vitals() -> void:
	enemy_vitals.visible = enemy_card.is_visible_in_tree() and gameplay_background.enemy.has_spawn and not enemy_card.defeated and not gameplay_background.transitioning
	if not enemy_vitals.is_visible_in_tree() or not gameplay_background.enemy.texture:
		return
	var bounds: Rect2 = gameplay_background.enemy_screen_bounds()
	var area: Control = enemy_vitals.get_parent()
	# Alpha bounds exclude transparent padding. Keep the entire optional stack
	# above the head, with a compact width for rats and more room for large foes.
	var width: float = clampf(maxf(bounds.size.x, bounds.size.y) + 48.0, 160.0, 280.0)
	width = maxf(width, enemy_vitals.get_combined_minimum_size().x)
	enemy_vitals.size = Vector2(width, enemy_vitals.get_combined_minimum_size().y)
	var head: Vector2 = gameplay_background.get_global_transform_with_canvas() * Vector2(bounds.get_center().x, bounds.position.y)
	var center: Vector2 = area.get_global_transform_with_canvas().affine_inverse() * head
	enemy_vitals.position = Vector2(clampf(center.x - width * 0.5, 0.0, maxf(0.0, area.size.x - width)), maxf(0.0, center.y - enemy_vitals.size.y - 24.0)).round()

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_enemy_vitals):
		RenderingServer.frame_pre_draw.disconnect(_sync_enemy_vitals)

func _settings_pressed() -> void:
	if front.is_visible_in_tree() and front.home.is_visible_in_tree():
		front.show_options(false)
	else:
		_open_pause_menu()

func _bind_gameplay() -> void:
	board.priority_edit_started.connect(inspector.clear)
	board.item_hovered.connect(_play_inventory_hover)
	playback.player_resolved.connect(_player_resolved)
	playback.monster_resolved.connect(_monster_resolved)
	playback.fight_finished.connect(_fight_finished)
	playback.pause_changed.connect(_combat_pause_changed)
	for bar: PixelStatBar in [hp_bar, enemy_bar]:
		bar.side_boxes = true
		bar.number_mode = PixelStatBar.NumberMode.VALUE
		bar.protection_icon = PackKeywords.icon("block", true)
		bar.protection_color = PackKeywords.color("block")
		bar.badge_icon = PackKeywords.icon("health", true)
		bar.badge_icon_color = Color("d2b0b3")
		bar.accent_color = PackKeywords.color("health")
	hp_bar.badge_icon = PackKeywords.icon("health", true)
	hp_bar.accessibility_name = "Health"
	enemy_bar.accessibility_name = "Enemy health"
	mana_bar.accessibility_name = "Mana"
	stamina_bar.accessibility_name = "Stamina"
	stamina_bar.accent_color = PackKeywords.color("stamina")
	enemy_bar.badge_icon = PackKeywords.icon("health", true)
	enemy_shield_bar.hide()
	mana_bar.accent_color = PackKeywords.color("mana")
	character_tabs.tab_changed.connect(_character_tab_changed)
	var tab_labels: Dictionary = {"Backpack": "Character & Backpack", "Statistics": "Statistics", "Logs": "Logs", "Relics": "Relics"}
	for index in range(character_tabs.get_tab_count()):
		character_tabs.set_tab_tooltip(index, tab_labels[character_tabs.get_tab_control(index).name])
	board.run = run
	board.storage = storage
	board.storage_button = storage_button
	storage.board = board
	storage.backpack_requested.connect(func() -> void: character_tabs.current_tab = character_tabs.get_tab_idx_from_control(board.get_parent()))
	storage.manipulation_started.connect(inspector.clear)
	storage.item_hovered.connect(_play_inventory_hover)
	storage_button.pressed.connect(_toggle_storage)
	item_reward_button.pressed.connect(_open_reward.bind(false))
	relic_reward_button.pressed.connect(_open_reward.bind(true))
	board.changed.connect(_update_preview)
	action.pressed.connect(_act)
	previous_stage.pressed.connect(_change_log_stage.bind(-1))
	next_stage.pressed.connect(_change_log_stage.bind(1))
	var relic_grid: GridContainer = combat.get_node("CharacterPanel/Tabs/Relics/Grid")
	for slot: Panel in relic_grid.get_children():
		relic_slots.append(slot)
	relic_grid.slots_changed.connect(_relic_slots_changed)
	for stat: String in ["damage", "block", "healing", "vampirism", "plating", "ward", "poison", "burn", "mana", "stamina", "curse", "thorns", "cleanse", "slow"]:
		var row: String = stat.to_pascal_case()
		values[stat] = combat.get_node("CharacterPanel/Tabs/Statistics/Scroll/Rows/%s/%sValue" % [row, row])
		var label: RichTextLabel = combat.get_node("CharacterPanel/Tabs/Statistics/Scroll/Rows/%s/%sLabel" % [row, row])
		label.text = PackKeywordLinks.rich(stat.capitalize(), "", false)
		values[stat].add_theme_color_override("font_color", PackKeywords.color(stat))
	# Reuse the existing editable row for newly supported combat values.
	var stat_rows: Node = combat.get_node("CharacterPanel/Tabs/Statistics/Scroll/Rows")
	for stat: String in ["physical_damage", "magical_damage", "doom", "spark", "physical_resistance", "magical_resistance"]:
		var row: Control = stat_rows.get_node("Damage").duplicate()
		row.name = stat.to_pascal_case()
		stat_rows.add_child(row)
		var label: RichTextLabel = row.get_node("DamageLabel")
		var value: Label = row.get_node("DamageValue")
		label.name = stat.to_pascal_case() + "Label"
		value.name = stat.to_pascal_case() + "Value"
		label.text = PackKeywordLinks.rich(stat.replace("_", " ").capitalize(), "", false)
		value.text = "0"
		value.add_theme_color_override("font_color", PackKeywords.color(stat))
		values[stat] = value

func _bind_dialogs() -> void:
	for index in range(3):
		var button: Button = reward_panel.get_node("Choices/ChoiceButton%d" % (index + 1))
		button.pressed.connect(_choose.bind(index))
		button.mouse_entered.connect(_play_item_hover.bind(index, true))
		choice_buttons.append(button)
		choice_art.append(button.get_node("Content/Art"))
		choice_names.append(button.get_node("Content/Title"))
		choice_details.append(button.get_node("Content/Description"))
		choice_shapes.append(button.get_node("Content/Footprint"))
	for index in range(3):
		var button: Button = modal.get_node("DeathScreen/ResultActions/ResultButton%d" % (index + 1))
		button.pressed.connect([_show_result_log, _new_descent, _continue_descent][index])
		result_buttons.append(button)
	result_log.get_node("Navigation/Previous").pressed.connect(_change_log_stage.bind(-1))
	result_log.get_node("Navigation/Next").pressed.connect(_change_log_stage.bind(1))
	for index in range(3):
		var button: Button = pause_screen.get_node("%%PauseButton%d" % (index + 1))
		button.pressed.connect([_resume_from_pause_screen, _open_options, _transition_to_menu][index])
		pause_buttons.append(button)
	var restart_button: Button = pause_screen.get_node("%RestartButton")
	restart_button.confirmed.connect(_restart_from_pause_screen)
	for button_name: String in ["RestartButton", "LibraryButton", "RecipesButton"]:
		pause_buttons.append(pause_screen.get_node("%" + button_name))
	close_button.pressed.connect(_close_modal)
	reward_close_button.pressed.connect(_close_modal)

func _transition_start_run(chosen_class: String) -> void:
	if loading_screen.active:
		return
	await loading_screen.play(func() -> void:
		start_run(chosen_class)
		waiting_at_entrance = true
		enemy_card.hide()
		gameplay_background.prepare_entrance()
		_update_preview()
		_save_run()
	)
	if waiting_at_entrance:
		action.grab_focus()

func _enter_dungeon() -> void:
	waiting_at_entrance = false
	busy = true
	board.cancel_drag()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspector.clear()
	_update_preview()
	var sequence: int = combat_sequence
	await gameplay_background.descend(func() -> void:
		if sequence == combat_sequence:
			enemy_card.show()
			_refresh()
	, clampf(float(front.settings["combat_speed"]), 1.0, 4.0))
	if sequence != combat_sequence:
		return
	busy = false
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()
	_show_phase_modal()

func _transition_to_menu() -> void:
	loading_screen.play(func() -> void:
		show_menu()
		front.play_button.grab_focus()
	)

func start_run(chosen_class: String = "warrior", seed_value: int = -1, saved: Dictionary = {}) -> void:
	waiting_at_entrance = false
	pause_menu_resume_combat = false
	options_from_pause_menu = false
	_cancel_combat()
	combat_sequence += 1
	enemy_card.show()
	enemy_card.reset_feedback()
	combat_audio.stop()
	enemy_death_audio.stop()
	_clear_health_glow()
	_close_storage()
	board.cancel_drag()
	run.reset(seed_value, chosen_class)
	storage.reset_pile()
	if not saved.is_empty():
		run_saves.restore(run, saved)
	gameplay_background.reset(run.fight + 1)
	gameplay_background.world.set_room(gameplay_background.scene_for_state(run))
	_configure_floor_scene()
	log_stage_index = -1
	board.selected_id = -1
	elapsed = 0
	if not saved.is_empty():
		elapsed = saved.get("elapsed", 0.0)
		active_run_id = saved["id"]
	else:
		active_run_id = run_saves.new_id()
	busy = false
	front.hide()
	combat.show()
	modal.hide()
	modal_kind = ""
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	character_tabs.current_tab = character_tabs.get_tab_idx_from_control(board.get_parent())
	character_portrait.texture = PackArt.character_head(chosen_class)
	_refresh()
	_show_phase_modal()
	if not saved.is_empty():
		playback.restore(run, saved.get("playback", {}))
		if playback.snapshot().get("crafting_wait", false):
			board.show_crafting_merges(run.crafting_events, maxf(0.0, PackRun.CRAFTING.ANIMATION_SECONDS - playback.remaining_seconds))
		busy = playback.active
		_refresh()
	floor_flow.focus_first()
	_save_run()

func _save_run() -> bool:
	if active_run_id.is_empty():
		return true
	autosave_seconds = 0.0
	var saved: Dictionary = run_saves.capture(run, elapsed, playback)
	saved["waiting_at_entrance"] = waiting_at_entrance
	var success: bool = run_saves.write(active_run_id, saved)
	if not success:
		push_error("Could not save descent: " + error_string(run_saves.last_error))
	return success

func _transition_resume_run(id: String) -> void:
	var saved: Dictionary = run_saves.read(id)
	if saved.is_empty():
		front.runs.show_error("This run could not be loaded. Its save has been kept.")
		return
	saved["id"] = id
	loading_screen.play(func() -> void:
		start_run(saved.state.class_key, -1, saved)
		waiting_at_entrance = saved.get("waiting_at_entrance", false)
		if waiting_at_entrance:
			enemy_card.hide()
			gameplay_background.prepare_entrance()
			_update_preview()
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _save_run():
			get_tree().quit()

func show_menu() -> void:
	if not _save_run():
		return
	active_run_id = ""
	waiting_at_entrance = false
	pause_menu_resume_combat = false
	options_from_pause_menu = false
	_cancel_combat()
	combat_audio.stop()
	enemy_death_audio.stop()
	gameplay_background.reset()
	board.cancel_drag()
	_close_storage()
	modal.hide()
	modal_kind = ""
	combat.hide()
	floor_flow.hide()
	front.show_home()

func _new_descent() -> void:
	_transition_start_run(run.class_key)

func _continue_descent() -> void:
	loading_screen.play(func() -> void:
		show_menu()
		front.show_classes()
	)

func _settings_changed() -> void:
	pause_screen.get_node("%RestartButton").set_hold_required(bool(front.settings["hold_destructive_actions"]))
	timer_label.visible = bool(front.settings["show_run_time"])
	inspector.clear()
	inspector.lock_delay = float(front.settings["tooltip_lock_delay"])
	board.tooltips_enabled = bool(front.settings["tooltips"])
	if not bool(front.settings["flash"]):
		_clear_health_glow()
		board.clear_activation_feedback()

func _open_options() -> void:
	options_from_pause_menu = modal.visible and modal_kind == "pause"
	combat_audio.stop()
	enemy_death_audio.stop()
	_close_storage()
	modal.hide()
	combat.hide()
	front.show_options(true)

func _resume_options() -> void:
	combat.show()
	_refresh()
	if options_from_pause_menu:
		options_from_pause_menu = false
		_show_pause_screen()
	elif not playback.active:
		show_pause()

func _input(event: InputEvent) -> void:
	if loading_screen.active:
		get_viewport().set_input_as_handled()
		return
	if not combat.visible or not event is InputEventKey or not event.pressed or not preload("res://scripts/keybindings.gd").matches(event, "pause"):
		return
	if modal.visible:
		_close_modal()
	elif storage.visible:
		_close_storage()
	else:
		if not settings_button.disabled:
			settings_button.pressed.emit()
	get_viewport().set_input_as_handled()

func _act() -> void:
	if loading_screen.active:
		return
	if run.needs_arrows():
		if not modal.visible:
			_open_reward(false)
		return
	if modal_kind == "reward":
		_close_modal()
	if playback.active:
		if combat.visible and not modal.visible:
			playback.set_paused(not playback.paused)
		return
	if busy or not run.pending_turn.is_empty() or not board.dragging.is_empty() or modal.visible or not combat.visible:
		return
	_close_storage()
	if waiting_at_entrance:
		_enter_dungeon()
		return
	if run.phase in [PackRun.Phase.ROOM, PackRun.Phase.ROOM_COMPLETE]:
		await _room_action("leave" if run.phase == PackRun.Phase.ROOM else "continue")
		return
	if run.phase == PackRun.Phase.FIGHT:
		busy = true
		combat_sequence += 1
		board.mouse_filter = Control.MOUSE_FILTER_STOP
		playback_speed = clampf(float(front.settings["combat_speed"]), 0.5, 10.0)
		if playback.start(run, playback_speed, enemy_card.hit_rise_seconds + enemy_card.hit_settle_seconds, PackEnemyCard.STRIKE_SECONDS, PackEnemyCard.DEATH_SECONDS, float(front.settings["player_response_delay"]), float(front.settings["enemy_response_delay"])):
			board.show_crafting_merges(run.crafting_events)

func _player_resolved(result: Dictionary) -> void:
	var speed: float = playback_speed
	_refresh()
	board.show_item_effects(result, speed)
	enemy_card.show_combat_effects(result, speed)
	if bool(front.settings["flash"]):
		board.flash_failed_activations(result.get("dormant_ids", []), speed)
		if _actual_enemy_damage(result) > 0:
			enemy_bar.flash_glow(speed)
		if int(result["special_taken"]) > 0:
			hp_bar.flash_glow(speed)
	if _actual_enemy_damage(result) > 0:
		enemy_card.play_hit(bool(front.settings["flash"]), speed, run.enemy["hp"] <= 0)

func _monster_resolved(result: Dictionary) -> void:
	var speed: float = playback_speed
	transition_popups.show_player_hit(result, str(run.enemy.get("damage_type", "physical")), speed)
	if result.get("player_hit_shielded", false):
		player_shield_hit_audio.play()
	if result.get("player_hit_unshielded", false):
		player_hit_audio.play()
	if result.get("player_shield_broken", false):
		player_shield_break_audio.play()
	_refresh()
	if bool(front.settings["flash"]):
		if int(result["taken"]) > 0:
			hp_bar.flash_glow(speed)
		if int(result["retaliation"]) > 0:
			enemy_bar.flash_glow(speed)
	if result.get("playback_strikes", false):
		var strike: Tween = enemy_card.play_strike(speed)
		strike.tween_callback(board.show_item_effects.bind(result, speed, true))
		if int(result["retaliation"]) > 0:
			strike.tween_callback(enemy_card.play_hit.bind(bool(front.settings["flash"]), speed, run.enemy["hp"] <= 0))
	elif int(result["retaliation"]) > 0:
		enemy_card.play_hit(bool(front.settings["flash"]), speed, run.enemy["hp"] <= 0)

func _fight_finished() -> void:
	busy = false
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()
	_show_phase_modal()

func _combat_pause_changed(value: bool) -> void:
	transition_popups.paused = value
	_refresh_history()
	board.set_activation_feedback_paused(value)
	enemy_card.set_feedback_paused(value)
	for bar: PixelStatBar in [hp_bar, enemy_bar, mana_bar, stamina_bar, enemy_shield_bar]:
		bar.set_glow_paused(value)
	combat_audio.stream_paused = value
	enemy_death_audio.stream_paused = value
	for sound: AudioStreamPlayer in [player_hit_audio, player_shield_hit_audio, player_shield_break_audio]:
		sound.stream_paused = value
	_update_action_control()

func _cancel_combat() -> void:
	transition_popups.clear()
	combat_audio.stop()
	enemy_death_audio.stop()
	for sound: AudioStreamPlayer in [player_hit_audio, player_shield_hit_audio, player_shield_break_audio]:
		sound.stop()
	combat_sequence += 1
	playback.cancel()
	board.clear_activation_feedback()
	_combat_pause_changed(false)
	enemy_card.reset_feedback()
	_clear_health_glow()
	busy = false


func _clear_health_glow() -> void:
	hp_bar.clear_glow()
	enemy_bar.clear_glow()
	hp_bar.clear_damage_feedback()
	enemy_bar.clear_damage_feedback()

func _refresh() -> void:
	# Live combat updates vitals twice per turn. Keep passive inspection open.
	if not playback.active:
		inspector.clear()
	_refresh_history()
	board.refresh()
	enemy_art.texture = PackArt.enemy(run.enemy["key"])
	gameplay_background.enemy.set_art(enemy_art.texture)
	enemy_card.set_monster(run.enemy["key"])
	enemy_card.visible = run.has_combat_room() and not waiting_at_entrance
	var protection: int = run.enemy_block()
	_set_health_block(enemy_bar, run.enemy["hp"], run.enemy["max_hp"], protection)
	enemy_shield_bar.hide()
	_update_status_rows()
	enemy_detail.text = PackKeywordLinks.rich(_enemy_rules(), "", false)
	hp_bar.set_amount(run.hp, run.max_hp)
	encounter_label.text = "%02d / 20" % run.display_floor()
	_update_preview()
	_refresh_relics()
	floor_flow.refresh(run, gameplay_background, busy or modal.visible or front.visible)

func _relic_slots_changed() -> void:
	var grid: GridContainer = combat.get_node("CharacterPanel/Tabs/Relics/Grid")
	for index in range(relic_slots.size(), grid.get_child_count()):
		var slot: Panel = grid.get_child(index)
		relic_slots.append(slot)
		inspector.register(slot, _relic_inspection.bind(index))
		slot.mouse_entered.connect(_play_item_hover.bind(index, false))
	_refresh_relics()

func _refresh_relics() -> void:
	for index in range(relic_slots.size()):
		var bound: bool = index < run.relics.size()
		var relic: Dictionary = PackCatalog.relic(run.relics[index]) if bound else {}
		var art: TextureRect = relic_slots[index].get_node("Art")
		art.texture = PackArt.relic(relic["key"]) if bound else null
		art.modulate.a = 0.4 if bound and relic["key"] == "last_thread" and run.last_thread_used else 1.0
		relic_slots[index].occupied = bound
		relic_slots[index].accent = PackCatalog.RARITY.color(relic) if bound else Color("c5b48a")
		relic_slots[index].focus_mode = Control.FOCUS_ALL if bound else Control.FOCUS_NONE
		relic_slots[index].accessibility_name = str(relic["name"]) + ", " + PackCatalog.RARITY.label(relic) if bound else "Empty relic slot"

func _refresh_history() -> void:
	var latest: int = run.stage_history.size() - 1
	var selected: int = latest if log_stage_index < 0 else mini(log_stage_index, latest)
	previous_stage.disabled = selected <= 0
	next_stage.disabled = selected >= latest
	var log_text: String = "Your descent begins here."
	stage_number.text = ""
	stage_monster.text = ""
	if selected >= 0:
		var stage: Dictionary = run.stage_history[selected]
		stage_number.text = "Stage %02d" % stage["number"]
		stage_monster.text = stage["name"]
		var lines: Array[String] = []
		var action_starts: Array = stage.get("action_starts", [])
		for index in range(stage["lines"].size()):
			if str(stage["lines"][index]).begins_with("Claimed ") or str(stage["lines"][index]).begins_with("Relic bound: "):
				continue
			if action_starts.find(index) > 0:
				lines.append("[hr width=100% height=2 color=#394855]")
			lines.append(str(stage["lines"][index]).replace(" An item choice is available whenever I am ready.", ""))
		log_text = "\n".join(lines) if not lines.is_empty() else "No events yet."
	history_view.scroll_following = selected == latest and run.combat_state != PackRun.CombatState.PAUSED
	var formatted: String = PackKeywordLinks.rich(log_text)
	var appearance: String = PackKeywordLinks.hover_markup(formatted, str(history_view.get_meta("hovered_link", "")), history_view.get_theme_color("default_color"))
	if history_view.text != appearance:
		history_view.text = appearance
	if is_instance_valid(result_log):
		var result_history: RichTextLabel = result_log.get_node("History")
		result_history.text = PackKeywordLinks.hover_markup(formatted, str(result_history.get_meta("hovered_link", "")), result_history.get_theme_color("default_color"))
		result_log.get_node("Navigation/StageNumber").text = stage_number.text
		result_log.get_node("Navigation/StageMonster").text = stage_monster.text
		result_log.get_node("Navigation/Previous").disabled = previous_stage.disabled
		result_log.get_node("Navigation/Next").disabled = next_stage.disabled

func _select_log_stage(index: int) -> void:
	if index < 0 or index >= run.stage_history.size():
		return
	log_stage_index = -1 if index == run.stage_history.size() - 1 else index
	inspector.clear()
	_refresh_history()
	history_view.scroll_to_line(0)
	result_log.get_node("History").scroll_to_line(0)

func _change_log_stage(direction: int) -> void:
	var latest: int = run.stage_history.size() - 1
	var selected: int = latest if log_stage_index < 0 else mini(log_stage_index, latest)
	_select_log_stage(selected + direction)


func _update_preview() -> void:
	if run.enemy.is_empty():
		return
	var stats: Dictionary = run.pending_turn if not run.pending_turn.is_empty() else board.preview_effects()
	for stat in values:
		values[stat].text = str(stats.get(stat, 0)) + ("%" if stat.ends_with("_resistance") else "")
	var class_summary: String = "%d item(s) waiting for resources" % stats["dormant_ids"].size()
	match run.class_key:
		"warrior": class_summary = "Momentum %d / +%d per round" % [run.momentum, run.momentum_gain()]
		"ranger": class_summary = "Choose starting arrows" if run.needs_arrows() else "Volley in %d round(s)" % run.volley_remaining
		"mage": class_summary = "%d reaction(s) ready" % stats.get("reactions", []).size()
		"assassin": class_summary = "Invisible: cannot be targeted" if run.is_invisible() else "Shadowstep in %d turn(s)" % (3 - (run.turn - 1) % 3)
		"necromancer": class_summary = "%d/%d bone thralls / +%d damage" % [run.undead_companions, PackRun.NECROMANCER_COMPANION_CAP, stats["companion_damage"]]
	var unused_count: int = board.unpacked().size()
	storage_button.accessibility_name = "Stash (%d)" % unused_count
	var preparing: bool = run.can_edit_inventory()
	var resources: Dictionary = board.preview_starting_resources() if preparing else {"mana": run.mana, "stamina": run.stamina, "block": run.block}
	for resource: String in ["mana", "stamina", "block"]:
		values[resource].text = str(resources[resource])
	class_status = class_summary
	var volley_badge: Label = character_portrait.get_node("VolleyCountdown")
	volley_badge.visible = run.class_key == "ranger" and not run.needs_arrows()
	volley_badge.text = str(run.volley_remaining)
	momentum_bar.visible = run.class_key == "warrior"
	momentum_bar.accessibility_name = "Momentum"
	momentum_bar.number_mode = PixelStatBar.NumberMode.HIDDEN
	# Expanding display scale, not a cap on the resource.
	momentum_bar.set_amount(run.momentum, maxi(5, ceili((run.momentum + 1) / 5.0) * 5))
	mana_bar.number_mode = PixelStatBar.NumberMode.HIDDEN
	stamina_bar.number_mode = PixelStatBar.NumberMode.HIDDEN
	mana_bar.set_amount(resources["mana"], resources["mana"] if preparing else run.mana_capacity)
	stamina_bar.set_amount(resources["stamina"], resources["stamina"] if preparing else run.stamina_capacity)
	_set_health_block(hp_bar, run.hp, run.max_hp, resources["block"])
	_update_action_control()
	_sync_settings_dock()
	storage_button.disabled = busy
	for button: Button in [item_reward_button, relic_reward_button]:
		var count: int = run.relic_rewards.size() if button == relic_reward_button else run.item_rewards.size()
		var label: String = "Relic" if button == relic_reward_button else "Item"
		button.disabled = not run.can_claim_rewards() or busy or not board.dragging.is_empty() or count == 0
		button.get_node("Badge").visible = count > 0
		button.tooltip_text = "Choose an item reward for your inventory." if button == item_reward_button else "Choose a relic reward for this descent."
		button.accessibility_name = "%s reward available" % label if count > 0 else "No %s reward available" % label.to_lower()

func _update_action_control() -> void:
	var in_basement: bool = gameplay_background.is_at_entrance()
	var label: String = "Resume combat" if playback.active and playback.paused else ("Pause combat" if playback.active else "Attack")
	if in_basement:
		label = "Enter dungeon"
	var activity: bool = run.phase in [PackRun.Phase.ROOM, PackRun.Phase.ROOM_COMPLETE]
	if activity:
		label = "Leave without claiming" if run.room_reward_pending else ("Leave without resting" if run.room_kind == "rest" and run.phase == PackRun.Phase.ROOM else "Continue to the doors")
	action.text = ""
	action.accessibility_name = label
	action.tooltip_text = "Enter dungeon" if in_basement else ""
	action.icon = load("res://assets/ui/icons/combat-v1/resume.svg") if playback.active and playback.paused else (load("res://assets/ui/icons/navigation-v3/pause.png") if playback.active else load("res://assets/ui/icons/attack/attack.png"))
	if in_basement:
		action.icon = load("res://assets/ui/icons/enter-dungeon/enter-dungeon.svg")
	if activity:
		action.icon = load("res://assets/ui/icons/enter-dungeon/enter-dungeon.svg")
		action.tooltip_text = label
	action.expand_icon = true
	action.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.add_theme_constant_override("icon_max_width", 64 if in_basement else (48 if playback.active else 32))
	action.disabled = not playback.active and (busy or not board.dragging.is_empty() or (run.phase != PackRun.Phase.FIGHT and not activity))

func _clear_modal(kind: String) -> void:
	_close_storage()
	inspector.clear()
	board.cancel_drag()
	board.mouse_filter = Control.MOUSE_FILTER_STOP if kind == "reward" else Control.MOUSE_FILTER_IGNORE
	modal_kind = kind
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE if kind == "reward" else Control.MOUSE_FILTER_STOP
	modal.show()
	pause_screen.visible = kind == "pause"
	reward_panel.visible = kind == "reward"
	result_log.visible = kind == "result_log"
	modal.get_node("LogTitle").visible = kind == "result_log"
	modal.get_node("DeathScreen").visible = kind in ["result", "result_log"]
	modal.get_node("Dimmer").visible = kind == "result_log"
	modal.get_node("DialogFrame").visible = kind == "result_log"
	modal_title.visible = kind == "result"
	modal_body.visible = kind == "result"
	# Temporary record until previous descents are persisted.
	modal.get_node("DeathScreen/LowestFloor").visible = kind == "result" and run.phase == PackRun.Phase.DEFEAT
	for button in choice_buttons + result_buttons + pause_buttons:
		button.hide()
	close_button.visible = kind == "result_log"

func _close_modal() -> void:
	if modal_kind == "result_log":
		_show_phase_modal()
		result_buttons[0].grab_focus()
		return
	if not modal.visible or (not close_button.visible and modal_kind not in ["pause", "reward"] and not (modal_kind == "result" and run.phase == PackRun.Phase.VICTORY)):
		return
	var resume_combat: bool = modal_kind == "pause" and pause_menu_resume_combat
	pause_menu_resume_combat = false
	modal.hide()
	modal_kind = ""
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	if resume_combat:
		playback.set_paused(false)

func _resume_from_pause_screen() -> void:
	_close_modal()
	if playback.active:
		playback.set_paused(false)

func _restart_from_pause_screen() -> void:
	if modal.visible and modal_kind == "pause" and combat.visible:
		_transition_start_run(run.class_key)

func show_pause() -> void:
	if playback.active and combat.visible and not modal.visible:
		playback.set_paused(not playback.paused)
		return
	if busy or not combat.visible or modal.visible:
		return
	_open_pause_menu()

func _open_pause_menu() -> void:
	if modal_kind == "reward":
		_close_modal()
	if not combat.visible or modal.visible or gameplay_background.transitioning:
		return
	pause_menu_resume_combat = playback.active and not playback.paused
	playback.set_paused(true)
	_show_pause_screen()
	_save_run()

func _show_pause_screen() -> void:
	_clear_modal("pause")
	pause_buttons[0].text = "RESUME"
	modal_title.text = "Descent paused"
	modal_body.text = "Floor %d / %s" % [run.fight + 1, front.player_name(run.class_key)]
	for button in pause_buttons:
		button.show()
	pause_buttons[0].grab_focus()

func show_record() -> void:
	if (busy and not playback.paused) or modal.visible:
		return
	character_tabs.current_tab = character_tabs.get_tab_idx_from_control(history_view.get_parent())

func _show_phase_modal() -> void:
	if run.needs_arrows() and run.can_claim_rewards():
		_open_reward(false)
		return
	if run.phase == PackRun.Phase.LOOT:
		_advance_encounter()
		return
	if run.phase not in [PackRun.Phase.VICTORY, PackRun.Phase.DEFEAT]:
		return
	_clear_modal("result")
	modal_title.text = "The curse is broken" if run.phase == PackRun.Phase.VICTORY else "The satchel fall silent"
	var identity: String = front.player_name(run.class_key)
	if int(front.settings["name_display"]) != 1 or str(front.settings["character_name"]).strip_edges().is_empty():
		identity = "the " + identity
	var won: bool = run.phase == PackRun.Phase.VICTORY
	var result_text: String = "Cleared the last floor as %s" % identity if won else "Died as %s on floor %d" % [identity, run.fight + 1]
	if bool(front.settings["show_run_time"]):
		result_text += " in %02d:%02d" % [floori(elapsed / 60.0), int(elapsed) % 60]
	modal_body.text = result_text.replace("[", "[lb]")
	var record: Label = modal.get_node("DeathScreen/LowestFloor")
	if won:
		record.text = "New record!"
		record.visible = run_saves.is_victory_record(elapsed, active_run_id)
	else:
		record.text = "Lowest floor: %d" % (run.fight + 1)
	for button in result_buttons:
		button.show()
	result_buttons[1].grab_focus()

func _show_result_log() -> void:
	_clear_modal("result_log")
	log_stage_index = -1
	_refresh_history()
	close_button.grab_focus()

func _open_reward(is_relic: bool) -> void:
	if not run.can_claim_rewards() or busy or (modal.visible and modal_kind != "reward") or not combat.visible or not board.dragging.is_empty():
		return
	if modal.visible and reward_is_relic == is_relic:
		_close_modal()
		return
	var keys: Array[String] = run.relic_offers if is_relic else run.offers
	if keys.is_empty():
		return
	reward_is_relic = is_relic
	_clear_modal("reward")
	var floor_number: int = run.relic_rewards[0] if is_relic else int(run.item_rewards[0]["floor"])
	reward_title.text = "CHOOSE A RELIC / %02d" % floor_number if is_relic else "CHOOSE AN ITEM / %02d" % floor_number
	reward_body.text = "Choose one. Close to save this choice for later."
	if not is_relic and run.needs_arrows():
		reward_title.text = "CHOOSE YOUR ARROWS"
		reward_body.text = "Choose the starting arrows for your Bowmaster's Quiver."
	elif not is_relic:
		reward_title.text = "CHOOSE A REWARD / %02d" % floor_number
	for button: Button in choice_buttons:
		button.hide()
	for index in range(keys.size()):
		var item: Dictionary = PackCatalog.relic(keys[index]) if is_relic else PackCatalog.item(keys[index])
		choice_buttons[index].show()
		choice_art[index].texture = PackArt.relic(item["key"]) if is_relic else PackArt.item(item["key"], 64)
		choice_names[index].text = item["name"] + " / " + PackCatalog.RARITY.label(item)
		choice_names[index].add_theme_color_override("font_color", PackCatalog.RARITY.color(item))
		choice_details[index].set_description(item["detail"])
		choice_shapes[index].visible = not is_relic and not PackCatalog.QUIVER.OPTIONS.has(keys[index])
		choice_shapes[index].set_meta("cells", [] if is_relic else PackRun.offsets(item))
		choice_shapes[index].position.x = 64 if is_relic else 64 - PackRun.dimensions(item).x * 3
		choice_shapes[index].queue_redraw()

func _choose(index: int) -> void:
	if not run.can_claim_rewards() or busy or not modal.visible or modal_kind != "reward":
		return
	var keys: Array[String] = run.relic_offers if reward_is_relic else run.offers
	if index < 0 or index >= keys.size():
		return
	if reward_is_relic:
		run.choose_relic(run.relic_offers[index])
	else:
		run.choose_loot(run.offers[index])
	modal.hide()
	modal_kind = ""
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()
	_open_reward(reward_is_relic)

func _preserve_transition_popups() -> void:
	transition_popups.take_from(board, board.effect_popups)
	transition_popups.take_from(enemy_card, enemy_card.effect_popups)

func _advance_encounter() -> void:
	if busy:
		return
	_preserve_transition_popups()
	run.advance_encounter()
	board.clear_activation_feedback()
	_clear_health_glow()
	if run.phase == PackRun.Phase.SELECTOR:
		await _travel_floor_scene()
		return
	_refresh()
	_show_phase_modal()

func _configure_floor_scene() -> void:
	var room: Node3D = gameplay_background.world.active_room
	if run.phase == PackRun.Phase.SELECTOR and room.has_method("configure"):
		room.configure(run.door_choices)
	if room.get_script() == preload("res://scripts/gameplay/rooms/encounter_room.gd"):
		room.combat_active = run.has_combat_room()
		gameplay_background.world.place_enemy_at_slot()

func _door_chosen(id: String) -> void:
	if busy or modal.visible or front.visible or not board.dragging.is_empty() or storage.visible or run.phase != PackRun.Phase.SELECTOR:
		return
	var room: Node3D = gameplay_background.world.active_room
	if not room.has_method("select_exit") or not room.select_exit(id):
		return
	if run.choose_destination(id):
		await _travel_floor_scene()

func _room_action(action_id: String) -> void:
	if busy or modal.visible or front.visible or not board.dragging.is_empty() or storage.visible:
		return
	if action_id == "continue":
		if run.enter_selector():
			await _travel_floor_scene()
		return
	if run.resolve_room(action_id):
		var activity_room: Node3D = gameplay_background.world.active_room
		if activity_room.has_method("retire_activity") and run.phase == PackRun.Phase.ROOM_COMPLETE:
			var sequence: int = combat_sequence
			busy = true
			inspector.clear()
			_save_run()
			await activity_room.retire_activity()
			if sequence != combat_sequence:
				return
			busy = false
		_configure_floor_scene()
		if run.phase == PackRun.Phase.FIGHT:
			enemy_card.reset_feedback()
		_refresh()
		_save_run()
		floor_flow.focus_first()
		if action_id == "leave" and run.enter_selector():
			await _travel_floor_scene()

func _travel_floor_scene() -> void:
	busy = true
	board.cancel_drag()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspector.clear()
	enemy_card.hide()
	floor_flow.hide()
	_save_run()
	var sequence: int = combat_sequence
	await gameplay_background.travel_to(gameplay_background.scene_for_state(run), func() -> void:
		if sequence == combat_sequence:
			_configure_floor_scene()
			_refresh()
	, clampf(float(front.settings["combat_speed"]), 0.5, 10.0))
	if sequence != combat_sequence:
		return
	busy = false
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()
	floor_flow.focus_first()
	_save_run()

func _character_tab_changed(_index: int) -> void:
	board.cancel_drag()
	_close_storage()
	inspector.clear()

func _toggle_storage() -> void:
	if modal_kind == "reward":
		_close_modal()
	if busy or modal.visible or not board.dragging.is_empty():
		return
	if storage.visible:
		_close_storage()
	else:
		character_tabs.current_tab = character_tabs.get_tab_idx_from_control(board.get_parent())
		inspector.clear()
		storage.refresh()
		storage.show()

func _close_storage() -> void:
	storage.hide()
	inspector.clear()

func _bind_inspection() -> void:
	inspector.register_links(history_view)
	inspector.register_links(result_log.get_node("History"))
	for index in range(3):
		inspector.register(choice_buttons[index], _reward_inspection.bind(index))
	board.managed_inspection = true
	inspector.register(board, _item_inspection)
	for stat: String in values:
		var control: Control = values[stat]
		inspector.register(control, _stat_inspection.bind(stat))
		inspector.register(control.get_parent().get_node(stat.to_pascal_case() + "Label"), _stat_inspection.bind(stat))
	inspector.register(hp_bar, func() -> Dictionary: return _explanation("health", "%d / %d HP\n%d block: absorbs incoming strikes." % [run.hp, run.max_hp, roundi(hp_bar.protection_amount)]))
	inspector.register(mana_bar, func() -> Dictionary: return PackKeywordLinks.entry("mana"))
	inspector.register(momentum_bar, func() -> Dictionary: return PackKeywordLinks.entry("momentum"))
	inspector.register(stamina_bar, func() -> Dictionary: return PackKeywordLinks.entry("stamina"))
	inspector.register(character_portrait, _character_inspection)
	inspector.register(gameplay_background.enemy_hover, _enemy_inspection)
	inspector.register(enemy_bar, _enemy_inspection)
	inspector.register(enemy_shield_bar, _enemy_inspection)
	var enemy_status: RichTextLabel = enemy_vitals.get_node("Statuses/Content")
	inspector.register(enemy_status, _enemy_status_inspection)
	enemy_status.meta_underlined = false
	enemy_status.meta_hover_started.connect(func(meta: Variant) -> void:
		hovered_enemy_status = str(meta)
		_update_status_rows())
	enemy_status.meta_hover_ended.connect(func(meta: Variant) -> void:
		if not updating_enemy_status_hover and hovered_enemy_status == str(meta):
			hovered_enemy_status = ""
			_update_status_rows())
	enemy_status.mouse_exited.connect(func() -> void:
		hovered_enemy_status = ""
		_update_status_rows())
	for index in range(relic_slots.size()):
		inspector.register(relic_slots[index], _relic_inspection.bind(index))
		relic_slots[index].mouse_entered.connect(_play_item_hover.bind(index, false))
	inspector.register(storage, _storage_inspection)
	storage_button.tooltip_text = "Open your stash. Move items into your backpack to use them."

func _explanation(key: String, context: String) -> Dictionary:
	var data: Dictionary = PackKeywordLinks.entry(key)
	data["body"] = context + "\n\n" + data["body"]
	return data

func _stat_inspection(stat: String) -> Dictionary:
	return PackKeywordLinks.entry({"physical_damage": "physical_attack", "magical_damage": "magical_attack"}.get(stat, stat))

func _set_health_block(bar: PixelStatBar, health: int, maximum: int, block: int) -> void:
	bar.accent_color = PackKeywords.color("health")
	bar.set_protected_amount(health, maximum, block)
	bar.accessibility_name = "Health %d of %d, block %d" % [health, maximum, block]

func _actual_enemy_damage(result: Dictionary) -> int:
	var total: int = 0
	for key: String in ["direct_damage_actual", "poison_damage_actual", "burn_damage_actual", "doom_damage_actual", "spark_damage_actual"]:
		total += int(result.get(key, 0))
	return total

func _update_status_rows() -> void:
	var enemy_status: RichTextLabel = enemy_vitals.get_node("Statuses/Content")
	var parts: PackedStringArray = []
	for key: String in run.enemy_conditions():
		var amount: int = int(run.enemy_conditions()[key])
		if amount <= 0:
			continue
		var glyph: String = PackKeywords.image_markup(key)
		if glyph.is_empty():
			glyph = key.capitalize()
		var fuse: String = " (%d)" % run.enemy_doom_turns if key == "doom" else ""
		parts.append("[url=%s][color=#%s]%d %s%s[/color][/url]" % [key, PackKeywords.color(key).to_html(false), amount, glyph, fuse])
	for element: String in run.elemental_traces:
		var count: int = run.elemental_traces[element].size()
		if count > 0:
			parts.append("[url=%s][color=#%s]%s ×%d[/color][/url]" % [element, PackKeywords.color(element).to_html(false), element.capitalize(), count])
	var markup: String = "[center]" + "    ".join(parts) + "[/center]"
	var appearance: String = PackKeywordLinks.hover_markup(markup, hovered_enemy_status, enemy_status.get_theme_color("default_color"))
	if enemy_status.text != appearance:
		updating_enemy_status_hover = true
		enemy_status.text = appearance
		updating_enemy_status_hover = false
	enemy_status.get_parent().visible = true
	var player_status: RichTextLabel = character_tabs.get_node("Backpack/Statuses")
	player_status.text = PackKeywordLinks.rich("Poison %d" % run.player_poison, "", false) if run.player_poison > 0 else ""

func _enemy_status_inspection() -> Dictionary:
	if int(run.enemy_conditions().get(hovered_enemy_status, 0)) <= 0 and run.elemental_traces.get(hovered_enemy_status, []).is_empty():
		return {}
	var data: Dictionary = PackKeywordLinks.entry(hovered_enemy_status)
	# Anchor to the hovered pair, not the wide centered text control.
	var status: Control = enemy_vitals.get_node("Statuses/Content")
	data["rect"] = Rect2(Vector2(inspector.pointer.x - 24, status.global_position.y), Vector2(48, status.size.y))
	return data

func _item_inspection() -> Dictionary:
	var item: Dictionary = board.hit_item(board.pointer)
	if item.is_empty():
		return {}
	var rect: Rect2 = board.item_rect(item)
	rect.position += board.global_position
	return _describe_item(item, rect)

func _storage_inspection() -> Dictionary:
	var item: Dictionary = storage.hovered_item()
	return _describe_item(item, storage.item_rect(item)) if not item.is_empty() else {}

func _describe_item(item: Dictionary, rect: Rect2) -> Dictionary:
	if Input.is_key_pressed(KEY_ALT):
		var recipes: Dictionary = PackRun.CRAFTING.recipe_inspection(run, item)
		if not recipes.is_empty():
			recipes["rect"] = rect
			return recipes
	var body: String = PackKeywords.item_description(item)
	if run.is_permanent(item):
		body = run.quiver_description()
	var costs: Array[Dictionary] = PackKeywords.item_resource_costs(item)
	var bonus: int = run.item_bonus(item)
	var presentation = preload("res://scripts/item_presentation.gd")
	return {"key": "item_%d" % item["id"], "rarity": PackCatalog.RARITY.tier(item), "title": presentation.display_name(item), "body": body, "keyword_list": [] if run.is_permanent(item) else PackKeywords.item_stats(item, bonus), "keyword_stats": presentation.volley_stats(run, item), "bonuses": presentation.bonuses(run, item), "resource_costs": costs, "priority_label": "" if costs.is_empty() else PackKeywords.item_priority_label(item), "bound": run.is_permanent(item), "rect": rect}

func _character_inspection() -> Dictionary:
	var data: Dictionary = PackCatalog.classes()[run.class_key]
	return {"key": "class_" + run.class_key, "title": front.player_name(run.class_key) + " / " + data["mechanic"], "keyword_stats": PackCatalog.innate_stats(run.class_key), "body": data["detail"] + "\n\n" + class_status}

func _enemy_inspection() -> Dictionary:
	if run.enemy.is_empty() or not run.has_combat_room():
		return {}
	return preload("res://scripts/enemy_presentation.gd").inspection(run)

func _enemy_rules() -> String:
	# Old saves may contain the previous terminology in their copied enemy brief.
	var rules: String = str(run.enemy["detail"]).replace("shields", "block").replace("shield", "block").replace("Shield", "Block")
	for key: String in ["physical_resistance", "magical_resistance"]:
		if int(run.enemy.get(key, 0)) > 0:
			rules += "\n%s %d%%" % [key.replace("_", " ").capitalize(), run.enemy[key]]
	return rules

func _relic_inspection(index: int) -> Dictionary:
	if index >= run.relics.size():
		return {}
	var data: Dictionary = PackCatalog.relic(run.relics[index])
	return {"key": "relic_" + data["key"], "rarity": PackCatalog.RARITY.tier(data), "title": data["name"], "icon": PackArt.relic(data["key"]), "keyword_stats": PackKeywords.relic_stats(data), "body": data["detail"] + ("\n\nConsumed this run." if data["key"] == "last_thread" and run.last_thread_used else "")}

func _play_item_hover(index: int, from_reward: bool) -> void:
	if not combat.is_visible_in_tree() or loading_screen.active or not board.dragging.is_empty():
		return
	if from_reward:
		if not modal.visible or _reward_inspection(index).is_empty():
			return
	elif index >= run.relics.size() or not relic_slots[index].is_visible_in_tree() or modal.visible:
		return
	front.audio.play_item_hover()

func _play_inventory_hover() -> void:
	if combat.is_visible_in_tree() and not loading_screen.active and not modal.visible and board.dragging.is_empty():
		front.audio.play_item_hover()

func _reward_inspection(index: int) -> Dictionary:
	if modal_kind != "reward":
		return {}
	if reward_is_relic and index < run.relic_offers.size():
		var relic: Dictionary = PackCatalog.relic(run.relic_offers[index])
		return {"key": "reward_" + relic["key"], "rarity": PackCatalog.RARITY.tier(relic), "title": relic["name"], "body": relic["detail"], "keyword_stats": PackKeywords.relic_stats(relic), "icon": PackArt.relic(relic["key"])}
	if not reward_is_relic and index < run.offers.size():
		var item: Dictionary = PackCatalog.item(run.offers[index])
		var body: String = PackKeywords.item_description(item)
		var costs: Array[Dictionary] = PackKeywords.item_resource_costs(item)
		return {"key": "reward_" + item["key"], "rarity": PackCatalog.RARITY.tier(item), "title": item["name"], "body": body, "keyword_list": PackKeywords.item_stats(item), "resource_costs": costs, "priority_label": "" if costs.is_empty() else PackKeywords.item_priority_label(item)}
	return {}
