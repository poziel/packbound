@tool
class_name GameplayTypes
extends RefCounted
## Shared enum vocabulary for typed content and existing text-ID catalogs.
## Enum numbers are serialized by .tres: never reorder or reuse assigned values.

enum Stat {
	DAMAGE = 0,
	BLOCK = 1,
	HEALING = 2,
	VAMPIRISM = 3,
	PLATING = 4,
	WARD = 5,
	POISON = 6,
	BURN = 7,
	MANA = 8,
	STAMINA = 9,
	CURSE = 10,
	THORNS = 11,
	CLEANSE = 12,
	SLOW = 13,
	PIERCE = 14,
	DOOM = 15,
	SPARK = 16,
	PHYSICAL_RESISTANCE = 17,
	MAGICAL_RESISTANCE = 18,
}

enum ResourceType {
	MANA = 0,
	STAMINA = 1,
	HEALTH = 2,
	MOMENTUM = 3
}

enum DamageType {
	PHYSICAL = 0,
	MAGICAL = 1
}

enum Element {
	NONE = 0,
	FIRE = 1,
	FROST = 2,
	LIGHTNING = 3,
	VOID = 4,
	VENOM = 5
}

enum Rarity {
	COMMON = 0,
	UNCOMMON = 1,
	RARE = 2,
	EPIC = 3,
	LEGENDARY = 4
}

const INVALID_VALUE: int = -1
const INVALID_ID: StringName = &"<invalid>"

## Text is derived only at dictionary/presentation compatibility boundaries.
## Enums are the sole vocabulary; there are no separately maintained ID tables.
## Invalid IDs never silently become a real enum value. IDs are case sensitive.
static func stat_from_id(id: StringName) -> int:
	return _from_id(Stat, id)

static func stat_id(value: int) -> StringName:
	return _id(Stat, value)

static func resource_from_id(id: StringName) -> int:
	return _from_id(ResourceType, id)

static func resource_id(value: int) -> StringName:
	return _id(ResourceType, value)

static func damage_type_from_id(id: StringName) -> int:
	return _from_id(DamageType, id)

static func damage_type_id(value: int) -> StringName:
	return _id(DamageType, value)

static func element_from_id(id: StringName) -> int:
	if id == &"": return Element.NONE
	var value: int = _from_id(Element, id)
	return INVALID_VALUE if value == Element.NONE else value

static func element_id(value: int) -> StringName:
	return &"" if value == Element.NONE else _id(Element, value)

static func rarity_from_id(id: StringName) -> int:
	return _from_id(Rarity, id)

static func rarity_id(value: int) -> StringName:
	return _id(Rarity, value)

static func _id(values: Dictionary, value: int) -> StringName:
	var key: Variant = values.find_key(value)
	return StringName(str(key).to_lower()) if key != null else INVALID_ID

static func _from_id(values: Dictionary, id: StringName) -> int:
	var text := str(id)
	if text != text.to_lower(): return INVALID_VALUE
	var key := text.to_upper()
	if key.to_lower() != text: return INVALID_VALUE
	return int(values.get(key, INVALID_VALUE))

## Godot stores enum-keyed dictionaries as int-keyed dictionaries. Supply the
## named choices explicitly so Inspector authoring does not expose raw integers.
static func enum_dictionary_hint(values: Dictionary) -> String:
	var choices := PackedStringArray()
	for name: String in values:
		choices.append("%s:%d" % [name, values[name]])
	return "%d/%d:%s;%d:" % [TYPE_INT, PROPERTY_HINT_ENUM, ",".join(choices), TYPE_INT]
