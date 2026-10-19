class_name PackCatalog
extends RefCounted

const QUIVER = preload("res://scripts/archer_quiver.gd")

const BASE_STAMINA: int = 3
const BASE_MANA: int = 1
const MAGE_MANA_BONUS: int = 5

const STATS: Array[String] = ["damage", "block", "healing", "vampirism", "plating", "ward", "poison", "burn", "mana", "stamina", "curse", "thorns", "cleanse", "slow", "pierce", "doom", "spark", "physical_resistance", "magical_resistance"]
const ROSTER: Array[String] = ["rusty_knife", "cracked_shield", "blood_gem", "bandage", "longsword", "tower_shield", "cursed_idol", "iron_charm", "shortbow", "quiver", "buckler", "ember_tome", "frost_wand", "spark_ring", "venom_dagger", "vampire_fang", "plate_mail", "thorn_mail", "warding_sigil", "hunting_trap", "battle_axe", "healing_herbs", "hourglass", "mirror_shard", "antidote", "lightning_wand", "void_tome", "venom_orb"]
const ELEMENTAL_ITEMS: Dictionary = {
	"lightning_wand": {"name": "Storm Wand", "template": "frost_wand", "damage": 4, "cost": 2, "element": "lightning", "spark": 1},
	"void_tome": {"name": "Void Grimoire", "template": "ember_tome", "damage": 6, "cost": 3, "element": "void", "doom": 1},
	"venom_orb": {"name": "Venom Codex", "template": "ember_tome", "damage": 3, "cost": 2, "element": "venom", "poison": 2}
}
const RELICS: Array[String] = ["diagonal_thread", "returning_guard", "blood_pact", "plague_seal", "echo_clock", "arcane_barter", "folded_space", "mana_furnace", "last_thread"]

static func classes() -> Dictionary:
	return {
		"warrior": {"name": "Warmonger", "hp": 40, "icon": "longsword", "mechanic": "Momentum", "detail": "Start each fight with 0 Momentum. Gain 1 after each completed exchange with the enemy. Momentum accumulates until spent and resets for the next fight. Equipment bonuses and spending effects are not yet assigned.", "starters": ["longsword", "cracked_shield", "iron_charm"], "positions": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]},
		"ranger": {"name": "Bowmaster", "hp": 32, "icon": "shortbow", "mechanic": "Volley", "detail": "Volley fires arrows from the Bowmaster's Quiver every 3 rounds. Choose starting arrows, then upgrade arrow capacity, tips and mechanisms through rewards. Bows attack normally; Volley costs no mana or stamina.", "starters": ["shortbow", "magnificent_quiver", "buckler"], "positions": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(3, 0)]},
		"mage": {"name": "Elementalist", "hp": 28, "icon": "ember_tome", "mechanic": "Elemental Reactions", "detail": "Elemental casts leave traces for 2 rounds. Combine traces to trigger Elemental Reactions and chain their effects. No innate stamina.", "starters": ["ember_tome", "frost_wand", "buckler"], "positions": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(3, 0)]},
		"assassin": {"name": "Assassin", "hp": 30, "icon": "venom_dagger", "mechanic": "Shadowstep", "detail": "Invisible on turns 1, 4, 7... Monsters cannot target you: skip all strikes and on-hit effects. Existing poison, reflection and item costs still apply.", "starters": ["venom_dagger", "buckler", "bandage"], "positions": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(3, 0)]},
		"necromancer": {"name": "Necromancer", "hp": 28, "icon": "vampire_fang", "mechanic": "Raise Dead", "detail": "Start with one bone thrall. Defeated monsters raise another, up to 3. Each adds 2 direct damage per turn before block absorption. Thralls persist between floors.", "starters": ["spark_ring", "ember_tome", "vampire_fang"], "positions": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 0)]}
	}

static func base_resources(key: String) -> Dictionary:
	return {"mana": BASE_MANA + (MAGE_MANA_BONUS if key == "mage" else 0), "stamina": 0 if key == "mage" else BASE_STAMINA, "block": 0}

static func innate_stats(key: String) -> Array[Dictionary]:
	var character: Dictionary = classes()[key]
	var resources: Dictionary = base_resources(key)
	var result: Array[Dictionary] = [{"key": "health", "value": int(character["hp"])}]
	for stat: String in ["mana", "stamina", "block"]:
		if int(resources[stat]) > 0:
			result.append({"key": stat, "value": int(resources[stat])})
	return result

