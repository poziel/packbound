class_name ExpansionRelics
extends RefCounted

const CATEGORIES = preload("res://systems/content/collectible_categories.gd")

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
		weapons += 1 if CATEGORIES.matches(item, &"melee_weapons") else 0
		spells += 1 if CATEGORIES.matches(item, &"magic_weapons") else 0
		shields += 1 if CATEGORIES.matches(item, &"shields") else 0
		companions += 1 if CATEGORIES.matches(item, &"companions") else 0
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
		"cursed": return int(stats.get(GameplayTypes.Stat.CURSE, 0)) > 0
		"dense": return context["cells"] >= 20
		"enemy_low_hp": return int(run.enemy.get("hp", 0)) * 3 <= int(run.enemy.get("max_hp", 1))
		"high_block": return int(stats.get(GameplayTypes.Stat.BLOCK, 0)) >= 10
		"no_damage": return int(stats.get(GameplayTypes.Stat.DAMAGE, 0)) == 0
	return false

static func resource_bonus(run: Variant, resource: int) -> int:
	var context: Dictionary = _context(run, {})
	var amount: int = 0
	for key: String in run.relics:
		if not PackCatalog.relic(key).has("rule"):
			continue
		var rule: Dictionary = PackCatalog.relic(key)["rule"]
		if bool(rule.get("resource_bonus", false)) and rule["stat"] == resource and _matches(rule["condition"], run, {}, context):
			amount += int(rule["amount"]) * mini(int(rule["cap"]), int(context.get(rule["metric"], 0)))
	return amount

static func apply_stats(run: Variant, result: Dictionary) -> void:
	var snapshot: Dictionary = result.duplicate(true)
	var context: Dictionary = _context(run, snapshot)
	for key: String in run.relics:
		var authored: CollectibleDefinition = CATEGORIES.definition_for_key(key)
		var effect_context: Dictionary = {"hp": run.hp, "max_hp": run.max_hp, "volley_damage": snapshot.get("volley_damage", 0), "reaction_count": context["reaction_count"]}
		var grants: Dictionary = CollectibleAbilityResolver.contributions(authored.abilities, CollectibleAbilityResolver.RELIC_TRIGGER, effect_context)
		for status_stat: int in grants:
			var status_gain: int = grants[status_stat]
			if status_gain <= 0: continue
			result[status_stat] = int(result.get(status_stat, 0)) + status_gain
			result["activation_events"].append("%s grants +%d %s." % [authored.display_name, status_gain, str(GameplayTypes.stat_id(status_stat)).replace("_", " ")])
		if not PackCatalog.relic(key).has("rule"):
			continue
		var definition: Dictionary = PackCatalog.relic(key)
		var rule: Dictionary = definition["rule"]
		var stat: Variant = rule["stat"]
		if bool(rule.get("resource_bonus", false)) or not _matches(rule["condition"], run, snapshot, context):
			continue
		var gain: int = int(rule["amount"]) * mini(int(rule["cap"]), int(context.get(rule["metric"], 0)))
		if gain <= 0:
			continue
		result[stat] = int(result.get(stat, 0)) + gain
		if stat in ["physical_damage", "magical_damage"]:
			result[GameplayTypes.Stat.DAMAGE] = int(result.get(GameplayTypes.Stat.DAMAGE, 0)) + gain
		if stat is int and stat == GameplayTypes.Stat.BLOCK:
			result["block_gained"] = int(result.get("block_gained", 0)) + gain
		result["activation_events"].append("%s grants +%d %s." % [definition["name"], gain, str(GameplayTypes.stat_id(stat)).replace("_", " ") if stat is int else stat.replace("_", " ")])

## Pure additive rules; all conditions use a pre-relic snapshot.
static var DEFINITIONS: Dictionary:
	get:
		var result: Dictionary = {}
		for key: String in RELIC_KEYS:
			result[key] = PackCatalog.relic(key)
		return result
const RELIC_KEYS: Array = ["tin_cricket","second_breakfast","rust_psalm","pocket_hearth","rain_button","hedgehog_penny","last_seat","pilgrim_sock","ram_flywheel","arrow_rosary","cinder_nursery","venom_thesis","broken_metronome","grave_bell","lantern_moth","anchor_feather","glass_orchard","tailor_moon","duelist_receipt","quiet_inkwell","siege_heart","fletchers_eclipse","storm_census","winter_mortgage","abyssal_hourhand","twin_sun_contract","apiary_crown","scar_cartographer","unspent_thunder","amber_tribunal","thirteenth_tooth","backpack_cathedral","empty_scabbard","salt_bride","world_beetle","revolution_spindle","horizon_engine","prism_leviathan","bone_parliament","mercy_guillotine","walking_bastion","mourning_volcano","unwritten_saint","copper_afterlife","false_spring","crown_of_the_unmade","atlas_of_missing_roads","thousand_arrow_funeral","heart_of_the_long_march","choir_beyond_the_door"]

