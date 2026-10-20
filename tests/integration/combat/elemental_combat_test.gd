extends "res://tests/support/prototype_support.gd"

const ELEMENTS = preload("res://systems/combat/elemental_combat.gd")

func _run() -> void:
	check(ELEMENTS.resist(20, 25) == 15 and ELEMENTS.resist(10, 200) == 0, "Percentage resistance clamps safely")
	var combo: Dictionary = ELEMENTS.react({}, [GameplayTypes.Element.FIRE, GameplayTypes.Element.FROST, GameplayTypes.Element.VOID])
	check(combo["reactions"] == ["thermal_shock", "blackout"], "Reaction output can trigger a second reaction")
	combo = ELEMENTS.react({}, [GameplayTypes.Element.FIRE, GameplayTypes.Element.FROST, GameplayTypes.Element.LIGHTNING])
	check(combo["reactions"] == ["prismatic_collapse"], "Three-element recipes have deliberate priority")
	for recipe: Dictionary in ELEMENTS.REACTIONS:
		check(recipe["needs"].size() > recipe["produces"].size(), "Reaction consumes net fuel: " + str(recipe["id"]))
	var state: PackRun = fixture("mage")
	check(state.starting_resources()[GameplayTypes.Stat.MANA] == 6 and state.starting_resources()[GameplayTypes.Stat.STAMINA] == 0, "Elementalist starts with six innate mana and no stamina")
	check(state.effects()["magical_damage"] > 0 and not state.effects()["reactions"].is_empty(), "Starting spells produce magical damage and reactions")
	state.items.clear()
	state.add_item("lightning_wand", Vector2i.ZERO)
	state.enemy["hp"] = 1000
	state.enemy["max_hp"] = 1000
	state.enemy["attacks"] = [0]
	var result: Dictionary = state.end_turn()
	check(state.enemy_spark == 1 and result["spark_damage_actual"] == 0, "New Spark waits for a later magical hit")
	result = state.end_turn()
	check(result["spark_damage_actual"] == 2, "Existing Spark discharges on later magic")
	state = fixture("mage")
	state.items.clear()
	state.add_item("void_tome", Vector2i.ZERO)
	state.enemy["hp"] = 1000
	state.enemy["max_hp"] = 1000
	state.enemy["attacks"] = [0]
	state.end_turn()
	state.end_turn()
	result = state.end_turn()
	check(result["doom_damage_actual"] == 6 and state.enemy_doom == 0, "Doom stacks detonate on the third round")
	_resistance_checks()
	_state_checks()
	await _ui_checks()
	report("ELEMENTAL COMBAT")
	quit(1 if failures else 0)

func _resistance_checks() -> void:
	var state: PackRun = fixture("warrior")
	state.items.clear()
	state.add_item("rusty_knife", Vector2i.ZERO)[GameplayTypes.Stat.DAMAGE] = 10
	state.add_item("spark_ring", Vector2i(4, 0))[GameplayTypes.Stat.MANA] = 3
	var spell: Dictionary = state.add_item("ember_tome", Vector2i(2, 0))
	spell[GameplayTypes.Stat.BURN] = 0
	state.enemy["hp"] = 1000
	state.enemy["max_hp"] = 1000
	state.enemy["armor"] = 3
	state.enemy["attacks"] = [0]
	state.enemy[GameplayTypes.Stat.PHYSICAL_RESISTANCE] = 50
	state.enemy[GameplayTypes.Stat.MAGICAL_RESISTANCE] = 20
	var stats: Dictionary = state.effects()
	check(stats["physical_damage"] == 10 and stats["magical_damage"] == 10 and stats[GameplayTypes.Stat.DAMAGE] == 20, "Mixed weapon and spell damage stays separated")
	var result: Dictionary = state.end_turn()
	check(result["dealt"] == 10 and result["shield_absorbed"] == 3, "Resist matching damage types before shared block")
	check(result["direct_physical_actual"] == 2 and result["direct_magical_actual"] == 8, "Damage feedback preserves physical and magical identities")
	state = fixture("warrior")
	state.items.clear()
	var weapon: Dictionary = state.add_item("rusty_knife", Vector2i.ZERO)
	weapon["element"] = GameplayTypes.Element.VOID
	check(state.effects()["magical_damage"] == 4 and state.effects()["physical_damage"] == 0, "Elemental weapons are magical regardless of weapon role")
	check(state.effects()["reactions"].is_empty(), "Only Elementalist triggers reactions")
	var traces: Dictionary = ELEMENTS.react({}, [GameplayTypes.Element.FIRE])["traces"]
	check(not ELEMENTS.react(traces, [GameplayTypes.Element.FROST])["reactions"].is_empty(), "Trace can react in a later round")
	traces = ELEMENTS.react(traces, [])["traces"]
	check(ELEMENTS.react(traces, [GameplayTypes.Element.FROST])["reactions"].is_empty(), "Old traces expire after their lifetime")
	var inputs: Array[int] = []
	for count in range(50):
		for element: int in GameplayTypes.Element.values():
			if element != GameplayTypes.Element.NONE:
				inputs.append(element)
	var chain: Dictionary = ELEMENTS.react({}, inputs)
	check(chain["reactions"].size() <= inputs.size() and chain["reactions"].size() > 50, "Large chains terminate by consuming fuel")

