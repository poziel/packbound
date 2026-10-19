class_name ExpansionRelics
extends RefCounted

static func relics() -> Dictionary:
	return DEFINITIONS.duplicate(true)

static func _context(run: Variant, stats: Dictionary) -> Dictionary:
	var weapons: int = 0
	var spells: int = 0
	var shields: int = 0
	var companions: int = int(run.undead_companions) if run.class_key == "necromancer" else 0
	var cells: int = 0
	var packed: Array = run.packed()
	for item: Dictionary in packed:
		if not run.item_enabled(item):
			continue
		weapons += 1 if item.get("role") == "weapon" else 0
		spells += 1 if item.get("role") == "spell" else 0
		shields += 1 if item.get("role") == "shield" else 0
		companions += 1 if item.get("role") == "companion" else 0
		cells += item.get("mask", []).size()
	return {"one": 1, "crafted_count": run.crafting_events.size(), "weapon_count": weapons, "spell_count": spells, "shield_count": shields,
		"companion_count": companions, "item_count": _enabled_count(run, packed), "cells": cells,
		"momentum": maxi(0, int(run.momentum)), "reaction_count": stats.get("reactions", []).size(),
		"unused_mana": maxi(0, int(stats.get("mana_after", 0))), "unused_stamina": maxi(0, int(stats.get("stamina_after", 0))),
		"spark": maxi(0, int(run.enemy_spark)), "slow": maxi(0, int(run.enemy_slow)), "doom": maxi(0, int(run.enemy_doom))}

static func _enabled_count(run: Variant, packed: Array) -> int:
	var count: int = 0
	for item: Dictionary in packed:
		if run.item_enabled(item):
			count += 1
	return count

static func _matches(condition: String, run: Variant, stats: Dictionary, context: Dictionary) -> bool:
	match condition:
		"always": return true
		"opening": return run.turn == 1
		"crafted_opening": return run.turn == 1 and context["crafted_count"] > 0
		"low_hp": return int(run.hp) * 2 <= int(run.max_hp)
		"has_weapon": return context["weapon_count"] > 0
		"has_spell": return context["spell_count"] > 0
		"has_shield": return context["shield_count"] > 0
		"sparse": return context["item_count"] <= 4
		"late": return run.turn >= 4
		"warrior": return run.class_key == "warrior"
		"volley": return int(stats.get("volley_damage", 0)) > 0
		"burning": return run.enemy_burn > 0
		"poisoned": return run.enemy_poison > 0
		"even": return run.turn % 2 == 0
		"odd": return run.turn % 2 == 1
		"companions": return context["companion_count"] > 0
		"has_magic": return int(stats.get("magical_damage", 0)) > 0
		"no_stamina_spent": return int(stats.get("stamina_spent", 0)) == 0
		"reactions": return context["reaction_count"] > 0
		"many_items": return context["item_count"] >= 8
		"single_weapon": return context["weapon_count"] == 1
		"unused_mana": return context["unused_mana"] > 0
		"sparked": return run.enemy_spark > 0
		"slowed": return run.enemy_slow > 0
		"doomed": return run.enemy_doom > 0
		"both_damage": return int(stats.get("physical_damage", 0)) > 0 and int(stats.get("magical_damage", 0)) > 0
		"unused_stamina": return context["unused_stamina"] > 0
		"poison_and_burn": return run.enemy_poison > 0 and run.enemy_burn > 0
		"third": return run.turn % 3 == 0
		"no_weapon": return context["weapon_count"] == 0
		"cursed": return int(stats.get("curse", 0)) > 0
		"dense": return context["cells"] >= 20
		"enemy_low_hp": return int(run.enemy.get("hp", 0)) * 3 <= int(run.enemy.get("max_hp", 1))
		"high_block": return int(stats.get("block", 0)) >= 10
		"no_damage": return int(stats.get("damage", 0)) == 0
	return false

