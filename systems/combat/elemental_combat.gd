extends RefCounted

const CATEGORIES = preload("res://systems/content/collectible_categories.gd")
## Pure combat rules. Every reaction consumes more traces than it creates.
const TYPES = preload("res://systems/content/gameplay_types.gd")
const CONDITIONS: Dictionary = {TYPES.Element.FIRE: "burn", TYPES.Element.FROST: "slow", TYPES.Element.LIGHTNING: "spark", TYPES.Element.VOID: "doom", TYPES.Element.VENOM: "poison"}
const TRACE_ROUNDS: int = 2
const DOOM_ROUNDS: int = 3
const DOOM_DAMAGE: int = 2
const SPARK_DAMAGE: int = 2
const REACTIONS: Array[Dictionary] = [
	{"id": "prismatic_collapse", "name": "Prismatic Collapse", "needs": [TYPES.Element.FIRE, TYPES.Element.FROST, TYPES.Element.LIGHTNING], "produces": [TYPES.Element.VOID], GameplayTypes.Stat.DAMAGE: 6, GameplayTypes.Stat.DOOM: 2},
	{"id": "sepulchral_flare", "name": "Sepulchral Flare", "needs": [TYPES.Element.FIRE, TYPES.Element.VOID, TYPES.Element.VENOM], "produces": [TYPES.Element.LIGHTNING], GameplayTypes.Stat.DAMAGE: 5, GameplayTypes.Stat.BURN: 2, GameplayTypes.Stat.DOOM: 1},
	{"id": "tempest_plague", "name": "Tempest Plague", "needs": [TYPES.Element.FROST, TYPES.Element.LIGHTNING, TYPES.Element.VENOM], "produces": [TYPES.Element.VOID], GameplayTypes.Stat.DAMAGE: 3, GameplayTypes.Stat.SPARK: 2, GameplayTypes.Stat.POISON: 2, GameplayTypes.Stat.SLOW: 1},
	{"id": "thermal_shock", "name": "Thermal Shock", "needs": [TYPES.Element.FIRE, TYPES.Element.FROST], "produces": [TYPES.Element.LIGHTNING], GameplayTypes.Stat.DAMAGE: 2},
	{"id": "overload", "name": "Overload", "needs": [TYPES.Element.FIRE, TYPES.Element.LIGHTNING], "produces": [TYPES.Element.VOID], GameplayTypes.Stat.DAMAGE: 3, GameplayTypes.Stat.SPARK: 1},
	{"id": "combustion", "name": "Combustion", "needs": [TYPES.Element.FIRE, TYPES.Element.VENOM], "produces": [TYPES.Element.FIRE], GameplayTypes.Stat.BURN: 3},
	{"id": "hellfire", "name": "Hellfire", "needs": [TYPES.Element.FIRE, TYPES.Element.VOID], "produces": [TYPES.Element.FIRE], GameplayTypes.Stat.BURN: 2, GameplayTypes.Stat.DOOM: 1},
	{"id": "superconduct", "name": "Superconduct", "needs": [TYPES.Element.FROST, TYPES.Element.LIGHTNING], "produces": [TYPES.Element.FROST], GameplayTypes.Stat.DAMAGE: 2, GameplayTypes.Stat.SLOW: 2},
	{"id": "numbing_toxin", "name": "Numbing Toxin", "needs": [TYPES.Element.FROST, TYPES.Element.VENOM], "produces": [TYPES.Element.VENOM], GameplayTypes.Stat.POISON: 2, GameplayTypes.Stat.SLOW: 1},
	{"id": "shatterveil", "name": "Shatterveil", "needs": [TYPES.Element.FROST, TYPES.Element.VOID], "produces": [TYPES.Element.VENOM], GameplayTypes.Stat.DAMAGE: 3, GameplayTypes.Stat.PIERCE: 2},
	{"id": "blackout", "name": "Blackout", "needs": [TYPES.Element.LIGHTNING, TYPES.Element.VOID], "produces": [TYPES.Element.FROST], GameplayTypes.Stat.SPARK: 2, GameplayTypes.Stat.DOOM: 1},
	{"id": "toxic_current", "name": "Toxic Current", "needs": [TYPES.Element.LIGHTNING, TYPES.Element.VENOM], "produces": [TYPES.Element.LIGHTNING], GameplayTypes.Stat.DAMAGE: 2, GameplayTypes.Stat.SPARK: 1, GameplayTypes.Stat.POISON: 1},
	{"id": "blight", "name": "Blight", "needs": [TYPES.Element.VOID, TYPES.Element.VENOM], "produces": [TYPES.Element.VENOM], GameplayTypes.Stat.DOOM: 2}
]

static func damage_type(item: Dictionary) -> GameplayTypes.DamageType:
	if has_element(item.get("element", TYPES.Element.NONE)):
		return TYPES.DamageType.MAGICAL
	return item.get("damage_type", TYPES.DamageType.MAGICAL if CATEGORIES.matches(item, &"magic_weapons") else TYPES.DamageType.PHYSICAL)

static func has_element(value: int) -> bool:
	return value != TYPES.Element.NONE and TYPES.Element.values().has(value)

static func resist(amount: int, percent: int) -> int:
	return maxi(0, amount) * (100 - clampi(percent, 0, 100)) / 100

static func react(previous: Dictionary, inputs: Array) -> Dictionary:
	var traces: Dictionary = {}
	var fuel: int = 0
	for element_type: int in TYPES.Element.values():
		if element_type == TYPES.Element.NONE: continue
		var element: int = element_type
		traces[element] = []
		for life: int in previous.get(element, []):
			if life > 1:
				traces[element].append(life - 1)
		for input: int in inputs:
			if input == element:
				traces[element].append(TRACE_ROUNDS)
		fuel += traces[element].size()
	var result: Dictionary = {"traces": traces, "reactions": [], GameplayTypes.Stat.DAMAGE: 0, GameplayTypes.Stat.BURN: 0, GameplayTypes.Stat.SLOW: 0, GameplayTypes.Stat.SPARK: 0, GameplayTypes.Stat.DOOM: 0, GameplayTypes.Stat.POISON: 0, GameplayTypes.Stat.PIERCE: 0}
	# Fuel is a proof-bound, not a per-round proc cap: every recipe reduces it.
	for step in range(fuel):
		var chosen: Dictionary = {}
		for recipe: Dictionary in REACTIONS:
			var matches: bool = true
			for element: int in recipe["needs"]:
				matches = matches and not traces[element].is_empty()
			if matches:
				chosen = recipe
				break
		if chosen.is_empty():
			break
		for element: int in chosen["needs"]:
			traces[element].pop_front()
		for element: int in chosen["produces"]:
			traces[element].append(TRACE_ROUNDS)
		for stat: int in [GameplayTypes.Stat.DAMAGE, GameplayTypes.Stat.BURN, GameplayTypes.Stat.SLOW, GameplayTypes.Stat.SPARK, GameplayTypes.Stat.DOOM, GameplayTypes.Stat.POISON, GameplayTypes.Stat.PIERCE]:
			result[stat] += int(chosen.get(stat, 0))
		result["reactions"].append(chosen["id"])
	return result

static func reaction(id: String) -> Dictionary:
	for entry: Dictionary in REACTIONS:
		if entry["id"] == id:
			return entry
	return {}
