extends CanvasLayer
## Presentation only. All state mutations pass through the host.
const KEYS = preload("res://systems/application/keybindings.gd")
const SESSION = preload("res://systems/development/dev_session.gd")
const PLAYER_STATS: Array[String] = ["hp", "max_hp", "mana", "stamina", "block", "momentum", "undead_companions", "volley_remaining"]
const ENEMY_STATS: Array[String] = ["hp", "enemy_poison", "enemy_burn", "enemy_slow", "enemy_spark", "enemy_doom", "enemy_doom_turns"]
const ROOM_KINDS: Array[String] = ["combat", "rest", "relic", "encounter", "selector"]
@onready var host: Node = $Host
@onready var search: LineEdit = %Search
@onready var catalog_list: ItemList = %Catalog
@onready var quantity: SpinBox = %Quantity
@onready var indicator: Button = %Indicator
@onready var scope: OptionButton = %Scope
@onready var enemies: ItemList = %Enemies
@onready var enemy_search: LineEdit = %EnemySearch
var entries: Array[Dictionary] = []
var enemy_entries: Array[Dictionary] = []
var _was_open: bool = false
var _last_lock: String = ""

func _ready() -> void:
	host.changed.connect(_sync)
	%Hint.pressed.connect(_toggle)
	indicator.pressed.connect(_toggle)
	%Close.pressed.connect(host.close)
	search.text_changed.connect(func(_text: String) -> void: _filter_catalog())
	scope.item_selected.connect(func(_index: int) -> void: _filter_catalog())
	catalog_list.item_selected.connect(func(_index: int) -> void:
		_selection_changed()
		_sync())
	enemy_search.text_changed.connect(func(_text: String) -> void: _filter_enemies())
	quantity.value_changed.connect(func(_value: float) -> void: _sync())
	%Floor.value_changed.connect(func(_value: float) -> void: _sync())
	%RoomKind.item_selected.connect(func(_index: int) -> void: _sync())
	%Owned.item_selected.connect(func(_index: int) -> void: _sync())
	enemies.item_selected.connect(func(_index: int) -> void: _sync())
	%Grant.pressed.connect(_grant_selected)
	%AutoPlace.pressed.connect(func() -> void: _grant_selected(true))
	%RemoveRelic.pressed.connect(func() -> void: _send_selected("remove_relic"))
	%RemoveItem.pressed.connect(func() -> void:
		if %Owned.selected >= 0: host.submit("remove_item", {"id": %Owned.get_item_id(%Owned.selected)}))
	for stat: String in PLAYER_STATS:
		get_node("%Value_" + stat).value_changed.connect(func(_value: float) -> void: _sync())
		get_node("%Apply_" + stat).pressed.connect(func() -> void: host.submit("set_player", {"stat": stat, "value": int(get_node("%Value_" + stat).value)}))
	for stat: String in ENEMY_STATS:
		get_node("%EnemyValue_" + stat).value_changed.connect(func(_value: float) -> void: _sync())
		get_node("%EnemyApply_" + stat).pressed.connect(func() -> void: host.submit("set_enemy", {"stat": stat, "value": int(get_node("%EnemyValue_" + stat).value)}))
	%Heal.pressed.connect(func() -> void: host.submit("restore_health"))
	%Refill.pressed.connect(func() -> void: host.submit("refill_resources"))
	%Cleanse.pressed.connect(func() -> void: host.submit("clear_player_conditions"))
	%ResetBudgets.pressed.connect(func() -> void: host.submit("clear_resource_budgets"))
	for key: String in SESSION.FLAGS:
		get_node("%Cheat_" + key).toggled.connect(func(value: bool) -> void:
			if not host.lock_reason().is_empty(): return
			host.session.set_cheat(key, value)
			host.last_message = "Session cheat updated; applies to the next uncommitted action."
			host.game._refresh()
			host.changed.emit())
	%DisableCheats.pressed.connect(func() -> void:
		host.session.clear_cheats()
		host.last_message = "All session cheats disabled."
		host.game._refresh()
		host.changed.emit())
	%Prepare.pressed.connect(func() -> void:
		var selected: PackedInt32Array = enemies.get_selected_items()
		if not selected.is_empty(): host.submit("prepare_enemy", {"key": enemies.get_item_metadata(selected[0])}))
	%Restart.pressed.connect(func() -> void: host.submit("restart_encounter"))
	%Defeat.pressed.connect(func() -> void: host.submit("defeat_enemy"))
	%ToggleCombat.pressed.connect(host.toggle_combat)
	%Step.pressed.connect(host.step_round)
	%TurnBased.toggled.connect(host.set_turn_based)
	%Travel.pressed.connect(func() -> void: host.submit("travel", {"floor": int(%Floor.value), "kind": ROOM_KINDS[%RoomKind.selected]}))
	%Entrance.pressed.connect(func() -> void: host.submit("entrance"))
	%FinishApply.pressed.connect(host.finish_exchange_and_apply)
	%CancelPending.pressed.connect(host.cancel_pending)
	for button: BaseButton in $Overlay.find_children("*", "BaseButton", true, false):
		button.set_meta("dev_tooltip", button.tooltip_text)
	_sync()