func _state_checks() -> void:
	var state: PackRun = fixture("mage")
	state.enemy["hp"] = 1000
	state.enemy["max_hp"] = 1000
	state.enemy["attacks"] = [0]
	var before: Dictionary = PackRunSaves.new().capture(state, 0)
	for preview in range(20):
		state.outcome(state.effects())
	check(PackRunSaves.new().capture(state, 0) == before, "Repeated elemental previews mutate no state or RNG")
	state.start_combat()
	state.begin_turn()
	var restored := PackRun.new()
	var saves := PackRunSaves.new()
	saves.restore(restored, saves.capture(state, 0))
	check(restored.elemental_traces == state.elemental_traces and restored.enemy_slow == state.enemy_slow, "Mid-round saves preserve traces and conditions")
	var trace_snapshot: Dictionary = restored.elemental_traces.duplicate(true)
	restored.complete_turn()
	check(restored.elemental_traces == trace_snapshot, "Enemy response never resolves reactions twice")
	restored.prepare_enemy()
	check(restored.elemental_traces.is_empty() and restored.enemy_slow == 0 and restored.enemy_spark == 0 and restored.enemy_doom == 0, "Encounter reset clears conditions and traces")
	state = fixture("mage")
	state.enemy["hp"] = 1000
	state.enemy["max_hp"] = 1000
	state.enemy["attacks"] = [0]
	state.enemy[GameplayTypes.Stat.CLEANSE] = 1
	state.enemy_doom = 8
	state.enemy_doom_turns = 1
	state.enemy_spark = 8
	state.enemy_slow = 8
	var result: Dictionary = state.end_turn()
	check(result["doom_damage_actual"] == 0 and result["spark_damage_actual"] == 0 and state.enemy_doom == 0 and state.enemy_slow == 1, "Cleanse clears old conditions before new applications")
	var old_save: Dictionary = saves.capture(state, 0)
	for key: String in ["enemy_slow", "enemy_spark", "enemy_doom", "enemy_doom_turns", "elemental_traces"]:
		old_save["state"].erase(key)
	for item: Dictionary in old_save["state"]["items"]:
		for key: Variant in ["element", "damage_type", GameplayTypes.Stat.DOOM, GameplayTypes.Stat.SPARK, GameplayTypes.Stat.PHYSICAL_RESISTANCE, GameplayTypes.Stat.MAGICAL_RESISTANCE]:
			item.erase(key)
	saves.restore(restored, old_save)
	check(restored.enemy_doom == 0 and restored.elemental_traces.is_empty() and restored.items[0]["element"] == GameplayTypes.Element.FIRE, "Legacy saves acquire new fields without losing their inventory")

func _ui_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run.reset(42, "mage")
	game.run.enemy_doom = 3
	game.run.enemy_doom_turns = 2
	game.run.enemy_spark = 2
	game.run.enemy_slow = 1
	game.run.elemental_traces = {GameplayTypes.Element.VOID: [2], GameplayTypes.Element.FIRE: [1]}
	game._refresh()
	var status: RichTextLabel = game.enemy_vitals.get_node("Statuses/Content")
	check(status.text.contains("url=doom") and status.text.contains("url=spark"), "Enemy HUD exposes condition links with glyphs")
	check(game.enemy_trace_indicator.visible and game._enemy_trace_inspection().get("body", "").contains("Void"), "Elementalist trace indicator exposes authored trace details")
	var trace_body: String = game._enemy_trace_inspection().get("body", "")
	check(trace_body.contains("Fire ×1") and trace_body.contains("Void ×1"), "Trace labels display element names rather than enum integers")
	var reaction_body: String = PackKeywordLinks.entry("reaction_thermal_shock").get("body", "")
	check(reaction_body.contains("fire") and reaction_body.contains("frost"), "Reaction recipe labels display element names rather than enum integers")
	game.hovered_enemy_status = "doom"
	check(PackKeywordLinks.entry("doom").get("title", "") == "Doom", "Doom links resolve to the nested status definition")
	check(PackKeywords.has_icon("doom"), "Existing Doom artwork is reused")
	check(PackKeywordLinks.rich("Thermal Shock").contains("[url=reaction_thermal_shock]"), "Reaction names open their own definitions")
	check(not PackKeywordLinks.entry("reaction_prismatic_collapse")["keyword_list"].is_empty(), "Multi-element reaction definitions expose their effects")
	game.run.enemy[GameplayTypes.Stat.MAGICAL_RESISTANCE] = 35
	check(game._enemy_rules().to_lower().contains("magical resistance 35%"), "Monster inspection exposes resistance percentage")
	check(game.values.has("magical_damage") and not game._stat_inspection("magical_damage").is_empty(), "Statistics panel exposes separate magical damage with a definition")
	if DisplayServer.get_name() != "headless":
		game.front.hide()
		game.combat.show()
		game.character_portrait.texture = PackArt.character_head("mage")
		game.character_tabs.current_tab = game.character_tabs.get_tab_idx_from_control(game.board.get_parent())
		game.inspector.set_process(false)
		game.inspector._spawn(game._character_inspection(), Rect2(1200, 140, 40, 40), -1)
		for frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("legacy_logs/elementalist-review.png"))
	game.queue_free()
	await process_frame
