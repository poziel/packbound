extends "res://tests/support/prototype_support.gd"

func encounter() -> PackRun:
	var state: PackRun = fixture("ranger")
	state.items.clear()
	state.max_hp = 100
	state.hp = 100
	state.enemy["name"] = "Test foe"
	state.enemy["hp"] = 100
	state.enemy["max_hp"] = 100
	state.enemy["attacks"] = [0]
	return state

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: printerr("Combat log test timed out"); quit(2))
	_echo_aggregate_checks()
	_shield_checks()
	_event_checks()
	_status_checks()
	_recovery_checks()
	await _ui_checks()
	report("COMBAT LOG RESULT")
	quit(1 if failures else 0)

func _shield_checks() -> void:
	var state: PackRun = encounter()
	state.enemy["armor"] = 8
	var blade: Dictionary = state.add_item("rusty_knife", Vector2i.ZERO)
	blade[GameplayTypes.Stat.DAMAGE] = 3
	var history_before: Array = state.history.duplicate()
	var preview: Dictionary = state.outcome(state.effects())
	check(preview == state.outcome(state.effects()) and state.shield() == 8 and state.history == history_before, "Previews leave shield and logs unchanged")
	var result: Dictionary = state.end_turn()
	check(result == preview, "Committed events and damage match the preview")
	check(state.shield() == 5 and state.enemy["hp"] == 100, "Partial hit depletes shield without damaging health")
	check(result["player_events"] == ["Test foe's shield blocked 3 damage."], "Fully absorbed damage has no zero-health damage event")
	check(result["monster_events"].is_empty(), "A harmless response produces no empty monster turn")
	blade[GameplayTypes.Stat.DAMAGE] = 7
	result = state.end_turn()
	check(state.shield() == 0 and state.enemy["hp"] == 98, "Second hit breaks the remaining shield and overflows to health")
	check(result["player_events"] == ["Test foe's shield blocked 5 damage.", "I broke Test foe's shield.", "I dealt 2 damage to Test foe."], "Shield absorption, break and overflow are separate ordered events")
	result = state.end_turn()
	check(state.enemy["hp"] == 91 and result["player_events"] == ["I dealt 7 damage to Test foe."], "Broken shield stays depleted and is not reported broken again")
	state.prepare_enemy()
	check(state.enemy_shield_spent == 0, "A new encounter resets spent shield")
	state = encounter()
	state.enemy["armor"] = 8
	var stats: Dictionary = state.effects()
	stats.merge({GameplayTypes.Stat.DAMAGE: 5, GameplayTypes.Stat.PIERCE: 2, GameplayTypes.Stat.POISON: 3, GameplayTypes.Stat.BURN: 2}, true)
	result = state.outcome(stats)
	check(result["shield_absorbed"] == 3 and result["enemy_shield_after"] == 5 and result["enemy_hp_after"] == 93, "Piercing and elemental damage bypass shield without consuming it")
	check(result["player_events"].has("I applied 3 poison to Test foe.") and result["player_events"].has("I applied 2 burn to Test foe."), "Both elemental applications are reported")
	state = encounter()
	state.enemy["cycle_armor"] = 8
	state.add_item("rusty_knife", Vector2i.ZERO)[GameplayTypes.Stat.DAMAGE] = 3
	result = state.end_turn()
	check(state.shield() == 0 and result["monster_events"].has("Test foe lost 5 temporary shield."), "Timed guard expires without a false break event")
	result = state.end_turn()
	check(state.shield() == 8 and result["monster_events"].has("Test foe restored 8 shield."), "Timed guard restores its shield for the next guarded turn")
	state = encounter()
	state.enemy["opening_armor"] = 7
	state.add_item("rusty_knife", Vector2i.ZERO)[GameplayTypes.Stat.DAMAGE] = 2
	state.end_turn()
	check(state.shield() == 5, "Opening shield persists partially depleted into turn two")
	result = state.end_turn()
	check(state.shield() == 0 and result["monster_events"].has("Test foe lost 3 temporary shield."), "Opening shield expires after its second turn")
	state = encounter()
	state.enemy["parry"] = 8
	state.turn = 2
	result = state.end_turn()
	check(state.shield() == 8 and result["monster_events"] == ["Test foe restored 8 shield."], "Parry explicitly restores shield before every third turn")