func bind(game: Control) -> void:
	if SESSION.enabled():
		host.bind(game)
		entries = host.commands.catalog("items")
		enemy_entries = host.commands.catalog("enemies")
		_filter_catalog()
		_filter_enemies()
	_sync()

func handle_input(event: InputEvent) -> bool:
	if not SESSION.enabled(): return false
	if KEYS.matches(event, "dev_menu"):
		_toggle()
		return true
	if host.is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		host.close()
		return true
	return false

func reset() -> void:
	host.reset()
	_sync()

func _toggle() -> void:
	if host.is_open: host.close()
	elif host.open():
		_sync_values()
		search.grab_focus()

func _process(_delta: float) -> void:
	if host.game == null: return
	var in_run: bool = host.game.combat.visible and not host.game.front.visible
	%Hint.text = "DEV TOOLS · " + KEYS.label(host.game.front.keybindings.get("dev_menu", KEY_F8))
	%Hint.visible = in_run and not host.is_open and SESSION.enabled()
	indicator.visible = in_run and not host.is_open and not host.session.active_labels().is_empty()
	if host.is_open:
		if host.lock_reason() != _last_lock: _sync()
		_update_context()
		_update_current_values()

func _sync() -> void:
	$Overlay.visible = host.is_open
	%Hint.visible = host.game != null and host.game.combat.visible and not host.is_open and SESSION.enabled()
	var labels: PackedStringArray = host.session.active_labels()
	indicator.text = "DEV: " + " · ".join(labels)
	indicator.tooltip_text = "Active session cheats: " + ", ".join(labels)
	var indicator_width: float = indicator.get_theme_font("font").get_string_size(indicator.text, HORIZONTAL_ALIGNMENT_LEFT, -1, indicator.get_theme_font_size("font_size")).x + 40.0
	indicator.offset_left = -minf(indicator_width + 16.0, get_viewport().get_visible_rect().size.x - 16.0)
	indicator.visible = host.game != null and host.game.combat.visible and not host.is_open and not labels.is_empty()
	if host.game == null: return
	if host.is_open and not _was_open:
		_was_open = true
		_sync_values()
		_filter_catalog()
		search.call_deferred("grab_focus")
	_was_open = host.is_open
	_update_context()
	_update_current_values()
	%Result.text = host.last_message
	%PendingLabel.text = "%d pending edit(s)" % host.pending.size()
	%PendingLabel.get_parent().visible = not host.pending.is_empty() or host.stepping
	var lock: String = host.lock_reason()
	_last_lock = lock
	for button: BaseButton in $Overlay.find_children("*", "BaseButton", true, false):
		button.disabled = not lock.is_empty()
		button.tooltip_text = lock if not lock.is_empty() else str(button.get_meta("dev_tooltip", ""))
	%FinishApply.disabled = host.stepping
	%CancelPending.disabled = host.stepping
	%Close.disabled = host.stepping
	for key: String in SESSION.FLAGS:
		get_node("%Cheat_" + key).set_pressed_no_signal(bool(host.session.flags.get(key, false)))
	%TurnBased.set_pressed_no_signal(host.game.playback.turn_based)
	%Grant.text = "Give to stash" if scope.selected == 0 else "Add relic"
	%AutoPlace.visible = scope.selected == 0
	%RemoveRelic.visible = scope.selected == 1
	%ToggleCombat.text = "Start combat" if not host.game.playback.active else ("Keep paused on close" if host.resumes_on_close() else "Resume on close")
	_fit_buttons()
	var owned: OptionButton = %Owned
	var selected_id: int = owned.get_item_id(owned.selected) if owned.selected >= 0 else -1
	owned.clear()
	for item: Dictionary in host.game.run.items:
		owned.add_item("%s #%d%s" % [item.name, item.id, " (permanent)" if host.game.run.is_permanent(item) else ""], int(item.id))
		if item.id == selected_id: owned.select(owned.item_count - 1)
	_sync_action_locks()

