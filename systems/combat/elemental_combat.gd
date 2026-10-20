extends RefCounted

const CATEGORIES = preload("res://systems/content/collectible_categories.gd")
## Pure combat rules. Every reaction consumes more traces than it creates.
const TYPES = preload("res://systems/content/gameplay_types.gd")
const ELEMENTS: Array[String] = TYPES.ELEMENT_IDS_WITHOUT_NONE
const CONDITIONS: Dictionary = {"fire": "burn", "frost": "slow", "lightning": "spark", "void": "doom", "venom": "poison"}
const TRACE_ROUNDS: int = 2
const DOOM_ROUNDS: int = 3
const DOOM_DAMAGE: int = 2
const SPARK_DAMAGE: int = 2
const REACTIONS: Array[Dictionary] = [
	{"id": "prismatic_collapse", "name": "Prismatic Collapse", "needs": ["fire", "frost", "lightning"], "produces": ["void"], "damage": 6, "doom": 2},
	{"id": "sepulchral_flare", "name": "Sepulchral Flare", "needs": ["fire", "void", "venom"], "produces": ["lightning"], "damage": 5, "burn": 2, "doom": 1},
	{"id": "tempest_plague", "name": "Tempest Plague", "needs": ["frost", "lightning", "venom"], "produces": ["void"], "damage": 3, "spark": 2, "poison": 2, "slow": 1},
	{"id": "thermal_shock", "name": "Thermal Shock", "needs": ["fire", "frost"], "produces": ["lightning"], "damage": 2},
	{"id": "overload", "name": "Overload", "needs": ["fire", "lightning"], "produces": ["void"], "damage": 3, "spark": 1},
	{"id": "combustion", "name": "Combustion", "needs": ["fire", "venom"], "produces": ["fire"], "burn": 3},
	{"id": "hellfire", "name": "Hellfire", "needs": ["fire", "void"], "produces": ["fire"], "burn": 2, "doom": 1},
	{"id": "superconduct", "name": "Superconduct", "needs": ["frost", "lightning"], "produces": ["frost"], "damage": 2, "slow": 2},
	{"id": "numbing_toxin", "name": "Numbing Toxin", "needs": ["frost", "venom"], "produces": ["venom"], "poison": 2, "slow": 1},
	{"id": "shatterveil", "name": "Shatterveil", "needs": ["frost", "void"], "produces": ["venom"], "damage": 3, "pierce": 2},
	{"id": "blackout", "name": "Blackout", "needs": ["lightning", "void"], "produces": ["frost"], "spark": 2, "doom": 1},
	{"id": "toxic_current", "name": "Toxic Current", "needs": ["lightning", "venom"], "produces": ["lightning"], "damage": 2, "spark": 1, "poison": 1},
	{"id": "blight", "name": "Blight", "needs": ["void", "venom"], "produces": ["venom"], "doom": 2}
]

static func damage_type(item: Dictionary) -> String:
	var raw_element: Variant = item.get("element", "")
	var element_id: String = str(TYPES.element_id(raw_element)) if raw_element is int else str(raw_element)
	if ELEMENTS.has(element_id):
		return "magical"
	var fallback: String = "magical" if CATEGORIES.matches(item, &"magic_weapons") else "physical"
	var raw_type: Variant = item.get("damage_type", fallback)
	if raw_type is int:
		var type_id: StringName = TYPES.damage_type_id(raw_type)
		return fallback if type_id == TYPES.INVALID_ID else str(type_id)
	return str(raw_type)

static func resist(amount: int, percent: int) -> int:
	return maxi(0, amount) * (100 - clampi(percent, 0, 100)) / 100

static func react(previous: Dictionary, inputs: Array) -> Dictionary:
	var traces: Dictionary = {}
	var fuel: int = 0
	for element: String in ELEMENTS:
		traces[element] = []
		for life: int in previous.get(element, []):
			if life > 1:
				traces[element].append(life - 1)
		for input: String in inputs:
			if input == element:
				traces[element].append(TRACE_ROUNDS)
		fuel += traces[element].size()
	var result: Dictionary = {"traces": traces, "reactions": [], "damage": 0, "burn": 0, "slow": 0, "spark": 0, "doom": 0, "poison": 0, "pierce": 0}
	# Fuel is a proof-bound, not a per-round proc cap: every recipe reduces it.
	for step in range(fuel):
		var chosen: Dictionary = {}
		for recipe: Dictionary in REACTIONS:
			var matches: bool = true
			for element: String in recipe["needs"]:
				matches = matches and not traces[element].is_empty()
			if matches:
				chosen = recipe
				break
		if chosen.is_empty():
			break
		for element: String in chosen["needs"]:
			traces[element].pop_front()
		for element: String in chosen["produces"]:
			traces[element].append(TRACE_ROUNDS)
		for stat: String in ["damage", "burn", "slow", "spark", "doom", "poison", "pierce"]:
			result[stat] += int(chosen.get(stat, 0))
		result["reactions"].append(chosen["id"])
	return result

static func reaction(id: String) -> Dictionary:
	for entry: Dictionary in REACTIONS:
		if entry["id"] == id:
			return entry
	return {}
