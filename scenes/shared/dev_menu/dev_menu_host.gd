extends Node
## Coordinates state commands with the application's existing playback, world, and save owners.
signal changed
const SESSION = preload("res://systems/development/dev_session.gd")
const COMMANDS = preload("res://systems/development/dev_commands.gd")
var session = SESSION.new()
var commands = COMMANDS.new()
var game: Control
var is_open: bool = false
var stepping: bool = false
var pending: Array[Dictionary] = []
var last_message: String = "Changes affect the current saved run."
var _resume_on_close: bool = false
var _previous_turn_based: bool = false
var _board_input: bool = true
var _storage_input: bool = true

func bind(application: Control) -> void:
	game = application
	session.attach(game.run)
	game.playback.round_boundary.connect(_on_boundary)
	game.playback.fight_finished.connect(_on_fight_finished)

func unbind() -> void:
	if game != null and is_instance_valid(game):
		if game.playback.round_boundary.is_connected(_on_boundary): game.playback.round_boundary.disconnect(_on_boundary)
		if game.playback.fight_finished.is_connected(_on_fight_finished): game.playback.fight_finished.disconnect(_on_fight_finished)
	session.detach()
	game = null

func _exit_tree() -> void:
	unbind()

func reset() -> void:
	if game != null and is_open:
		game.board.set_process_input(_board_input)
		game.storage.set_process_input(_storage_input)
	is_open = false
	stepping = false
	pending.clear()
	_resume_on_close = false
	session.clear_cheats()
	changed.emit()

func lock_reason() -> String:
	if game == null or not SESSION.enabled(): return "Developer tools are unavailable."
	if game.loading_screen.active or game.gameplay_background.transitioning or (game.busy and not game.playback.active): return "Wait for the room transition to finish."
	if not game.combat.visible or game.front.visible: return "Start or resume a run first."
	if stepping: return "Finishing the current exchange…"
	return ""

func open() -> bool:
	var reason: String = lock_reason()
	if not reason.is_empty():
		last_message = reason
		return false
	if is_open: return true
	_board_input = game.board.is_processing_input()
	_storage_input = game.storage.is_processing_input()
	game.board.set_process_input(false)
	game.storage.set_process_input(false)
	game.board.cancel_drag()
	game._close_storage()
	game.inspector.clear()
	_resume_on_close = game.playback.active and not game.playback.paused
	_previous_turn_based = game.playback.turn_based
	game.playback.set_paused(true)
	is_open = true
	changed.emit()
	return true

func close() -> void:
	if stepping: return
	if not pending.is_empty():
		pending.clear()
		last_message = "Unapplied edits cancelled when the panel closed."
	is_open = false
	if game != null:
		game.board.set_process_input(_board_input)
		game.storage.set_process_input(_storage_input)
	if game != null and game.playback.active:
		game.playback.turn_based = _previous_turn_based
		if _resume_on_close: game.playback.set_paused(false)
	changed.emit()

func submit(command: String, args: Dictionary = {}) -> Dictionary:
	var reason: String = lock_reason()
	if not is_open: reason = "Open the developer panel first."
	if not reason.is_empty(): return _reject(reason)
	var error: String = commands.validate(game.run, command, args)
	if not error.is_empty(): return _reject(error)
	var replacement: bool = command in COMMANDS.REPLACEMENTS or (command == "set_enemy" and str(args.get("stat", "")) == "hp" and int(args.get("value", -1)) == 0)
	if replacement:
		pending.clear()
		game._cancel_combat()
		game.run.pending_turn.clear()
		if game.run.combat_state == PackRun.CombatState.RUNNING: game.run.combat_state = PackRun.CombatState.PAUSED
		_resume_on_close = false
	elif game.playback.active and not game.playback.waiting_for_round:
		pending.append({"command": command, "args": args.duplicate(true)})
		last_message = "Queued for the next round boundary. Finish exchange and apply, or cancel."
		changed.emit()
		return {"ok": true, "message": last_message, "queued": true, "saved": false}
	return _apply(command, args)

