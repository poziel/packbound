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
		["stat", types.Stat],
		["resource", types.ResourceType],
		["damage_type", types.DamageType],
		["element", types.Element],
		["rarity", types.Rarity]
	]
	for family: Array in families:
		var name: String = family[0]
		var values: Dictionary = family[1]
		var unique: Dictionary = {}
		for member: String in values:
			var value: int = values[member]
			var id: StringName = types.call(name + "_id", value)
			check(id != types.INVALID_ID, name + " maps enum member " + member)
			check(not unique.has(id), name + " IDs are unique: " + str(id))
			unique[id] = true
			check_equal(types.call(name + "_from_id", id), value, name + " round trip: " + member)
			check_equal(str(id), "" if name == "element" and member == "NONE" else member.to_lower(), name + " text boundary derives from enum names")
		check_equal(types.call(name + "_from_id", &"unknown_value"), types.INVALID_VALUE, name + " rejects unknown IDs")
		check_equal(types.call(name + "_id", -1), types.INVALID_ID, name + " rejects negative values")
		check_equal(types.call(name + "_id", 999), types.INVALID_ID, name + " rejects out-of-range values")
		check_equal(types.call(name + "_from_id", StringName(str(values.keys().back()))), types.INVALID_VALUE, name + " IDs are case sensitive")
	check_equal(types.element_id(types.Element.NONE), &"", "No element preserves the existing empty ID")
	check_equal(types.stat_from_id(&"DAMAGE"), types.INVALID_VALUE, "Text boundary remains case sensitive")
	check_equal(types.stat_from_id(&" damage"), types.INVALID_VALUE, "Text boundary rejects padded IDs")
	check_equal(types.resource_from_id(&"\u017ftamina"), types.INVALID_VALUE, "Text boundary rejects noncanonical Unicode spellings")
	check_equal(types.element_from_id(&"none"), types.INVALID_VALUE, "NONE retains only its existing empty text representation")
	for retired: String in ["STAT_IDS", "RESOURCE_IDS", "DAMAGE_TYPE_IDS", "ELEMENT_IDS", "ELEMENT_IDS_WITHOUT_NONE", "RARITY_IDS"]:
		check(not types.get_script_constant_map().has(retired), "Retired duplicate vocabulary: " + retired)
	check_equal(types.stat_id(0), &"damage", "Serialized stat zero remains damage")
	check_equal(types.stat_id(18), &"magical_resistance", "Serialized stat eighteen remains magical resistance")
	check_equal(types.rarity_id(4), &"legendary", "Serialized rarity four remains legendary")
	check_equal(types.element_id(5), &"venom", "Serialized element five remains venom")
	check_equal(PackCatalog.RARITY.tier({"rarity": types.Rarity.RARE}), types.Rarity.RARE, "Rarity stays an enum in runtime presentation data")
	check_equal(PackCatalog.item("rusty_knife").rarity, types.Rarity.COMMON, "Catalog retains enum rarity")
	for row: Dictionary in PackCatalog.innate_stats("mage"):
		check(row.key is String and PackKeywords.has_icon(row.key), "Innate stat presentation keeps named icon keys")
	check_equal(PackCatalog.RARITY.tier({"rarity": "rare"}), types.Rarity.COMMON, "Runtime does not reinterpret legacy strings")
	check_equal(preload("res://systems/combat/elemental_combat.gd").damage_type({"element": types.Element.FIRE, "damage_type": types.DamageType.PHYSICAL}), types.DamageType.MAGICAL, "Elemental damage accepts enum values")
	var elements = preload("res://systems/combat/elemental_combat.gd")
	for key: String in PackCatalog.ROSTER:
		var definition: Dictionary = PackCatalog.item(key)
		var expected_damage: int = types.DamageType.MAGICAL if definition.element != types.Element.NONE else definition.damage_type
		check_equal(elements.damage_type(definition), expected_damage, "Authored damage classification is preserved: " + key)
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
