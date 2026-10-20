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
	var result: Dictionary = {"one": 1, "crafted_count": run.crafting_events.size(), "weapon_count": weapons, "spell_count": spells, "shield_count": shields,
		"companion_count": companions, "item_count": _enabled_count(run, packed), "cells": cells,
		"momentum": maxi(0, int(run.momentum)), "reaction_count": stats.get("reactions", []).size(),
		"unused_mana": maxi(0, int(stats.get("mana_after", 0))), "unused_stamina": maxi(0, int(stats.get("stamina_after", 0))),
		"spark": maxi(0, int(run.enemy_spark)), "slow": maxi(0, int(run.enemy_slow)), "doom": maxi(0, int(run.enemy_doom))}
	result.merge({"hp": run.hp, "max_hp": run.max_hp, "enemy_hp": run.enemy.get("hp", 0), "enemy_max_hp": run.enemy.get("max_hp", 1), "class_id": run.class_key, "turn": run.turn, "volley_damage": stats.get("volley_damage", 0), "magical_damage": stats.get("magical_damage", 0), "physical_damage": stats.get("physical_damage", 0), "stamina_spent": stats.get("stamina_spent", 0), "burn": run.enemy_burn, "poison": run.enemy_poison, "curse": stats.get(GameplayTypes.Stat.CURSE, 0), "block": stats.get(GameplayTypes.Stat.BLOCK, 0), "damage": stats.get(GameplayTypes.Stat.DAMAGE, 0)})
	return result

static func _enabled_count(run: Variant, packed: Array) -> int:
	var count: int = 0
	for item: Dictionary in packed:
		if run.item_enabled(item):
			count += 1
	return count

static func resource_bonus(run: Variant, resource: int) -> int:
	var context: Dictionary = _context(run, {})
	var amount: int = 0
	for key: String in run.relics:
		var authored: CollectibleDefinition = CATEGORIES.definition_for_key(key)
		amount += int(CollectibleAbilityResolver.contributions(authored.abilities, CollectibleAbilityResolver.RESOURCE_TRIGGER, context).get(resource, 0))
	return amount

static func apply_stats(run: Variant, result: Dictionary) -> void:
	var snapshot: Dictionary = result.duplicate(true)
	var context: Dictionary = _context(run, snapshot)
	for key: String in run.relics:
		var authored: CollectibleDefinition = CATEGORIES.definition_for_key(key)
		var effect_context: Dictionary = context
		var grants: Dictionary = CollectibleAbilityResolver.contributions(authored.abilities, CollectibleAbilityResolver.RELIC_TRIGGER, effect_context)
		for granted_stat: Variant in grants:
			var grant_amount: int = grants[granted_stat]
			if grant_amount <= 0: continue
			result[granted_stat] = int(result.get(granted_stat, 0)) + grant_amount
			if granted_stat in ["physical_damage", "magical_damage"]:
				result[GameplayTypes.Stat.DAMAGE] += grant_amount
			if granted_stat is int and granted_stat == GameplayTypes.Stat.BLOCK:
				result["block_gained"] = int(result.get("block_gained", 0)) + grant_amount
			result["activation_events"].append("%s grants +%d %s." % [authored.display_name, grant_amount, (str(GameplayTypes.stat_id(granted_stat)) if granted_stat is int else str(granted_stat)).replace("_", " ")])

## Pure additive rules; all conditions use a pre-relic snapshot.
static var DEFINITIONS: Dictionary:
	get:
		var result: Dictionary = {}
		for key: String in RELIC_KEYS:
			result[key] = PackCatalog.relic(key)
		return result
const RELIC_KEYS: Array = ["tin_cricket","second_breakfast","rust_psalm","pocket_hearth","rain_button","hedgehog_penny","last_seat","pilgrim_sock","ram_flywheel","arrow_rosary","cinder_nursery","venom_thesis","broken_metronome","grave_bell","lantern_moth","anchor_feather","glass_orchard","tailor_moon","duelist_receipt","quiet_inkwell","siege_heart","fletchers_eclipse","storm_census","winter_mortgage","abyssal_hourhand","twin_sun_contract","apiary_crown","scar_cartographer","unspent_thunder","amber_tribunal","thirteenth_tooth","backpack_cathedral","empty_scabbard","salt_bride","world_beetle","revolution_spindle","horizon_engine","prism_leviathan","bone_parliament","mercy_guillotine","walking_bastion","mourning_volcano","unwritten_saint","copper_afterlife","false_spring","crown_of_the_unmade","atlas_of_missing_roads","thousand_arrow_funeral","heart_of_the_long_march","choir_beyond_the_door"]
