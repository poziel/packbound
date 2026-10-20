class_name CollectibleAbilityResolver
extends RefCounted
## Pure stat/status contributions for the existing combined-attack scheduler.
## StatusResolver applies stacks at the established combat phase, never here.
const ITEM_TRIGGER: StringName = &"item_activation"
const RELIC_TRIGGER: StringName = &"relic_stats"
const RESOURCE_TRIGGER: StringName = &"relic_resources"

static func validation_errors(ability: AbilityDefinition, trigger: StringName) -> PackedStringArray:
	if ability.trigger_id == &"quiver_loadout":
		var errors: PackedStringArray = ability.validation_errors()
		if trigger != ITEM_TRIGGER or not ability.conditions.is_empty(): errors.append("Quiver loadout effects require an unconditional item owner.")
		for effect: EffectDefinition in ability.effects:
			if not effect is QuiverVolleyEffectDefinition: errors.append("Unsupported quiver loadout effect.")
		return errors
	if ability.trigger_id in [&"item_adjacency", &"item_quiver", &"item_momentum"]:
		return item_validation_errors(ability, trigger)
	if ability.trigger_id in [&"item_mechanic", &"relic_mechanic"]:
		return mechanic_validation_errors(ability, trigger)
	var errors: PackedStringArray = ability.validation_errors()
	if ability.trigger_id != trigger and not (trigger == RELIC_TRIGGER and ability.trigger_id == RESOURCE_TRIGGER): errors.append("Ability uses an unsupported collectible trigger.")
	for condition: ConditionDefinition in ability.conditions:
		if not (condition is CombatMetricConditionDefinition or condition is ClassConditionDefinition) or trigger != RELIC_TRIGGER:
			errors.append("Unsupported collectible combat condition.")
	for effect: EffectDefinition in ability.effects:
		if effect is GrantDamageEffectDefinition:
			if trigger != RELIC_TRIGGER or ability.trigger_id != RELIC_TRIGGER: errors.append("Damage bonuses require relic_stats.")
			continue
		if effect is GrantResourceEffectDefinition:
			if trigger != RELIC_TRIGGER or ability.trigger_id != RESOURCE_TRIGGER: errors.append("Round resource bonuses require relic_resources.")
			continue
		if effect is GrantCombatStatEffectDefinition:
			if trigger != RELIC_TRIGGER or ability.trigger_id != RELIC_TRIGGER: errors.append("Combat stat grants currently require the relic_stats trigger.")
			continue
		if not effect is ApplyStatusEffectDefinition:
			errors.append("Unsupported collectible effect type.")
			continue
		if ability.trigger_id == RESOURCE_TRIGGER: errors.append("Status effects require a combat trigger.")
		if effect.status == null: continue
		if effect.target != ApplyStatusEffectDefinition.Target.OPPONENT:
			errors.append("Combined-attack status grants must target the opponent.")
		if not effect.status.id in [&"poison", &"burn", &"slow", &"spark", &"doom"]:
			errors.append("Unsupported collectible status.")
		if trigger == ITEM_TRIGGER and effect is ScaledApplyStatusEffectDefinition:
			errors.append("Item status grants do not support relic metric scaling.")
	return errors