func _sync_action_locks() -> void:
	var selected: PackedInt32Array = catalog_list.get_selected_items()
	var key: String = str(catalog_list.get_item_metadata(selected[0])) if not selected.is_empty() else ""
	var grant_command: String = "add_relic" if scope.selected == 1 else ("quiver_upgrade" if PackRun.QUIVER.OPTIONS.has(key) else "grant_item")
	var args: Dictionary = {"key": key, "quantity": int(quantity.value)}
	_command_lock(%Grant, grant_command, args)
	_command_lock(%AutoPlace, grant_command, args)
	_command_lock(%RemoveRelic, "remove_relic", {"key": key})
	_command_lock(%RemoveItem, "remove_item", {"id": %Owned.get_item_id(%Owned.selected) if %Owned.selected >= 0 else -1})
	selected = enemies.get_selected_items()
	key = str(enemies.get_item_metadata(selected[0])) if not selected.is_empty() else ""
	_command_lock(%Prepare, "prepare_enemy", {"key": key})
	_command_lock(%Restart, "restart_encounter")
	_command_lock(%Defeat, "defeat_enemy")
	_command_lock(%Travel, "travel", {"floor": int(%Floor.value), "kind": ROOM_KINDS[%RoomKind.selected]})
	if host.game.run.phase != PackRun.Phase.FIGHT or host.game.waiting_at_entrance:
		for button: Button in [%Step, %ToggleCombat]:
			button.disabled = true
			button.tooltip_text = "Prepare a combat encounter first."
	for stat: String in PLAYER_STATS:
		_command_lock(get_node("%Apply_" + stat), "set_player", {"stat": stat, "value": int(get_node("%Value_" + stat).value)})
	for stat: String in ENEMY_STATS:
		_command_lock(get_node("%EnemyApply_" + stat), "set_enemy", {"stat": stat, "value": int(get_node("%EnemyValue_" + stat).value)})

func _command_lock(button: BaseButton, command: String, args: Dictionary = {}) -> void:
	var reason: String = host.lock_reason()
	if reason.is_empty(): reason = host.commands.validate(host.game.run, command, args)
	button.disabled = not reason.is_empty()
	button.tooltip_text = reason if not reason.is_empty() else str(button.get_meta("dev_tooltip", ""))

func _fit_buttons() -> void:
	for button: Button in $Overlay.find_children("*", "Button", true, false):
		if button.get_script() == preload("res://components/ui/buttons/pixel_button/pixel_button.gd"):
			var font: Font = button.get_theme_font("font")
			var font_size: int = button.get_theme_font_size("font_size")
			button.custom_minimum_size.x = maxf(100.0, font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 40.0)