func _event_checks() -> void:
	var state: PackRun = encounter()
	state.enemy["attacks"] = [5]
	state.add_item("rusty_knife", Vector2i.ZERO)[GameplayTypes.Stat.DAMAGE] = 7
	state.end_turn()
	var lines: Array = state.history
	check(lines.find("I dealt 7 damage to Test foe.") < lines.find("Test foe dealt 5 damage to me.") and not "\n".join(lines).contains("Turn 1"), "Player and monster events stay in order without turn headings")
	check(state.stage_history[0]["lines"] == lines, "Individual events remain in the correct stage history")
	var stats: Dictionary = state.effects()
	stats[GameplayTypes.Stat.BLOCK] = 5
	var result: Dictionary = state.outcome(stats)
	check(result["monster_events"] == ["My shield blocked 5 damage.", "Test foe broke my shield."], "Fully blocked hit logs a real shield break and no zero damage")
	state.enemy["hits"] = 3
	result = state.outcome(stats)
	check(result["monster_events"].count("Test foe broke my shield.") == 1 and result["monster_events"].count("Test foe dealt 5 damage to me.") == 2, "Multiple strikes use one shield pool and report each damaging hit")
	state.enemy["sunder"] = 5
	result = state.outcome(stats)
	check(result["monster_events"][0] == "Test foe destroyed 5 of my shield." and result["monster_events"].count("Test foe broke my shield.") == 1, "Sunder reports destruction and exactly one break")
	state = encounter()
	state.enemy["attacks"] = [10]
	state.enemy["hp"] = 3
	stats = state.effects()
	stats[GameplayTypes.Stat.DAMAGE] = 20
	result = state.outcome(stats)
	check(result["player_events"] == ["I dealt 3 damage to Test foe."] and result["monster_events"].is_empty(), "Lethal hit reports actual HP lost and prevents a monster action")
	stats[GameplayTypes.Stat.DAMAGE] = 0
	stats[GameplayTypes.Stat.POISON] = 5
	stats[GameplayTypes.Stat.BURN] = 2
	result = state.outcome(stats)
	check(result["player_events"].has("Poison dealt 3 damage to Test foe.") and not "\n".join(result["player_events"]).contains("Burn dealt") and result["monster_events"].is_empty(), "Lethal poison prevents later damage and the monster response")
	stats = state.effects()
	stats[GameplayTypes.Stat.THORNS] = 10
	state.enemy["hits"] = 3
	result = state.outcome(stats)
	check(result["monster_events"] == ["Test foe dealt 10 damage to me.", "My thorns dealt 3 damage to Test foe."], "Lethal retaliation stops the remaining strikes")
	state = encounter()
	state.hp = 2
	state.enemy["attacks"] = [10]
	result = state.end_turn()
	check(result["monster_events"] == ["Test foe dealt 2 damage to me."] and state.history.back() == "I was defeated.", "Lethal incoming damage is capped to HP and defeat is recorded")

func _status_checks() -> void:
	var state: PackRun = encounter()
	state.enemy["attacks"] = [4]
	state.enemy[GameplayTypes.Stat.POISON] = 2
	var result: Dictionary = state.end_turn()
	check(result["monster_events"] == ["Test foe dealt 4 damage to me.", "Test foe applied 2 poison to me."], "Monster poison is logged when applied")
	check(state.player_poison == 2 and result["player_events"].is_empty(), "New poison does not tick before it is applied")
	result = state.end_turn()
	check(result["player_events"] == ["Poison dealt 2 damage to me."] and state.player_poison == 3, "Existing poison ticks before the next response and decays")
	state = encounter()
	state.enemy["attacks"] = [5]
	state.enemy[GameplayTypes.Stat.POISON] = 2
	var stats: Dictionary = state.effects()
	stats[GameplayTypes.Stat.BLOCK] = 8
	result = state.outcome(stats)
	check(result["poison_after"] == 0 and not "\n".join(result["monster_events"]).contains("poison"), "Fully blocked attacks do not invent elemental applications")
	state.player_poison = 5
	stats.merge({GameplayTypes.Stat.CLEANSE: 2, GameplayTypes.Stat.WARD: 2}, true)
	result = state.outcome(stats)
	check(result["player_events"].has("I cleansed 2 poison.") and result["player_events"].has("My ward blocked 2 damage from poison.") and result["player_events"].has("Poison dealt 1 damage to me."), "Cleanse and ward report only their actual effects")
	state = encounter()
	state.hp = 99
	stats = state.effects()
	stats[GameplayTypes.Stat.HEALING] = 10
	result = state.outcome(stats)
	check(result["player_events"] == ["I healed 1 HP."], "Healing reports only HP actually restored")
	state.hp = 100
	result = state.outcome(stats)
	check(result["player_events"].is_empty(), "Healing at full HP does not create an event")
	state.enemy["regen"] = 8
	state.enemy["hp"] = 99
	result = state.outcome(stats)
	check(result["monster_events"] == ["Test foe regenerated 1 HP."], "Enemy regeneration also reports actual healing")
	state.enemy["hp"] = 100
	result = state.outcome(stats)
	check(result["monster_events"].is_empty(), "Enemy regeneration at full HP stays silent")
	state = encounter()
	state.enemy["reflect"] = 2
	stats = state.effects()
	stats.merge({GameplayTypes.Stat.DAMAGE: 4, GameplayTypes.Stat.CURSE: 3, "blood_cost": 1}, true)
	result = state.outcome(stats)
	check(result["player_events"].has("Curse dealt 3 damage to me.") and result["player_events"].has("Test foe's reflection dealt 2 damage to me.") and result["player_events"].has("Arcane Barter cost me 1 HP."), "Special damage identifies each source instead of a combined HP cost")
	state = encounter()
	state.class_key = "mage"
	state.mana = 12
	state.add_item("ember_tome", Vector2i.ZERO)
	result = state.end_turn()
	check(not "\n".join(result["player_events"]).contains("gained") and result["player_events"].has("I spent 3 mana on spells."), "Mana capped at twelve logs actual spell spending but no zero gain")
	state = encounter()
	state.relics = ["last_thread"]
	state.hp = 1
	state.enemy["attacks"] = [10]
	state.end_turn()
	check(state.history.has("Last Thread saved me with 8 HP.") and not "\n".join(state.history).contains("unpacked"), "Revival without packed items does not claim an unpacking event")