static func contributions(abilities: Array[AbilityDefinition], trigger: StringName, context: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	for ability: AbilityDefinition in abilities:
		if ability == null or ability.trigger_id != trigger: continue
		var errors: PackedStringArray = validation_errors(ability, RELIC_TRIGGER if trigger == RESOURCE_TRIGGER else trigger)
		if not errors.is_empty():
			push_error("Invalid collectible combat ability: " + "; ".join(errors))
			continue
		var matches: bool = true
		for condition: ConditionDefinition in ability.conditions:
			matches = matches and condition.matches(context)
		if not matches: continue
		for effect: EffectDefinition in ability.effects:
			if effect is GrantDamageEffectDefinition or effect is GrantResourceEffectDefinition:
				var key: Variant = str(GameplayTypes.damage_type_id(effect.damage_type)) + "_damage" if effect is GrantDamageEffectDefinition else (GameplayTypes.Stat.MANA if effect.resource == GameplayTypes.ResourceType.MANA else GameplayTypes.Stat.STAMINA)
				var gain: int = effect.amount * (effect.scaling.amount(context) if effect.scaling != null else 1)
				result[key] = int(result.get(key, 0)) + gain
				continue
			if effect is GrantCombatStatEffectDefinition:
				result[effect.stat] = int(result.get(effect.stat, 0)) + effect.amount * (effect.scaling.amount(context) if effect.scaling != null else 1)
				continue
			var count: int = effect.applications(context) if effect is ScaledApplyStatusEffectDefinition else 1
			var stat: int = GameplayTypes.stat_from_id(effect.status.id)
			result[stat] = int(result.get(stat, 0)) + effect.stacks * count
	return result

static func item_validation_errors(ability: AbilityDefinition, owner_trigger: StringName) -> PackedStringArray:
	var errors: PackedStringArray = ability.validation_errors()
	if owner_trigger != ITEM_TRIGGER: errors.append("Item bonuses require an item owner.")
	if ability.trigger_id == &"item_momentum":
		if not ability.conditions.is_empty(): errors.append("Momentum bonuses do not support target conditions.")
		for effect: EffectDefinition in ability.effects:
			if not effect is ItemMomentumEffectDefinition: errors.append("Unsupported Momentum effect.")
	else:
		if ability.conditions.size() != 1 or not ability.conditions[0] is CollectibleTargetConditionDefinition:
			errors.append("An adjacency bonus requires one target condition.")
		if ability.effects.size() != 1: errors.append("An adjacency ability requires one bonus effect.")
		if ability.conditions.size() == 1 and ability.conditions[0] is CollectibleTargetConditionDefinition:
			var target: CollectibleTargetConditionDefinition = ability.conditions[0]
			if ability.trigger_id == &"item_quiver":
				if not target.category_ids.is_empty() or target.item_ids.size() != 1 or target.item_ids[0] != &"magnificent_quiver": errors.append("Quiver bonuses must target the permanent quiver.")
			elif not target.item_ids.is_empty() or target.category_ids.is_empty(): errors.append("Adjacency bonuses require category targets.")
		for effect: EffectDefinition in ability.effects:
			if not effect is GrantItemBonusEffectDefinition: errors.append("Unsupported adjacency effect.")
			elif ability.trigger_id == &"item_adjacency" and effect.arrows > 0: errors.append("Extra arrows require the quiver trigger.")
	return errors

static func item_views(abilities: Array[AbilityDefinition]) -> Dictionary:
	var result: Dictionary = {}
	for ability: AbilityDefinition in abilities:
		if ability.trigger_id == &"item_momentum":
			for effect: ItemMomentumEffectDefinition in ability.effects:
				if effect.gain > 0: result["momentum_gain"] = int(result.get("momentum_gain", 0)) + effect.gain
				if effect.damage_per_spent > 0: result["momentum_damage"] = int(result.get("momentum_damage", 0)) + effect.damage_per_spent
		elif ability.trigger_id in [&"item_adjacency", &"item_quiver"]:
			var condition: CollectibleTargetConditionDefinition = ability.conditions[0]
			for effect: GrantItemBonusEffectDefinition in ability.effects:
				var stats: Dictionary = effect.stats.duplicate()
				if ability.trigger_id == &"item_quiver":
					var bonuses: Dictionary = result.get("quiver_bonus", {})
					for stat: int in stats: bonuses[stat] = int(bonuses.get(stat, 0)) + stats[stat]
					if effect.arrows > 0: bonuses["arrows"] = int(bonuses.get("arrows", 0)) + effect.arrows
					result["quiver_bonus"] = bonuses
				elif effect.scope == GrantItemBonusEffectDefinition.Scope.PRIMARY_STAT:
					var bonuses: Array = result.get("primary_bonuses", [])
					bonuses.append({"target_category_ids": condition.category_ids.map(func(id): return str(id)), "stats": stats})
					result["primary_bonuses"] = bonuses
				else:
					result["adjacency_bonus"] = {"target_category_ids": condition.category_ids.map(func(id): return str(id)), "stats": stats}
	return result

static func mechanic_validation_errors(ability: AbilityDefinition, owner_trigger: StringName) -> PackedStringArray:
	var errors: PackedStringArray = ability.validation_errors()
	if ability.trigger_id != (&"item_mechanic" if owner_trigger == ITEM_TRIGGER else &"relic_mechanic"): errors.append("Mechanic trigger must match its owner.")
	for condition: ConditionDefinition in ability.conditions:
		if not condition is CombatMetricConditionDefinition or condition.metric != CombatMetricConditionDefinition.Metric.TURN: errors.append("Special mechanics currently support turn conditions only.")
	for effect: EffectDefinition in ability.effects:
		if not effect is CollectibleMechanicEffectDefinition: errors.append("Unsupported mechanic effect.")
	return errors
