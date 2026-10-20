extends "res://tests/support/test_case.gd"

func _run() -> void:
	var path := "res://systems/content/gameplay_types.gd"
	if not FileAccess.file_exists(path):
		check(false, "GameplayTypes enum authority exists")
		report("GAMEPLAY TYPES")
		quit(1)
		return
	var types: Script = load(path)
	if types == null or not types.can_instantiate():
		check(false, "GameplayTypes compiles")
		report("GAMEPLAY TYPES")
		quit(1)
		return
	var families: Array = [
		["stat", types.Stat, types.STAT_IDS],
		["resource", types.ResourceType, types.RESOURCE_IDS],
		["damage_type", types.DamageType, types.DAMAGE_TYPE_IDS],
		["element", types.Element, types.ELEMENT_IDS],
		["rarity", types.Rarity, types.RARITY_IDS]
	]
	for family: Array in families:
		var name: String = family[0]
		var values: Dictionary = family[1]
		var ids: Array = family[2]
		check_equal(values.size(), ids.size(), name + " has exactly one stable ID per enum value")
		var unique: Dictionary = {}
		for member: String in values:
			var value: int = values[member]
			var id: StringName = types.call(name + "_id", value)
			check(id != types.INVALID_ID, name + " maps enum member " + member)
			check(not unique.has(id), name + " IDs are unique: " + str(id))
			unique[id] = true
			check_equal(types.call(name + "_from_id", id), value, name + " round trip: " + member)
		check_equal(types.call(name + "_from_id", &"unknown_value"), types.INVALID_VALUE, name + " rejects unknown IDs")
		check_equal(types.call(name + "_id", -1), types.INVALID_ID, name + " rejects negative values")
		check_equal(types.call(name + "_id", 999), types.INVALID_ID, name + " rejects out-of-range values")
		check_equal(types.call(name + "_from_id", StringName(str(ids.back()).to_upper())), types.INVALID_VALUE, name + " IDs are case sensitive")
	check_equal(types.element_id(types.Element.NONE), &"", "No element preserves the existing empty ID")
	check_equal(types.ELEMENT_IDS_WITHOUT_NONE, ["fire", "frost", "lightning", "void", "venom"], "Reaction elements exclude NONE")
	check_equal(types.RESOURCE_IDS, ["mana", "stamina", "health", "momentum"], "Activation resources match existing committed costs")
	check_equal(types.stat_id(0), &"damage", "Serialized stat zero remains damage")
	check_equal(types.stat_id(18), &"magical_resistance", "Serialized stat eighteen remains magical resistance")
	check_equal(types.rarity_id(4), &"legendary", "Serialized rarity four remains legendary")
	check_equal(types.element_id(5), &"venom", "Serialized element five remains venom")
	check_equal(PackCatalog.STATS, types.STAT_IDS, "Catalog uses the enum-owned stat IDs")
	check_equal(PackCatalog.EXPANSION_ITEMS.STAT_KEYS, types.STAT_IDS, "Expansion items use the enum-owned stat IDs")
	check_equal(PackCatalog.CONTENT.STAT_KEYS, types.STAT_IDS, "Progression items use the enum-owned stat IDs")
	check_equal(PackCatalog.RARITY.TIERS, types.RARITY_IDS, "Rarity tiers use the enum authority")
	check_equal(preload("res://systems/combat/elemental_combat.gd").ELEMENTS, types.ELEMENT_IDS_WITHOUT_NONE, "Combat uses the enum-owned element IDs")
	check_equal(PackCatalog.RARITY.tier({"rarity": types.Rarity.RARE}), "rare", "Legacy rarity presentation accepts enum values")
	check_equal(preload("res://systems/combat/elemental_combat.gd").damage_type({"element": types.Element.FIRE, "damage_type": types.DamageType.PHYSICAL}), "magical", "Elemental damage accepts enum values")
	var elements = preload("res://systems/combat/elemental_combat.gd")
	for key: String in PackCatalog.ROSTER:
		var definition: Dictionary = PackCatalog.item(key)
		var legacy_damage: String = "magical" if ["fire", "frost", "lightning", "void", "venom"].has(str(definition.get("element", ""))) else str(definition.get("damage_type", "magical" if definition.get("role") == "spell" else "physical"))
		check_equal(elements.damage_type(definition), legacy_damage, "Legacy damage classification is preserved: " + key)
	var item: Resource = load("res://systems/items/item_definition.gd").new()
	item.id = &"test_enum_item"
	item.display_name = "Enum Item"
	item.footprint.assign([Vector2i.ZERO])
	item.base_stats[types.Stat.DAMAGE] = 9
	item.activation_costs[types.ResourceType.MOMENTUM] = 2
	item.rarity = types.Rarity.UNCOMMON
	item.damage_type = types.DamageType.PHYSICAL
	item.element = types.Element.NONE
	check_equal(item.validation_errors(), PackedStringArray(), "Definitions accept enum stats, resources and scalar values")
	for field: String in ["rarity", "damage_type", "element"]:
		var original: int = item.get(field)
		item.set(field, 999)
		check("\n".join(item.validation_errors()).contains(field), "Definitions reject invalid enum field " + field)
		item.set(field, original)
	for field: String in ["base_stats", "activation_costs"]:
		item.get(field)[999] = 1
		check("\n".join(item.validation_errors()).contains(field), "Definitions reject unknown enum keys in " + field)
		item.get(field).erase(999)
	check_equal(item.validation_errors(), PackedStringArray(), "Restored enum definition remains valid")
	report("GAMEPLAY TYPES")
	quit(1 if failures else 0)
