extends "res://tests/support/prototype_support.gd"

const ELEMENTS = preload("res://systems/combat/elemental_combat.gd")

func _run() -> void:
	check(ELEMENTS.resist(20, 25) == 15 and ELEMENTS.resist(10, 200) == 0, "Percentage resistance clamps safely")
	var combo: Dictionary = ELEMENTS.react({}, ["fire", "frost", "void"])
	check(combo["reactions"] == ["thermal_shock", "blackout"], "Reaction output can trigger a second reaction")
	combo = ELEMENTS.react({}, ["fire", "frost", "lightning"])
	check(combo["reactions"] == ["prismatic_collapse"], "Three-element recipes have deliberate priority")
	for recipe: Dictionary in ELEMENTS.REACTIONS:
		check(recipe["needs"].size() > recipe["produces"].size(), "Reaction consumes net fuel: " + str(recipe["id"]))
	var state: PackRun = fixture("mage")
	check(state.starting_resources()["mana"] == 6 and state.starting_resources()["stamina"] == 0, "Elementalist starts with six innate mana and no stamina")
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
	state.add_item("rusty_knife", Vector2i.ZERO)["damage"] = 10
	state.add_item("spark_ring", Vector2i(4, 0))["mana"] = 3
	var spell: Dictionary = state.add_item("ember_tome", Vector2i(2, 0))
	spell["burn"] = 0
	state.enemy["hp"] = 1000
	state.enemy["max_hp"] = 1000
	state.enemy["armor"] = 3
	state.enemy["attacks"] = [0]
	state.enemy["physical_resistance"] = 50
	state.enemy["magical_resistance"] = 20
	var stats: Dictionary = state.effects()
	check(stats["physical_damage"] == 10 and stats["magical_damage"] == 10 and stats["damage"] == 20, "Mixed weapon and spell damage stays separated")
	var result: Dictionary = state.end_turn()
	check(result["dealt"] == 10 and result["shield_absorbed"] == 3, "Resist matching damage types before shared block")
	check(result["direct_physical_actual"] == 2 and result["direct_magical_actual"] == 8, "Damage feedback preserves physical and magical identities")
	state = fixture("warrior")
	state.items.clear()
	var weapon: Dictionary = state.add_item("rusty_knife", Vector2i.ZERO)
	weapon["element"] = "void"
	check(state.effects()["magical_damage"] == 4 and state.effects()["physical_damage"] == 0, "Elemental weapons are magical regardless of weapon role")
	check(state.effects()["reactions"].is_empty(), "Only Elementalist triggers reactions")
	var traces: Dictionary = ELEMENTS.react({}, ["fire"])["traces"]
	check(not ELEMENTS.react(traces, ["frost"])["reactions"].is_empty(), "Trace can react in a later round")
	traces = ELEMENTS.react(traces, [])["traces"]
	check(ELEMENTS.react(traces, ["frost"])["reactions"].is_empty(), "Old traces expire after their lifetime")
	var inputs: Array[String] = []
	for count in range(50):
		inputs.append_array(ELEMENTS.ELEMENTS)
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
	state.enemy["cleanse"] = 1
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
		for key: String in ["element", "damage_type", "doom", "spark", "physical_resistance", "magical_resistance"]:
			item.erase(key)
	saves.restore(restored, old_save)
	check(restored.enemy_doom == 0 and restored.elemental_traces.is_empty() and restored.items[0]["element"] == "fire", "Legacy saves acquire new fields without losing their inventory")

func _ui_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run.reset(42, "mage")
	game.run.enemy_doom = 3
	game.run.enemy_doom_turns = 2
	game.run.enemy_spark = 2
	game.run.enemy_slow = 1
	game.run.elemental_traces = {"void": [2], "fire": [1]}
	game._refresh()
	var status: RichTextLabel = game.enemy_vitals.get_node("Statuses/Content")
	check(status.text.contains("doom") and status.text.contains("Spark") and status.text.contains("void"), "Enemy HUD shows new conditions and traces with links")
	game.hovered_enemy_status = "doom"
	check(game._enemy_status_inspection()["title"] == "Doom", "Doom has nested status inspection")
	check(PackKeywords.has_icon("doom"), "Existing Doom artwork is reused")
	check(PackKeywordLinks.rich("Thermal Shock").contains("[url=reaction_thermal_shock]"), "Reaction names open their own definitions")
	check(not PackKeywordLinks.entry("reaction_prismatic_collapse")["keyword_list"].is_empty(), "Multi-element reaction definitions expose their effects")
	game.run.enemy["magical_resistance"] = 35
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
