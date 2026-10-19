class_name PackCombatPlayback
extends Node

signal player_resolved(result: Dictionary)
signal monster_resolved(result: Dictionary)
signal fight_finished()
signal pause_changed(value: bool)

var active: bool = false
var paused: bool = false
var remaining_seconds: float = 0.0
var _state: PackRun
var _speed: float = 1.0
var _impact: float = 0.18
var _strike: float = 0.18
var _death: float = 0.0
var _player_delay: float = 1.5
var _enemy_delay: float = 1.5
var _response_wait: bool = false
var _crafting_wait: bool = false
var _result: Dictionary = {}

func start(state: PackRun, speed: float, impact_seconds: float, strike_seconds: float, death_seconds: float = 0.0, player_delay: float = 1.5, enemy_delay: float = 1.5) -> bool:
	if active or not state.start_combat():
		return false
	_state = state
	_speed = clampf(speed, 0.5, 10.0)
	_player_delay = snappedf(clampf(player_delay, 0.2, 2.5), 0.1)
	_enemy_delay = snappedf(clampf(enemy_delay, 0.2, 2.5), 0.1)
	_impact = maxf(0.0, impact_seconds)
	_strike = maxf(0.0, strike_seconds)
	_death = maxf(0.0, death_seconds)
	active = true
	paused = false
	_crafting_wait = not state.crafting_events.is_empty()
	if _crafting_wait:
		remaining_seconds = PackRun.CRAFTING.ANIMATION_SECONDS
	else:
		_begin_player()
	return true

func _begin_player() -> void:
	_result = _state.begin_turn()
	if _result.is_empty():
		_finish()
		return
	_response_wait = true
	remaining_seconds = (_enemy_delay if _result["has_response"] else _impact + _death) / _speed
	player_resolved.emit(_result)

func _process(delta: float) -> void:
	if not active or paused:
		return
	remaining_seconds = maxf(0.0, remaining_seconds - delta)
	if remaining_seconds > 0.0:
		return
	if _crafting_wait:
		_crafting_wait = false
		_begin_player()
		return
	if _response_wait:
		var strikes: bool = _result["has_response"] and _state.attack() > 0 and int(_state.enemy["hits"]) > 0 and not _result.get("invisible", false)
		var result: Dictionary = _state.complete_turn()
		result["playback_strikes"] = strikes
		_response_wait = false
		remaining_seconds = _strike / _speed if strikes else 0.0
		if int(result.get("retaliation", 0)) > 0:
			# Retaliation lands after the approach; allow its reaction/death to finish.
			remaining_seconds += (_impact + (_death if _state.enemy["hp"] <= 0 else 0.0)) / _speed
		if _state.combat_state != PackRun.CombatState.FINISHED:
			remaining_seconds = _player_delay / _speed
		if result.get("has_response", false):
			monster_resolved.emit(result)
		# A separate frame always separates checkpoints, even harmless exchanges.
	else:
		if _state.combat_state == PackRun.CombatState.FINISHED:
			_finish()
		else:
			_begin_player()

func set_paused(value: bool) -> void:
	if not active or paused == value:
		return
	paused = value
	_state.set_combat_paused(value)
	pause_changed.emit(value)

func cancel() -> void:
	_crafting_wait = false
	active = false
	paused = false
	remaining_seconds = 0.0
	_result = {}
	_state = null

func snapshot() -> Dictionary:
	return {"active": active, "paused": paused, "remaining": remaining_seconds, "response_wait": _response_wait, "crafting_wait": _crafting_wait, "result": _result.duplicate(true), "speed": _speed, "impact": _impact, "strike": _strike, "death": _death, "player_delay": _player_delay, "enemy_delay": _enemy_delay}

func restore(state: PackRun, data: Dictionary) -> void:
	cancel()
	if not data.get("active", false):
		return
	_state = state
	active = true
	paused = true
	remaining_seconds = data.get("remaining", 0.0)
	_crafting_wait = data.get("crafting_wait", false)
	_response_wait = data.get("response_wait", false)
	_result = data.get("result", {}).duplicate(true)
	_speed = data.get("speed", 1.0)
	_impact = data.get("impact", 0.18)
	_strike = data.get("strike", 0.18)
	_death = data.get("death", 0.0)
	_player_delay = data.get("player_delay", 1.5)
	_enemy_delay = data.get("enemy_delay", 1.5)
	_state.set_combat_paused(true)
	pause_changed.emit(true)

func _finish() -> void:
	cancel()
	fight_finished.emit()