static func item(key: String) -> Dictionary:
	if ELEMENTAL_ITEMS.has(key):
		var extension: Dictionary = ELEMENTAL_ITEMS[key]
		var spell: Dictionary = item(extension["template"])
		for stat: String in STATS:
			spell[stat] = 0
		spell.merge(extension, true)
		spell["key"] = key
		spell["detail"] = ""
		spell["tooltip_detail"] = ""
		return spell
	if key == QUIVER.KEY or QUIVER.OPTIONS.has(key):
		var special: Dictionary = item("quiver")
		special["key"] = key
		if key == QUIVER.KEY:
			special["name"] = "Bowmaster's Quiver"
			special["role"] = "quiver"
			special["arrow_type"] = ""
			special["upgrades"] = {}
			special["detail"] = QUIVER.describe(special, 3)
		else:
			special.merge(QUIVER.OPTIONS[key], true)
			special["role"] = "upgrade"
		special["tooltip_detail"] = special["detail"]
		return special
	var data: Dictionary = {
		"rusty_knife": ["Rusty Knife", "weapon", ["#"], {"damage": 4}, "Deals 4 damage."],
		"cracked_shield": ["Cracked Shield", "shield", ["#"], {"block": 5}, "Starts each fight with 5 block. Spent block does not regenerate."],
		"blood_gem": ["Blood Gem", "booster", ["#"], {}, "Touching weapons, bows and spells gain +2 damage."],
		"bandage": ["Grave Bandage", "healer", ["#"], {"healing": 2}, "Regenerates 2 HP each turn."],
		# Legacy keys retain their effects and references; these basic items now occupy one cell.
		"longsword": ["Iron Dagger", "weapon", ["#"], {"damage": 8}, "Deals 8 damage."],
		"tower_shield": ["Shield Relic", "shield", ["#"], {"block": 9}, "Starts each fight with 9 block. Spent block does not regenerate."],
		"cursed_idol": ["Cursed Idol", "booster", ["#"], {"curse": 1}, "Touching attacks gain +3 damage; shields gain +3 block. Costs 1 HP each turn; ward absorbs this cost."],
		"iron_charm": ["Iron Charm", "booster", ["#"], {"stamina": 1}, "Touching shields gain +3 block."],
		"shortbow": ["Ashwood Bow", "ranged", ["#.", "##"], {"damage": 5}, "Deals 5 ranged damage."],
		"quiver": ["Hunting Quiver", "booster", ["#", "#"], {}, "Touching ranged weapons gain +2 damage per activation."],
		"buckler": ["Buckler", "shield", ["#"], {"block": 4, "thorns": 1}, "Starts each fight with 4 block. Reflects 1 damage for each enemy strike."],
		"ember_tome": ["Ember Grimoire", "spell", ["##", "#."], {"damage": 10, "burn": 2, "cost": 3}, "Costs 3 mana: 10 damage and 2 burn. Burn ticks each turn and decays by 1."],
		"frost_wand": ["Frost Wand", "spell", ["#", "#", "#"], {"damage": 8, "slow": 2, "cost": 2}, "Costs 2 mana: 8 damage and reduces each enemy strike by 2 this turn."],
		"spark_ring": ["Spark Ring", "focus", ["#"], {"mana": 2}, "+2 maximum mana. Mana refills each round."],
		"venom_dagger": ["Venom Dagger", "weapon", ["##", ".#"], {"damage": 5, "poison": 3, "pierce": 2}, "5 damage, 3 poison and 2 block piercing. Poison ticks each turn and decays by 1."],
		"vampire_fang": ["Vampire Fang", "weapon", ["#", "#"], {"damage": 5, "vampirism": 2}, "5 damage. Recover up to 2 HP from direct damage dealt, even on a killing blow."],
		"plate_mail": ["Iron Plate", "armor", ["###", ".#."], {"plating": 2}, "Plating reduces every enemy strike by 2 before block. Particularly useful against multiple hits."],
		"thorn_mail": ["Briar Mail", "shield", ["##", "##"], {"block": 3, "thorns": 3}, "Starts each fight with 3 block; 3 piercing retaliation damage per enemy strike."],
		"warding_sigil": ["Warding Sigil", "focus", [".#.", "###", ".#."], {"ward": 4}, "4 ward each turn absorbs curse, poison and reflected damage. Does not absorb ordinary attacks."],
		"hunting_trap": ["Venom Trap", "ranged", ["#.#", "###"], {"poison": 4, "slow": 1}, "Adds 4 poison and slows enemy strikes by 1."],
		"battle_axe": ["Executioner's Axe", "weapon", ["###", ".#."], {"damage": 13}, "Deals 13 damage. Its open corners can hold other items."],
		"healing_herbs": ["Moonleaf Herbs", "healer", ["#.", "##"], {"healing": 4}, "Regenerates 4 HP each turn."],
		"hourglass": ["Battle Hourglass", "utility", [".##", "##."], {}, "Every fourth turn, ordinary melee weapons activate twice. Stacks with Echo Clock."],
		"mirror_shard": ["Mirror Shard", "utility", ["##", ".#"], {}, "Copies half the base damage and block of the strongest touching item. Does not copy other mirrors or bonuses."],
		"antidote": ["Antidote Flask", "healer", ["#"], {"cleanse": 3, "healing": 1}, "Removes 3 poison before it ticks and restores 1 HP each turn."]
	}
	var entry: Array = data[key]
	var offsets: Array[Vector2i] = []
	var rows: Array = entry[2]
	for y in range(rows.size()):
		for x in range(str(rows[y]).length()):
			if str(rows[y])[x] == "#":
				offsets.append(Vector2i(x, y))
	var result: Dictionary = {"key": key, "name": entry[0], "role": entry[1], "mask": offsets, "rotation": 0, "shape": Vector2i(str(rows[0]).length(), rows.size()), "detail": entry[4], "cost": 0, "stamina_cost": 0, "priority": 0, "mana_per_round": 0, "stamina_per_round": 0, "block_per_round": 0}
	for stat in STATS:
		result[stat] = 0
	result.merge(entry[3], true)
	result["damage_type"] = "magical" if result["role"] == "spell" else "physical"
	result["element"] = {"ember_tome": "fire", "frost_wand": "frost"}.get(key, "")
	var stamina_costs: Dictionary = {"rusty_knife": 0, "longsword": 2, "shortbow": 2, "venom_dagger": 1, "vampire_fang": 1, "hunting_trap": 1, "battle_axe": 3}
	result["stamina_cost"] = int(stamina_costs.get(key, 0))
	# Tooltip lists own ordinary numeric effects. Keep only item-specific rules below.
	var tooltip_rules: Dictionary = {
		"shortbow": "",
		"hunting_trap": "",
		"battle_axe": "Its open corners can hold other items."
	}
	var list_only: Array[String] = ["rusty_knife", "cracked_shield", "bandage", "longsword", "tower_shield", "buckler", "ember_tome", "frost_wand", "spark_ring", "venom_dagger", "vampire_fang", "plate_mail", "thorn_mail", "warding_sigil", "healing_herbs", "antidote"]
	result["tooltip_detail"] = "" if key in list_only else str(tooltip_rules.get(key, result["detail"]))

	return result

