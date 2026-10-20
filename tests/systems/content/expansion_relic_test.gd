extends "res://tests/support/test_case.gd"

const EXPANSION = preload("res://systems/relics/expansion_relics.gd")


func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()


func fixture() -> PackRun:
	var state := PackRun.new()
	state.reset(42)
	state.relics.clear()
	return state

func _run() -> void:
	check(EXPANSION.RELIC_KEYS.size() == 50, "Fifty distinct expansion relics")
	var tiers: Dictionary = {}
	for key: String in EXPANSION.RELIC_KEYS:
		var relic: Dictionary = EXPANSION.relics()[key]
		tiers[relic["rarity"]] = int(tiers.get(relic["rarity"], 0)) + 1
		check(PackCatalog.relic(key)["name"] == relic["name"], "Catalog loads " + key)
	check(tiers == {GameplayTypes.Rarity.COMMON: 8, GameplayTypes.Rarity.UNCOMMON: 12, GameplayTypes.Rarity.RARE: 14, GameplayTypes.Rarity.EPIC: 10, GameplayTypes.Rarity.LEGENDARY: 6}, "Relic rarity distribution")
	var state: PackRun = fixture()
	state.relics.assign(["tin_cricket"])
	var before: Dictionary = state.effects()
	check(before[GameplayTypes.Stat.WARD] == 1, "Cricket provides ward")
	var again: Dictionary = state.effects()
	check(before == again and state.turn == 1, "Repeated previews are deterministic without advancing state")
	state.relics.assign(["ram_flywheel", "siege_heart"])
	state.momentum = 100
	var enhanced: Dictionary = state.effects()
	state.relics.clear()
	var baseline: Dictionary = state.effects()
	check(enhanced["physical_damage"] - baseline["physical_damage"] == 6, "Momentum damage respects six-count cap")
	check(enhanced[GameplayTypes.Stat.BLOCK] - baseline[GameplayTypes.Stat.BLOCK] == 16, "Momentum block respects eight-count cap")
	state.class_key = "mage"
	state.relics.assign(["ram_flywheel"])
	enhanced = state.effects()
	state.relics.clear()
	baseline = state.effects()
	check(enhanced[GameplayTypes.Stat.DAMAGE] == baseline[GameplayTypes.Stat.DAMAGE], "Warmonger relic is class specific")
	state = fixture()
	state.relics.assign(["pilgrim_sock", "copper_afterlife"])
	state.turn = 1
	check(state.starting_resources()[GameplayTypes.Stat.STAMINA] == 4, "Conditional stamina absent on first round")
	state.turn = 6
	check(state.starting_resources()[GameplayTypes.Stat.STAMINA] == 7, "Conditional stamina applies to round refill budget")
	state.relics.assign(["cinder_nursery", "mourning_volcano"])
	state.hp = 1
	state.enemy_burn = 0
	enhanced = state.effects()
	check(enhanced[GameplayTypes.Stat.BURN] >= 6, "Low HP volcano adds Burn")
	check(enhanced[GameplayTypes.Stat.HEALING] == 0, "A relic cannot enable another relic in the same pass")
	state.enemy_burn = 1
	check(state.effects()[GameplayTypes.Stat.HEALING] == 2, "Existing Burn enables nursery next round")
	state.relics.assign(["tin_cricket", "ram_flywheel", "winter_mortgage"])
	state.enemy_slow = 2
	before = state.effects()
	state.relics.reverse()
	check(before[GameplayTypes.Stat.DAMAGE] == state.effects()[GameplayTypes.Stat.DAMAGE] and before[GameplayTypes.Stat.WARD] == state.effects()[GameplayTypes.Stat.WARD], "Relic equipment order does not change awards")
	state.reset(42)
	state.relics.clear()
	check(state.momentum == 0 and state.enemy_burn == 0 and state.effects()[GameplayTypes.Stat.WARD] == 0, "Reset clears enabling state and equipment")
	state.items.clear()
	var disabled: Dictionary = state.add_item("rusty_knife", Vector2i.ZERO)
	disabled["classes"] = ["mage"]
	state.relics.assign(["rust_psalm"])
	check(state.effects()[GameplayTypes.Stat.PIERCE] == 0, "Dormant wrong-class weapons cannot enable relic bonuses")
	disabled["category_ids"] = ["companions"]
	state.relics.assign(["grave_bell"])
	check(state.effects()[GameplayTypes.Stat.WARD] == 0, "Dormant wrong-class companions cannot enable relic bonuses")
	report("EXPANSION RELICS")
	quit(1 if failures else 0)