static func resource_bonus(run: Variant, resource: String) -> int:
	var context: Dictionary = _context(run, {})
	var amount: int = 0
	for key: String in run.relics:
		if not DEFINITIONS.has(key):
			continue
		var rule: Dictionary = DEFINITIONS[key]["rule"]
		if rule["stat"] == resource + "_resource" and _matches(rule["condition"], run, {}, context):
			amount += int(rule["amount"]) * mini(int(rule["cap"]), int(context.get(rule["metric"], 0)))
	return amount

static func apply_stats(run: Variant, result: Dictionary) -> void:
	var snapshot: Dictionary = result.duplicate(true)
	var context: Dictionary = _context(run, snapshot)
	for key: String in run.relics:
		if not DEFINITIONS.has(key):
			continue
		var definition: Dictionary = DEFINITIONS[key]
		var rule: Dictionary = definition["rule"]
		var stat: String = rule["stat"]
		if stat.ends_with("_resource") or not _matches(rule["condition"], run, snapshot, context):
			continue
		var gain: int = int(rule["amount"]) * mini(int(rule["cap"]), int(context.get(rule["metric"], 0)))
		if gain <= 0:
			continue
		result[stat] = int(result.get(stat, 0)) + gain
		if stat in ["physical_damage", "magical_damage"]:
			result["damage"] = int(result.get("damage", 0)) + gain
		if stat == "block":
			result["block_gained"] = int(result.get("block_gained", 0)) + gain
		result["activation_events"].append("%s grants +%d %s." % [definition["name"], gain, stat.replace("_", " ")])