static func relic(key: String) -> Dictionary:
	var data: Dictionary = {
		"diagonal_thread": ["Diagonal Thread", "diagonal_thread", "Boosters and mirrors also connect across diagonals. Build clusters around corners."],
		"returning_guard": ["Returning Guard", "returning_guard", "Unused block already carries in full for every champion. This relic currently adds no extra effect; block resets between floors."],
		"blood_pact": ["Blood Pact", "blood_pact", "Excess regeneration becomes direct damage instead of being wasted at full health."],
		"plague_seal": ["Plague Seal", "plague_seal", "Poison on enemies no longer decays. Enemy cleansing can still remove it."],
		"echo_clock": ["Echo Clock", "echo_clock", "Every third round: repeat strongest active attack, no extra mana cost. Adjacency counts; ties use reading order."],
		"arcane_barter": ["Arcane Barter", "arcane_barter", "Spells with insufficient mana spend 1 HP per missing mana. This cost bypasses ward and can be lethal."],
		"folded_space": ["Folded Space", "folded_space", "The left and right edges of the backpack touch. Bonuses can connect across the seam."],
		"mana_furnace": ["Mana Furnace", "mana_furnace", "After spells activate, all remaining mana becomes block at 2 block per mana. No mana is retained.", [{"key": "block", "value": 2, "qualifier": "per remaining mana, after spells"}]],
		"last_thread": ["Last Thread", "last_thread", "Once per run, lethal damage instead restores 8 HP and unpacks your largest item. It can be packed again.", [{"key": "healing", "value": 8, "qualifier": "once, on lethal damage"}]]
	}
	var entry: Array = data[key]
	return {"key": key, "name": entry[0], "icon": entry[1], "detail": entry[2], "keyword_stats": entry[3] if entry.size() > 3 else []}

