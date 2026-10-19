@tool
class_name GameplayTypes
extends RefCounted
## Shared enum vocabulary for typed content and existing text-ID catalogs.
## Enum numbers are serialized by .tres: never reorder or reuse assigned values.

enum Stat {
	DAMAGE = 0, BLOCK = 1, HEALING = 2, VAMPIRISM = 3, PLATING = 4,
	WARD = 5, POISON = 6, BURN = 7, MANA = 8, STAMINA = 9, CURSE = 10,
	THORNS = 11, CLEANSE = 12, SLOW = 13, PIERCE = 14, DOOM = 15,
	SPARK = 16, PHYSICAL_RESISTANCE = 17, MAGICAL_RESISTANCE = 18,
}

enum ResourceType { MANA = 0, STAMINA = 1, HEALTH = 2, MOMENTUM = 3 }
enum DamageType { PHYSICAL = 0, MAGICAL = 1 }
enum Element { NONE = 0, FIRE = 1, FROST = 2, LIGHTNING = 3, VOID = 4, VENOM = 5 }
enum Rarity { COMMON = 0, UNCOMMON = 1, RARE = 2, EPIC = 3, LEGENDARY = 4 }

const INVALID_VALUE: int = -1
const INVALID_ID: StringName = &"<invalid>"

## Array indices match the explicitly assigned enum numbers above.
const STAT_IDS: Array[String] = [
	"damage", "block", "healing", "vampirism", "plating", "ward", "poison",
	"burn", "mana", "stamina", "curse", "thorns", "cleanse", "slow", "pierce",
	"doom", "spark", "physical_resistance", "magical_resistance",
]
const RESOURCE_IDS: Array[String] = ["mana", "stamina", "health", "momentum"]
const DAMAGE_TYPE_IDS: Array[String] = ["physical", "magical"]
const ELEMENT_IDS: Array[String] = ["", "fire", "frost", "lightning", "void", "venom"]
const ELEMENT_IDS_WITHOUT_NONE: Array[String] = [
	ELEMENT_IDS[Element.FIRE], ELEMENT_IDS[Element.FROST], ELEMENT_IDS[Element.LIGHTNING],
	ELEMENT_IDS[Element.VOID], ELEMENT_IDS[Element.VENOM],
]
const RARITY_IDS: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]

## Invalid IDs never silently become a real enum value. IDs are case sensitive.
static func stat_from_id(id: StringName) -> int:
	return STAT_IDS.find(str(id))

static func stat_id(value: int) -> StringName:
	return _id(STAT_IDS, value)

static func resource_from_id(id: StringName) -> int:
	return RESOURCE_IDS.find(str(id))

static func resource_id(value: int) -> StringName:
	return _id(RESOURCE_IDS, value)

static func damage_type_from_id(id: StringName) -> int:
	return DAMAGE_TYPE_IDS.find(str(id))

static func damage_type_id(value: int) -> StringName:
	return _id(DAMAGE_TYPE_IDS, value)

static func element_from_id(id: StringName) -> int:
	return ELEMENT_IDS.find(str(id))

static func element_id(value: int) -> StringName:
	return _id(ELEMENT_IDS, value)

static func rarity_from_id(id: StringName) -> int:
	return RARITY_IDS.find(str(id))

static func rarity_id(value: int) -> StringName:
	return _id(RARITY_IDS, value)

static func _id(ids: Array[String], value: int) -> StringName:
	return StringName(ids[value]) if value >= 0 and value < ids.size() else INVALID_ID

## Godot stores enum-keyed dictionaries as int-keyed dictionaries. Supply the
## named choices explicitly so Inspector authoring does not expose raw integers.
static func enum_dictionary_hint(values: Dictionary) -> String:
	var choices := PackedStringArray()
	for name: String in values:
		choices.append("%s:%d" % [name, values[name]])
	return "%d/%d:%s;%d:" % [TYPE_INT, PROPERTY_HINT_ENUM, ",".join(choices), TYPE_INT]