func cancel_pending() -> void:
	pending.clear()
	last_message = "Pending edits cancelled."
	changed.emit()

func finish_exchange_and_apply() -> bool:
	if not is_open or stepping or not lock_reason().is_empty(): return false
	if not game.playback.active:
		_apply_pending()
		return true
	if game.playback.waiting_for_round:
		_apply_pending()
		return true
	stepping = true
	game.playback.set_paused(false)
	changed.emit()
	return true

func step_round() -> bool:
	if not is_open or stepping or not lock_reason().is_empty(): return false
	if game.waiting_at_entrance or game.run.phase != PackRun.Phase.FIGHT:
		last_message = "Prepare a combat encounter before stepping."
		changed.emit()
		return false
	stepping = true
	if game.playback.active:
		game.playback.set_paused(false)
		if game.playback.waiting_for_round: game.playback.advance_round()
	else:
		game.modal.hide()
		game.modal_kind = ""
		game._act()
		if not game.playback.active:
			stepping = false
			last_message = "Combat could not start. Check required class equipment and arrows."
	changed.emit()
	return stepping

func resumes_on_close() -> bool:
	return _resume_on_close

func toggle_combat() -> void:
	if not lock_reason().is_empty(): return
	if game.playback.active:
		_resume_on_close = not _resume_on_close
		last_message = "Combat will %s when the panel closes." % ("resume" if _resume_on_close else "stay paused")
	else:
		if game.run.phase != PackRun.Phase.FIGHT or game.waiting_at_entrance: return
		game.modal.hide()
		game.modal_kind = ""
		game._act()
		game.playback.set_paused(true)
		_resume_on_close = game.playback.active
		last_message = "Combat started and paused; close the panel to resume."
	changed.emit()

func set_turn_based(value: bool) -> void:
	_previous_turn_based = value
	if game != null: game.playback.turn_based = value
	changed.emit()

func _on_boundary() -> void:
	if not stepping: return
	if game.playback.active:
		game.playback.waiting_for_round = true
		game.playback.set_paused(true)
	stepping = false
	_apply_pending()
	if pending.is_empty():
		_save()
	changed.emit()

func _on_fight_finished() -> void:
	if not stepping: return
	stepping = false
	_resume_on_close = false
	_apply_pending()
	_save()
	changed.emit()

func _apply_pending() -> void:
	var queue: Array[Dictionary] = pending.duplicate(true)
	pending.clear()
	for entry: Dictionary in queue:
		_apply(entry.command, entry.args)
	changed.emit()

func _apply(command: String, args: Dictionary) -> Dictionary:
	var result: Dictionary = commands.apply(game.run, command, args)
	if not result.ok: return _reject(result.message)
	if result.world_changed:
		game.modal.hide()
		game.modal_kind = ""
		game.waiting_at_entrance = command == "entrance"
		game.gameplay_background.reset(game.run.display_floor())
		if game.waiting_at_entrance: game.gameplay_background.prepare_entrance()
		else: game.gameplay_background.world.set_room(game.gameplay_background.scene_for_state(game.run))
		game._configure_floor_scene()
	game._refresh()
	game.storage.refresh()
	if command == "defeat_enemy" or (command == "set_enemy" and str(args.get("stat", "")) == "hp" and int(args.get("value", -1)) == 0):
		game._show_phase_modal()
	result["saved"] = _save()
	last_message = result.message + (" Saved." if result.saved else " Save failed: " + error_string(game.run_saves.last_error))
	changed.emit()
	return result

func _save() -> bool:
	var saved: bool = game._save_run(false)
	if not saved: last_message = "Save failed: " + error_string(game.run_saves.last_error)
	return saved

func _reject(message: String) -> Dictionary:
	last_message = message
	changed.emit()
	return {"ok": false, "message": message, "saved": false}