static func enemies() -> Array[Dictionary]:
	var data: Array = [
		["ash_rat", "Ash Rat", 20, [5], "Gnaw", {}, "A steady single strike."],
		["bone_thief", "Bone Thief", 28, [3], "Twin knives", {"hits": 2}, "Strikes twice. Block is shared between both hits."],
		["lantern_wretch", "Lantern Wretch", 34, [6], "Scorch", {"pierce": 2}, "2 damage from each strike bypasses block."],
		["iron_mite", "Iron Mite", 40, [7], "Shell bash", {"armor": 3}, "Starts with 3 block. Absorbed damage depletes it."],
		["pack_leech", "Pack Leech", 44, [7], "Drain", {"drain": 3}, "Heals 3 HP if its attacks hurt you."],
		["mire_viper", "Mire Viper", 48, [7], "Toxic bite", {"poison": 2}, "Adds 2 poison when an attack hurts you."],
		["bell_sentinel", "Bell Sentinel", 56, [0, 15], "Charge / Slam", {}, "Alternates a harmless charge and a heavy slam."],
		["mirror_wisp", "Mirror Wisp", 50, [8], "Reflection", {"reflect": 2}, "Reflects 2 damage when hit directly. Ward absorbs reflection."],
		["rust_knight", "Rust Knight", 62, [10], "Corrode", {"sunder": 3}, "Destroys 3 of your generated block before attacking."],
		["crypt_butcher", "Crypt Butcher", 70, [10], "Rising fury", {"enrage": 1}, "Gains 1 attack for each elapsed turn."],
		["hollow_monk", "Hollow Monk", 76, [10], "Mend", {"regen": 5}, "Regenerates 5 HP after surviving your turn."],
		["carrion_swarm", "Carrion Swarm", 72, [4], "Swarm", {"hits": 3}, "Strikes three times. Plating reduces each strike."],
		["glass_duelist", "Glass Duelist", 82, [11], "Parry", {"parry": 8}, "Restores 8 block for every third turn. Unused block expires after that turn."],
		["cinder_oracle", "Cinder Oracle", 88, [11], "Cinder lance", {"pierce": 4}, "4 damage from each strike bypasses block."],
		["grave_keeper", "Grave Keeper", 98, [12], "Sealed gate", {"opening_armor": 7}, "Starts with 7 block. Absorbed damage depletes it; any remainder expires after turn two."],
		["iron_matron", "Iron Matron", 102, [7], "Twin hammers", {"armor": 3, "hits": 2}, "Starts with 3 block and strikes twice each turn."],
		["clockwork_warden", "Clockwork Warden", 112, [6, 17], "Guard / Strike", {"cycle_armor": 8}, "Restores 8 block for each odd turn. The block expires before a heavy strike on even turns."],
		["blood_collector", "Blood Collector", 118, [12], "Blood tithe", {"drain": 6, "enrage": 1}, "Heals 6 HP on a damaging hit. Attack rises each turn."],
		["oathbreaker", "Oathbreaker", 128, [12, 15], "Purify / Rend", {"cleanse": 3}, "Removes existing conditions and elemental traces at the start of every third turn."],
		["zippered_maw", "The Zippered Maw", 170, [13, 21], "Bite / Rend", {"armor": 3}, "Starts with 3 block. Alternates a bite and a devastating rend."]
	]
	var result: Array[Dictionary] = []
	for entry in data:
		var enemy: Dictionary = {"key": entry[0], "name": entry[1], "hp": entry[2], "attacks": entry[3], "intent": entry[4], "detail": entry[6], "hits": 1, "armor": 0, "pierce": 0, "poison": 0, "drain": 0, "reflect": 0, "sunder": 0, "enrage": 0, "regen": 0, "parry": 0, "opening_armor": 0, "cycle_armor": 0, "cleanse": 0}
		enemy.merge(entry[5], true)
		enemy["physical_resistance"] = {"iron_mite": 20, "rust_knight": 25, "iron_matron": 20, "zippered_maw": 15}.get(enemy["key"], 0)
		enemy["magical_resistance"] = {"mirror_wisp": 35, "cinder_oracle": 25, "oathbreaker": 20, "zippered_maw": 15}.get(enemy["key"], 0)
		result.append(enemy)
	return result