func _update_context() -> void:
	var game: Control = host.game
	var checkpoint: String = "enemy response pending" if not game.run.pending_turn.is_empty() else ("round boundary" if game.playback.waiting_for_round else "preparation / feedback")
	%Context.text = "Floor %02d / %s / %s / %s / %s" % [game.run.display_floor(), str(PackRun.Phase.keys()[game.run.phase]).capitalize(), game.run.room_kind.capitalize(), game.run.enemy.get("name", "No enemy"), checkpoint]

func _update_current_values() -> void:
	var run: PackRun = host.game.run
	for stat: String in PLAYER_STATS:
		var capacity: String = " / %d" % run.get(stat + "_capacity") if stat in ["mana", "stamina", "block"] else (" / %d" % run.max_hp if stat == "hp" else "")
		get_node("%Now_" + stat).text = "Now: %d%s" % [run.get(stat), capacity]
	for stat: String in ENEMY_STATS:
		get_node("%EnemyNow_" + stat).text = "Now: %d" % (run.enemy.get("hp", 0) if stat == "hp" else run.get(stat))

func _sync_values() -> void:
	if host.game == null: return
	for stat: String in PLAYER_STATS: get_node("%Value_" + stat).set_value_no_signal(host.game.run.get(stat))
	for stat: String in ENEMY_STATS: get_node("%EnemyValue_" + stat).set_value_no_signal(host.game.run.enemy.get("hp", 0) if stat == "hp" else host.game.run.get(stat))
	%Floor.set_value_no_signal(host.game.run.display_floor())

func _filter_catalog() -> void:
	if host.game == null: return
	entries = host.commands.catalog("items" if scope.selected == 0 else "relics")
	var query: String = search.text.strip_edges().to_lower()
	catalog_list.clear()
	for entry: Dictionary in entries:
		if not query.is_empty() and not (str(entry.name) + " " + str(entry.key)).to_lower().contains(query): continue
		var unavailable: bool = not host.game.run.item_enabled(entry)
		catalog_list.add_item("%s  /  %s%s" % [entry.name, entry.key, " (class restricted)" if unavailable else ""])
		catalog_list.set_item_metadata(catalog_list.item_count - 1, entry.key)
	if catalog_list.item_count > 0: catalog_list.select(0)
	_selection_changed()
	_sync()

func _selection_changed() -> void:
	var selected: PackedInt32Array = catalog_list.get_selected_items()
	if selected.is_empty():
		%Selection.text = "No matching content."
		return
	var key: String = str(catalog_list.get_item_metadata(selected[0]))
	for entry: Dictionary in entries:
		if str(entry.key) == key:
			%Selection.text = str(entry.get("detail", "")) + ("  Quiver option." if PackRun.QUIVER.OPTIONS.has(key) else "")
			return

func _filter_enemies() -> void:
	var query: String = enemy_search.text.strip_edges().to_lower()
	enemies.clear()
	for entry: Dictionary in enemy_entries:
		if not query.is_empty() and not (str(entry.name) + " " + str(entry.key)).to_lower().contains(query): continue
		enemies.add_item("%s  /  %s" % [entry.name, entry.key])
		enemies.set_item_metadata(enemies.item_count - 1, entry.key)
	if enemies.item_count > 0: enemies.select(0)

func _send_selected(command: String, extra: Dictionary = {}) -> void:
	var selected: PackedInt32Array = catalog_list.get_selected_items()
	if selected.is_empty(): return
	var args: Dictionary = extra.duplicate()
	args["key"] = catalog_list.get_item_metadata(selected[0])
	host.submit(command, args)

func _grant_selected(auto_place: bool = false) -> void:
	var selected: PackedInt32Array = catalog_list.get_selected_items()
	if selected.is_empty(): return
	var key: String = str(catalog_list.get_item_metadata(selected[0]))
	var command: String = "add_relic" if scope.selected == 1 else ("quiver_upgrade" if PackRun.QUIVER.OPTIONS.has(key) else "grant_item")
	_send_selected(command, {"quantity": int(quantity.value), "auto_place": auto_place})
