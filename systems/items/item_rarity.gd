extends RefCounted
## Definition rarity is independent of combat role, art palette and instance ID.
const TYPES = preload("res://systems/content/gameplay_types.gd")
const TIERS: Array[String] = TYPES.RARITY_IDS
const COLORS: Dictionary = {
	"common": Color("c4bdb0"), "uncommon": Color("78be83"),
	"rare": Color("72aaf0"), "epic": Color("bb91e8"), "legendary": Color("edbd63")
}
const ITEMS: Dictionary = {
	"rusty_knife": "common", "cracked_shield": "common", "bandage": "common",
	"antidote": "common", "buckler": "common", "shortbow": "common", "quiver": "common",
	"blood_gem": "uncommon", "longsword": "uncommon", "tower_shield": "uncommon",
	"iron_charm": "uncommon", "spark_ring": "uncommon", "healing_herbs": "uncommon",
	"ember_tome": "rare", "frost_wand": "rare", "venom_dagger": "rare", "plate_mail": "rare",
	"hunting_trap": "rare", "battle_axe": "rare", "lightning_wand": "rare", "venom_orb": "rare",
	"vampire_fang": "epic", "thorn_mail": "epic", "warding_sigil": "epic",
	"cursed_idol": "epic", "mirror_shard": "epic", "void_tome": "epic", "hourglass": "legendary",
	"magnificent_quiver": "rare", "arrow_broadhead": "common", "arrow_bodkin": "common",
	"arrow_venom": "common", "quiver_capacity": "uncommon", "quiver_mechanism": "uncommon",
	"quiver_fire": "rare", "quiver_poison": "rare", "quiver_explosive": "epic", "quiver_loader": "legendary"
}
const RELICS: Dictionary = {
	"returning_guard": "common", "diagonal_thread": "uncommon", "arcane_barter": "rare",
	"mana_furnace": "rare", "blood_pact": "epic", "plague_seal": "epic",
	"folded_space": "epic", "echo_clock": "legendary", "last_thread": "legendary"
}

static func tier(data: Dictionary) -> String:
	# Legacy in-memory/saved instances can omit rarity; definitions remain authoritative.
	var raw: Variant = data.get("rarity", ITEMS.get(str(data.get("key", "")), RELICS.get(str(data.get("key", "")), "common")))
	var value: String = str(TYPES.rarity_id(raw)) if raw is int else str(raw)
	return value if value in TIERS else "common"

static func color(data: Dictionary) -> Color:
	return COLORS[tier(data)]

static func label(data: Dictionary) -> String:
	return tier(data).capitalize()

static func markup(data: Dictionary) -> String:
	return "[color=#%s]%s[/color]" % [color(data).to_html(false), label(data)]
