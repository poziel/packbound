extends RefCounted
## Authored Volley tuning; selected arrows/upgrades remain per-run state.
const CATEGORIES = preload("res://systems/content/collectible_categories.gd")
const KEY: String = "magnificent_quiver"
const INITIAL: Array[String] = ["arrow_broadhead", "arrow_bodkin", "arrow_venom"]
const OPTION_IDS: Array[String] = ["arrow_broadhead", "arrow_bodkin", "arrow_venom", "quiver_capacity", "quiver_mechanism", "quiver_fire", "quiver_poison", "quiver_explosive", "quiver_loader"]
static var INTERVAL: int:
	get: return effect(KEY).interval
static var ARROWS: int:
	get: return effect(KEY).arrows
static var DAMAGE: int:
	get: return int(effect(KEY).per_arrow_stats.get(GameplayTypes.Stat.DAMAGE, 0))
static var OPTIONS: Dictionary:
	get:
		var result: Dictionary = {}
		for id: String in OPTION_IDS:
			var definition: CollectibleDefinition = CATEGORIES.definition_for_key(id)
			var tuning: QuiverVolleyEffectDefinition = effect(id)
			var option: Dictionary = {"name": definition.display_name, "detail": definition.description}
			if tuning.kind == QuiverVolleyEffectDefinition.Kind.ARROW: option["type"] = str(tuning.arrow_type)
			else: option["cap"] = tuning.cap
			result[id] = option
		return result

static func effect(id: String) -> QuiverVolleyEffectDefinition:
	var definition: CollectibleDefinition = CATEGORIES.definition_for_key(id)
	if definition == null: return null
	for ability: AbilityDefinition in definition.abilities:
		if ability.trigger_id != &"quiver_loadout": continue
		for value: EffectDefinition in ability.effects:
			if value is QuiverVolleyEffectDefinition: return value
	return null

static func available(item: Dictionary) -> Array[String]:
	return preload("res://systems/loot/loot_selection.gd").available_upgrades(item)

static func _loadout(item: Dictionary) -> Dictionary:
	var base: QuiverVolleyEffectDefinition = effect(KEY)
	var result: Dictionary = {"arrows": base.arrows, "interval": base.interval, "per_arrow": base.per_arrow_stats.duplicate(), "flat": base.volley_stats.duplicate()}
	var selected: Array = []
	for id: String in INITIAL:
		var arrow: QuiverVolleyEffectDefinition = effect(id)
		if str(arrow.arrow_type) == item.get("arrow_type", ""): selected.append([arrow, 1])
	for id: String in item.get("upgrades", {}):
		var upgrade: QuiverVolleyEffectDefinition = effect(id)
		if upgrade != null and upgrade.kind == QuiverVolleyEffectDefinition.Kind.UPGRADE: selected.append([upgrade, int(item.upgrades[id])])
	for pair: Array in selected:
		var tuning: QuiverVolleyEffectDefinition = pair[0]
		var count: int = pair[1]
		result.arrows += tuning.arrows * count
		result.interval -= tuning.interval_reduction * count
		for stat: int in tuning.per_arrow_stats: result.per_arrow[stat] = int(result.per_arrow.get(stat, 0)) + tuning.per_arrow_stats[stat] * count
		for stat: int in tuning.volley_stats: result.flat[stat] = int(result.flat.get(stat, 0)) + tuning.volley_stats[stat] * count
	return result

static func per_arrow_stats(item: Dictionary) -> Dictionary:
	return _loadout(item).per_arrow

static func stats(item: Dictionary, adjacency: int = 0) -> Dictionary:
	var tuning: Dictionary = _loadout(item)
	var result: Dictionary = {"arrows": tuning.arrows, "interval": tuning.interval}
	for stat: int in [GameplayTypes.Stat.DAMAGE, GameplayTypes.Stat.PIERCE, GameplayTypes.Stat.POISON, GameplayTypes.Stat.BURN, GameplayTypes.Stat.SLOW]:
		result[stat] = tuning.arrows * int(tuning.per_arrow.get(stat, 0)) + int(tuning.flat.get(stat, 0))
	result[GameplayTypes.Stat.DAMAGE] += adjacency
	return result

static func describe(_item: Dictionary, _remaining: int, _adjacency: int = 0) -> String:
	return CATEGORIES.definition_for_key(KEY).description
