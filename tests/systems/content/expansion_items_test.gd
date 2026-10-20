extends "res://tests/support/test_case.gd"


func fixture(character: String = "warrior") -> PackRun:
	var run := PackRun.new()
	run.reset(42, character)
	run.items.clear()
	run.relics.clear()
	run.enemy["hp"] = 10000
	run.enemy["max_hp"] = 10000
	run.enemy["attacks"] = [0]
	return run

func _initialize() -> void:
	if not require_isolation():
		return
	var run := fixture()
	var blade: Dictionary = run.add_item("rusty_knife", Vector2i.ZERO)
	blade.merge({GameplayTypes.Stat.DAMAGE: 4, "momentum_damage": 3}, true)
	blade.activation_costs[GameplayTypes.ResourceType.MOMENTUM] = 2
	blade.activation_costs[GameplayTypes.ResourceType.STAMINA] = 1
	var preview: Dictionary = run.effects()
	check(preview[GameplayTypes.Stat.DAMAGE] == 0 and preview["stamina_spent"] == 0, "Missing Momentum skips attack without spending stamina")
	run.momentum = 2
	preview = run.effects()
	check(preview[GameplayTypes.Stat.DAMAGE] == 10 and run.momentum == 2, "Momentum strike damage previews without live spending")
	run.start_combat()
	run.begin_turn()
	check(run.momentum == 0, "Momentum paid at committed player checkpoint")
	run.complete_turn()
	check(run.momentum == 1, "Momentum payment and exchange gain commit once")
	run = fixture()
	blade = run.add_item("rusty_knife", Vector2i.ZERO)
	blade["momentum_gain"] = 2
	run.end_turn()
	check(run.momentum == 3, "Affordable weapon grants Momentum plus normal exchange gain")
	run = fixture("mage")
	blade = run.add_item("rusty_knife", Vector2i.ZERO)
	blade["activation_costs"][GameplayTypes.ResourceType.MOMENTUM] = 1
	check(run.effects()[GameplayTypes.Stat.DAMAGE] == 0, "Nonwarrior cannot pay Momentum costs")
	run = fixture()
	blade = run.add_item("rusty_knife", Vector2i.ZERO)
	var charm: Dictionary = run.add_item("spark_ring", Vector2i.RIGHT)
	charm["adjacency_bonus"] = {"target_category_ids": ["melee_weapons"], "stats": {GameplayTypes.Stat.DAMAGE: 2, GameplayTypes.Stat.PIERCE: 1}}
	preview = run.effects()
	check(preview[GameplayTypes.Stat.DAMAGE] == 6 and preview[GameplayTypes.Stat.PIERCE] == 1, "Connected equipment supplies typed adjacency stats")
	charm["cell"] = null
	check(run.effects()[GameplayTypes.Stat.DAMAGE] == 4, "Stashed booster grants no stats")
	run = fixture("ranger")
	var quiver: Dictionary = run.add_item("magnificent_quiver", Vector2i.ZERO)
	quiver["arrow_type"] = "broadhead"
	charm = run.add_item("spark_ring", Vector2i(1, 0))
	charm["quiver_bonus"] = {"arrows": 1, GameplayTypes.Stat.DAMAGE: 2, GameplayTypes.Stat.PIERCE: 1, GameplayTypes.Stat.SLOW: 1}
	run.volley_remaining = 1
	preview = run.effects()
	check(preview["volley_damage"] == 14 and preview[GameplayTypes.Stat.PIERCE] == 1 and preview[GameplayTypes.Stat.SLOW] == 1, "Touching fitting adds arrows and flat Volley stats")
	charm["cell"] = Vector2i(5, 5)
	check(run.effects()["volley_damage"] == 8, "Distant fitting cannot affect Volley")
	run = fixture()
	blade = run.add_item("rusty_knife", Vector2i.ZERO)
	blade["category_ids"] = ["companions"]
	charm = run.add_item("blood_gem", Vector2i.RIGHT)
	check(run.effects()[GameplayTypes.Stat.DAMAGE] == 6, "Companion is a physical attacker and accepts attack boosters")
	report("EXPANSION ITEMS")
	quit(1 if failures else 0)