## Pure additive rules; all conditions use a pre-relic snapshot.
const DEFINITIONS: Dictionary = {
  "tin_cricket": {
    "key": "tin_cricket",
    "name": "Tin Cricket",
    "icon": "tin_cricket",
    "rarity": "common",
    "detail": "Every round: gain +1 ward.",
    "stats": {},
        "rule": {
          "condition": "always",
          "stat": "ward",
          "amount": 1,
          "metric": "one",
          "cap": 1
        }
  },
  "second_breakfast": {
    "key": "second_breakfast",
    "name": "Second Breakfast",
    "icon": "second_breakfast",
    "rarity": "common",
    "detail": "On the first round of each fight: gain +3 healing.",
    "stats": {},
        "rule": {
          "condition": "opening",
          "stat": "healing",
          "amount": 3,
          "metric": "one",
          "cap": 1
        }
  },
  "rust_psalm": {
    "key": "rust_psalm",
    "name": "Rust Psalm",
    "icon": "rust_psalm",
    "rarity": "common",
    "detail": "With at least one packed melee weapon: gain +1 pierce per weapon count (up to 3 counted).",
    "stats": {},
        "rule": {
          "condition": "has_weapon",
          "stat": "pierce",
          "amount": 1,
          "metric": "weapon_count",
          "cap": 3
        }
  },
  "pocket_hearth": {
    "key": "pocket_hearth",
    "name": "Pocket Hearth",
    "icon": "pocket_hearth",
    "rarity": "common",
    "detail": "When current HP is at most half maximum HP before activations: gain +1 healing.",
    "stats": {},
        "rule": {
          "condition": "low_hp",
          "stat": "healing",
          "amount": 1,
          "metric": "one",
          "cap": 1
        }
  },
  "rain_button": {
    "key": "rain_button",
    "name": "Rain Button",
    "icon": "rain_button",
    "rarity": "common",
    "detail": "With at least one packed spell: gain +1 ward per spell count (up to 3 counted).",
    "stats": {},
        "rule": {
          "condition": "has_spell",
          "stat": "ward",
          "amount": 1,
          "metric": "spell_count",
          "cap": 3
        }
  },
  "hedgehog_penny": {
    "key": "hedgehog_penny",
    "name": "Hedgehog Penny",
    "icon": "hedgehog_penny",
    "rarity": "common",
    "detail": "With at least one packed shield: gain +1 thorns.",
    "stats": {},
        "rule": {
          "condition": "has_shield",
          "stat": "thorns",
          "amount": 1,
          "metric": "one",
          "cap": 1
        }
  },
  "last_seat": {
    "key": "last_seat",
    "name": "Last Seat",
    "icon": "last_seat",
    "rarity": "common",
    "detail": "With at most four packed items: gain +2 block. Block is added each round.",
    "stats": {},
        "rule": {
          "condition": "sparse",
          "stat": "block",
          "amount": 2,
          "metric": "one",
          "cap": 1
        }
  },
  "pilgrim_sock": {
    "key": "pilgrim_sock",
    "name": "Pilgrim Sock",
    "icon": "pilgrim_sock",
    "rarity": "common",
    "detail": "From round four onward: gain +1 stamina. Increases the round refill budget.",
    "stats": {},
        "rule": {
          "condition": "late",
          "stat": "stamina_resource",
          "amount": 1,
          "metric": "one",
          "cap": 1
        }
  },
  "ram_flywheel": {
    "classes": ["warrior"],
    "key": "ram_flywheel",
    "name": "Ram Flywheel",
    "icon": "ram_flywheel",
    "rarity": "uncommon",
    "detail": "For the Warmonger: gain +1 physical damage per momentum (up to 6 counted).",
    "stats": {},
        "rule": {
          "condition": "warrior",
          "stat": "physical_damage",
          "amount": 1,
          "metric": "momentum",
          "cap": 6
        }
  },
  "arrow_rosary": {
    "key": "arrow_rosary",
    "name": "Arrow Rosary",
    "icon": "arrow_rosary",
    "rarity": "uncommon",
    "detail": "When Volley fires this round: gain +3 pierce.",
    "stats": {},
        "rule": {
          "condition": "volley",
          "stat": "pierce",
          "amount": 3,
          "metric": "one",
          "cap": 1
        }
  },
  "cinder_nursery": {
    "key": "cinder_nursery",
    "name": "Cinder Nursery",
    "icon": "cinder_nursery",
    "rarity": "uncommon",
    "detail": "When the enemy already has Burn before activations: gain +2 healing.",
    "stats": {},
        "rule": {
          "condition": "burning",
          "stat": "healing",
          "amount": 2,
          "metric": "one",
          "cap": 1
        }
  },
  "venom_thesis": {
    "key": "venom_thesis",
    "name": "Venom Thesis",
    "icon": "venom_thesis",
    "rarity": "uncommon",
    "detail": "When the enemy already has Poison before activations: gain +2 magical damage.",
    "stats": {},
        "rule": {
          "condition": "poisoned",
          "stat": "magical_damage",
          "amount": 2,
          "metric": "one",
          "cap": 1
        }
  },
  "broken_metronome": {
    "key": "broken_metronome",
    "name": "Broken Metronome",
    "icon": "broken_metronome",
    "rarity": "uncommon",
    "detail": "On even numbered rounds: gain +3 block. Block is added each round.",
    "stats": {},
        "rule": {
          "condition": "even",
          "stat": "block",
          "amount": 3,
          "metric": "one",
          "cap": 1
        }
  },
  "grave_bell": {
    "key": "grave_bell",
    "name": "Grave Bell",
    "icon": "grave_bell",
    "rarity": "uncommon",
    "detail": "With at least one companion (bone thralls and packed companion items count): gain +1 ward per companion count (up to 4 counted).",
    "stats": {},
        "rule": {
          "condition": "companions",
          "stat": "ward",
          "amount": 1,
          "metric": "companion_count",
          "cap": 4
        }
  },
  "lantern_moth": {
    "key": "lantern_moth",
    "name": "Lantern Moth",
    "icon": "lantern_moth",
    "rarity": "uncommon",
    "detail": "When activations produced magical damage: gain +2 cleanse.",
    "stats": {},
        "rule": {
          "condition": "has_magic",
          "stat": "cleanse",
          "amount": 2,
          "metric": "one",
          "cap": 1
        }
  },
  "anchor_feather": {
    "key": "anchor_feather",
    "name": "Anchor Feather",
    "icon": "anchor_feather",
    "rarity": "uncommon",
    "detail": "When no stamina was spent on activations: gain +1 plating.",
    "stats": {},
        "rule": {
          "condition": "no_stamina_spent",
          "stat": "plating",
          "amount": 1,
          "metric": "one",
          "cap": 1
        }
  },
  "glass_orchard": {
    "key": "glass_orchard",
    "name": "Glass Orchard",
    "icon": "glass_orchard",
    "rarity": "uncommon",
    "detail": "When an Elemental Reaction occurs this round: gain +1 healing per reaction count (up to 3 counted).",
    "stats": {},
        "rule": {
          "condition": "reactions",
          "stat": "healing",
          "amount": 1,
          "metric": "reaction_count",
          "cap": 3
        }
  },
  "tailor_moon": {
    "key": "tailor_moon",
    "name": "Tailor Moon",
    "icon": "tailor_moon",
    "rarity": "uncommon",
    "detail": "With at least eight packed items: gain +3 ward.",
    "stats": {},
        "rule": {
          "condition": "many_items",
          "stat": "ward",
          "amount": 3,
          "metric": "one",
          "cap": 1
        }
  },
  "duelist_receipt": {
    "key": "duelist_receipt",
    "name": "Duelist Receipt",
    "icon": "duelist_receipt",
    "rarity": "uncommon",
    "detail": "On the opening round, gain +4 physical damage per recipe completed at this fight start, counting at most 3 recipes.",
    "stats": {},
        "rule": {
          "condition": "crafted_opening",
          "stat": "physical_damage",
          "amount": 4,
          "metric": "crafted_count",
          "cap": 3
        }
  },
  "quiet_inkwell": {
    "key": "quiet_inkwell",
    "name": "Quiet Inkwell",
    "icon": "quiet_inkwell",
    "rarity": "uncommon",
    "detail": "When mana remains after activations and Mana Furnace: gain +1 magical damage per unused mana (up to 4 counted).",
    "stats": {},
        "rule": {
          "condition": "unused_mana",
          "stat": "magical_damage",
          "amount": 1,
          "metric": "unused_mana",
          "cap": 4
        }
  },
  "siege_heart": {
    "classes": ["warrior"],
    "key": "siege_heart",
    "name": "Siege Heart",
    "icon": "siege_heart",
    "rarity": "rare",
    "detail": "For the Warmonger: gain +2 block per momentum (up to 8 counted). Block is added each round.",
    "stats": {},
        "rule": {
          "condition": "warrior",
          "stat": "block",
          "amount": 2,
          "metric": "momentum",
          "cap": 8
        }
  },
  "fletchers_eclipse": {
    "key": "fletchers_eclipse",
    "name": "Fletchers Eclipse",
    "icon": "fletchers_eclipse",
    "rarity": "rare",
    "detail": "When Volley fires this round: gain +5 physical damage.",
    "stats": {},
        "rule": {
          "condition": "volley",
          "stat": "physical_damage",
          "amount": 5,
          "metric": "one",
          "cap": 1
        }
  },
  "storm_census": {
    "key": "storm_census",
    "name": "Storm Census",
    "icon": "storm_census",
    "rarity": "rare",
    "detail": "When the enemy already has Spark before activations: gain +2 pierce per spark (up to 4 counted).",
    "stats": {},
        "rule": {
          "condition": "sparked",
          "stat": "pierce",
          "amount": 2,
          "metric": "spark",
          "cap": 4
        }
  },
  "winter_mortgage": {
    "key": "winter_mortgage",
    "name": "Winter Mortgage",
    "icon": "winter_mortgage",
    "rarity": "rare",
    "detail": "When the enemy already has Slow before activations: gain +2 ward per slow (up to 4 counted).",
    "stats": {},
        "rule": {
          "condition": "slowed",
          "stat": "ward",
          "amount": 2,
          "metric": "slow",
          "cap": 4
        }
  },
  "abyssal_hourhand": {
    "key": "abyssal_hourhand",
    "name": "Abyssal Hourhand",
    "icon": "abyssal_hourhand",
    "rarity": "rare",
    "detail": "When the enemy already has Doom before activations: gain +3 magical damage per doom (up to 3 counted).",
    "stats": {},
        "rule": {
          "condition": "doomed",
          "stat": "magical_damage",
          "amount": 3,
          "metric": "doom",
          "cap": 3
        }
  },
  "twin_sun_contract": {
    "key": "twin_sun_contract",
    "name": "Twin Sun Contract",
    "icon": "twin_sun_contract",
    "rarity": "rare",
    "detail": "When activations produced both physical and magical damage: gain +3 healing.",
    "stats": {},
        "rule": {
          "condition": "both_damage",
          "stat": "healing",
          "amount": 3,
          "metric": "one",
          "cap": 1
        }
  },
  "apiary_crown": {
    "key": "apiary_crown",
    "name": "Apiary Crown",
    "icon": "apiary_crown",
    "rarity": "rare",
    "detail": "With at least one companion (bone thralls and packed companion items count): gain +2 thorns per companion count (up to 4 counted).",
    "stats": {},
        "rule": {
          "condition": "companions",
          "stat": "thorns",
          "amount": 2,
          "metric": "companion_count",
          "cap": 4
        }
  },
  "scar_cartographer": {
    "key": "scar_cartographer",
    "name": "Scar Cartographer",
    "icon": "scar_cartographer",
    "rarity": "rare",
    "detail": "When current HP is at most half maximum HP before activations: gain +6 physical damage.",
    "stats": {},
        "rule": {
          "condition": "low_hp",
          "stat": "physical_damage",
          "amount": 6,
          "metric": "one",
          "cap": 1
        }
  },
  "unspent_thunder": {
    "key": "unspent_thunder",
    "name": "Unspent Thunder",
    "icon": "unspent_thunder",
    "rarity": "rare",
    "detail": "When stamina remains after activations: gain +2 block per unused stamina (up to 4 counted). Block is added each round.",
    "stats": {},
        "rule": {
          "condition": "unused_stamina",
          "stat": "block",
          "amount": 2,
          "metric": "unused_stamina",
          "cap": 4
        }
  },
  "amber_tribunal": {
    "key": "amber_tribunal",
    "name": "Amber Tribunal",
    "icon": "amber_tribunal",
    "rarity": "rare",
    "detail": "When the enemy already has both Poison and Burn before activations: gain +5 pierce.",
    "stats": {},
        "rule": {
          "condition": "poison_and_burn",
          "stat": "pierce",
          "amount": 5,
          "metric": "one",
          "cap": 1
        }
  },
  "thirteenth_tooth": {
    "key": "thirteenth_tooth",
    "name": "Thirteenth Tooth",
    "icon": "thirteenth_tooth",
    "rarity": "rare",
    "detail": "Every third round: gain +5 vampirism.",
    "stats": {},
        "rule": {
          "condition": "third",
          "stat": "vampirism",
          "amount": 5,
          "metric": "one",
          "cap": 1
        }
  },
  "backpack_cathedral": {
    "key": "backpack_cathedral",
    "name": "Backpack Cathedral",
    "icon": "backpack_cathedral",
    "rarity": "rare",
    "detail": "With at least eight packed items: gain +12 magical resistance.",
    "stats": {},
        "rule": {
          "condition": "many_items",
          "stat": "magical_resistance",
          "amount": 12,
          "metric": "one",
          "cap": 1
        }
  },
  "empty_scabbard": {
    "key": "empty_scabbard",
    "name": "Empty Scabbard",
    "icon": "empty_scabbard",
    "rarity": "rare",
    "detail": "With no packed melee weapons: gain +5 magical damage.",
    "stats": {},
        "rule": {
          "condition": "no_weapon",
          "stat": "magical_damage",
          "amount": 5,
          "metric": "one",
          "cap": 1
        }
  },
  "salt_bride": {
    "key": "salt_bride",
    "name": "Salt Bride",
    "icon": "salt_bride",
    "rarity": "rare",
    "detail": "When packed activations contribute Curse: gain +4 cleanse.",
    "stats": {},
        "rule": {
          "condition": "cursed",
          "stat": "cleanse",
          "amount": 4,
          "metric": "one",
          "cap": 1
        }
  },
  "world_beetle": {
    "key": "world_beetle",
    "name": "World Beetle",
    "icon": "world_beetle",
    "rarity": "epic",
    "detail": "With at least twenty occupied backpack cells: gain +2 plating.",
    "stats": {},
        "rule": {
          "condition": "dense",
          "stat": "plating",
          "amount": 2,
          "metric": "one",
          "cap": 1
        }
  },
  "revolution_spindle": {
    "classes": ["warrior"],
    "key": "revolution_spindle",
    "name": "Revolution Spindle",
    "icon": "revolution_spindle",
    "rarity": "epic",
    "detail": "For the Warmonger: gain +2 physical damage per momentum (up to 10 counted).",
    "stats": {},
        "rule": {
          "condition": "warrior",
          "stat": "physical_damage",
          "amount": 2,
          "metric": "momentum",
          "cap": 10
        }
  },
  "horizon_engine": {
    "key": "horizon_engine",
    "name": "Horizon Engine",
    "icon": "horizon_engine",
    "rarity": "epic",
    "detail": "When Volley fires this round: gain +5 burn.",
    "stats": {},
        "rule": {
          "condition": "volley",
          "stat": "burn",
          "amount": 5,
          "metric": "one",
          "cap": 1
        }
  },
  "prism_leviathan": {
    "key": "prism_leviathan",
    "name": "Prism Leviathan",
    "icon": "prism_leviathan",
    "rarity": "epic",
    "detail": "When an Elemental Reaction occurs this round: gain +5 magical damage per reaction count (up to 4 counted).",
    "stats": {},
        "rule": {
          "condition": "reactions",
          "stat": "magical_damage",
          "amount": 5,
          "metric": "reaction_count",
          "cap": 4
        }
  },
  "bone_parliament": {
    "key": "bone_parliament",
    "name": "Bone Parliament",
    "icon": "bone_parliament",
    "rarity": "epic",
    "detail": "With at least one companion (bone thralls and packed companion items count): gain +3 physical damage per companion count (up to 4 counted).",
    "stats": {},
        "rule": {
          "condition": "companions",
          "stat": "physical_damage",
          "amount": 3,
          "metric": "companion_count",
          "cap": 4
        }
  },
  "mercy_guillotine": {
    "key": "mercy_guillotine",
    "name": "Mercy Guillotine",
    "icon": "mercy_guillotine",
    "rarity": "epic",
    "detail": "When the enemy starts the round at or below one third maximum HP: gain +12 physical damage.",
    "stats": {},
        "rule": {
          "condition": "enemy_low_hp",
          "stat": "physical_damage",
          "amount": 12,
          "metric": "one",
          "cap": 1
        }
  },
  "walking_bastion": {
    "key": "walking_bastion",
    "name": "Walking Bastion",
    "icon": "walking_bastion",
    "rarity": "epic",
    "detail": "With at least ten block after activations: gain +20 physical resistance.",
    "stats": {},
        "rule": {
          "condition": "high_block",
          "stat": "physical_resistance",
          "amount": 20,
          "metric": "one",
          "cap": 1
        }
  },
  "mourning_volcano": {
    "key": "mourning_volcano",
    "name": "Mourning Volcano",
    "icon": "mourning_volcano",
    "rarity": "epic",
    "detail": "When current HP is at most half maximum HP before activations: gain +6 burn.",
    "stats": {},
        "rule": {
          "condition": "low_hp",
          "stat": "burn",
          "amount": 6,
          "metric": "one",
          "cap": 1
        }
  },
  "unwritten_saint": {
    "key": "unwritten_saint",
    "name": "Unwritten Saint",
    "icon": "unwritten_saint",
    "rarity": "epic",
    "detail": "When activations produced no direct damage: gain +7 healing.",
    "stats": {},
        "rule": {
          "condition": "no_damage",
          "stat": "healing",
          "amount": 7,
          "metric": "one",
          "cap": 1
        }
  },
  "copper_afterlife": {
    "key": "copper_afterlife",
    "name": "Copper Afterlife",
    "icon": "copper_afterlife",
    "rarity": "epic",
    "detail": "Every third round: gain +2 stamina. Increases the round refill budget.",
    "stats": {},
        "rule": {
          "condition": "third",
          "stat": "stamina_resource",
          "amount": 2,
          "metric": "one",
          "cap": 1
        }
  },
  "false_spring": {
    "key": "false_spring",
    "name": "False Spring",
    "icon": "false_spring",
    "rarity": "legendary",
    "detail": "On odd numbered rounds: gain +5 healing.",
    "stats": {},
        "rule": {
          "condition": "odd",
          "stat": "healing",
          "amount": 5,
          "metric": "one",
          "cap": 1
        }
  },
  "crown_of_the_unmade": {
    "key": "crown_of_the_unmade",
    "name": "Crown Of The Unmade",
    "icon": "crown_of_the_unmade",
    "rarity": "legendary",
    "detail": "When an Elemental Reaction occurs this round: gain +2 doom per reaction count (up to 4 counted).",
    "stats": {},
        "rule": {
          "condition": "reactions",
          "stat": "doom",
          "amount": 2,
          "metric": "reaction_count",
          "cap": 4
        }
  },
  "atlas_of_missing_roads": {
    "key": "atlas_of_missing_roads",
    "name": "Atlas Of Missing Roads",
    "icon": "atlas_of_missing_roads",
    "rarity": "legendary",
    "detail": "With at most four packed items: gain +14 physical damage.",
    "stats": {},
        "rule": {
          "condition": "sparse",
          "stat": "physical_damage",
          "amount": 14,
          "metric": "one",
          "cap": 1
        }
  },
  "thousand_arrow_funeral": {
    "key": "thousand_arrow_funeral",
    "name": "Thousand Arrow Funeral",
    "icon": "thousand_arrow_funeral",
    "rarity": "legendary",
    "detail": "When Volley fires this round: gain +9 poison.",
    "stats": {},
        "rule": {
          "condition": "volley",
          "stat": "poison",
          "amount": 9,
          "metric": "one",
          "cap": 1
        }
  },
  "heart_of_the_long_march": {
    "classes": ["warrior"],
    "key": "heart_of_the_long_march",
    "name": "Heart Of The Long March",
    "icon": "heart_of_the_long_march",
    "rarity": "legendary",
    "detail": "For the Warmonger: gain +1 healing per momentum (up to 8 counted).",
    "stats": {},
        "rule": {
          "condition": "warrior",
          "stat": "healing",
          "amount": 1,
          "metric": "momentum",
          "cap": 8
        }
  },
  "choir_beyond_the_door": {
    "key": "choir_beyond_the_door",
    "name": "Choir Beyond The Door",
    "icon": "choir_beyond_the_door",
    "rarity": "legendary",
    "detail": "With at least one companion (bone thralls and packed companion items count): gain +6 magical damage per companion count (up to 4 counted).",
    "stats": {},
        "rule": {
          "condition": "companions",
          "stat": "magical_damage",
          "amount": 6,
          "metric": "companion_count",
          "cap": 4
        }
  }
}
const RELIC_KEYS: Array = ["tin_cricket","second_breakfast","rust_psalm","pocket_hearth","rain_button","hedgehog_penny","last_seat","pilgrim_sock","ram_flywheel","arrow_rosary","cinder_nursery","venom_thesis","broken_metronome","grave_bell","lantern_moth","anchor_feather","glass_orchard","tailor_moon","duelist_receipt","quiet_inkwell","siege_heart","fletchers_eclipse","storm_census","winter_mortgage","abyssal_hourhand","twin_sun_contract","apiary_crown","scar_cartographer","unspent_thunder","amber_tribunal","thirteenth_tooth","backpack_cathedral","empty_scabbard","salt_bride","world_beetle","revolution_spindle","horizon_engine","prism_leviathan","bone_parliament","mercy_guillotine","walking_bastion","mourning_volcano","unwritten_saint","copper_afterlife","false_spring","crown_of_the_unmade","atlas_of_missing_roads","thousand_arrow_funeral","heart_of_the_long_march","choir_beyond_the_door"]