func _recovery_checks() -> void:
	for starting_hp: int in [100, 98]:
		var state: PackRun = encounter()
		state.hp = starting_hp
		state.enemy["hp"] = 1
		state.add_item("rusty_knife", Vector2i.ZERO)
		state.end_turn()
		state.advance_encounter()
		state.choose_loot(state.offers[0])
		check(not state.history.has("I recovered 0 HP between stages."), "Zero between-stage recovery is omitted")
		check(state.hp == starting_hp and not "\n".join(state.stage_history[0]["lines"]).contains("recovered"), "Floor entry neither heals nor invents recovery logs")

func _ui_checks() -> void:
	render = DisplayServer.get_name() != "headless"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	game.start_run("ranger", 42)
	game.run = encounter()
	game.run.fight = 5
	game.run.prepare_enemy()
	game.run.enemy["armor"] = 8
	game.run.add_item("rusty_knife", Vector2i.ZERO)[GameplayTypes.Stat.DAMAGE] = 3
	game.run.add_item("cracked_shield", Vector2i(2, 0))[GameplayTypes.Stat.BLOCK] = 2
	game.modal.hide()
	game.run.end_turn()
	game._refresh()
	await process_frame
	check(game.enemy_shield_bar.visible and game.enemy_shield_bar.value == 5 and game.enemy_shield_bar.max_value == 8, "Enemy bar shows remaining shield against original capacity")
	game.character_tabs.current_tab = _tab_index("Logs")
	game._refresh()
	await process_frame
	check(game.stage_monster.text == "Mire Viper" and game.stage_number.text == "Stage 06", "Existing footer keeps monster name left and stage number between arrows")
	var log_spacing := RegEx.new()
	log_spacing.compile(" +")
	var log_text: String = log_spacing.sub(game.history_view.get_parsed_text().replace(char(0x2060), "").replace(char(0xA0), " "), " ", true)
	check(log_text.contains("Mire Viper applied 2 poison to me.") and not log_text.contains("0 damage"), "Logs render elemental applications without zero damage summaries")
	if render:
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("combat-events-log.png"))
	game.run.items[0][GameplayTypes.Stat.DAMAGE] = 7
	game.run.end_turn()
	game._refresh()
	await process_frame
	check(not game.enemy_shield_bar.visible and game.history_view.get_parsed_text().contains("I broke Mire Viper's shield."), "Broken shield hides immediately and its event is visible")
	viewport.queue_free()
	await process_frame
	# Audio playback releases its background resources after the scene is freed.
	await create_timer(0.1).timeout

func _echo_aggregate_checks() -> void:
	var state: PackRun = encounter()
	state.turn = 3
	state.relics.assign(["echo_clock"])
	state.hp = 50
	state.enemy["armor"] = 15
	state.enemy["hp"] = 3
	var blade: Dictionary = state.add_item("rusty_knife", Vector2i.ZERO)
	blade.merge({GameplayTypes.Stat.DAMAGE: 10, GameplayTypes.Stat.VAMPIRISM: 9}, true)
	var result: Dictionary = state.outcome(state.effects())
	check(result["shield_absorbed"] == 15 and result["enemy_hp_after"] == 0, "Echo aggregates damage before shield absorption")
	check(result["healed"] == 3 and result["player_state"]["hp"] == 53, "Echo vampirism caps at actual health damage including overkill")
	check(result["player_events"].has("I dealt 3 damage to Test foe.") and result["player_events"].has("Vampirism restored 3 HP to me."), "Echo log reports actual damage and leech")
