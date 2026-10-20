class_name CollectibleAbilityResolver
extends RefCounted
## Pure stat/status contributions for the existing combined-attack scheduler.
## StatusResolver applies stacks at the established combat phase, never here.
const ITEM_TRIGGER: StringName = &"item_activation"
const RELIC_TRIGGER: StringName = &"relic_stats"

static func validation_errors(ability: AbilityDefinition, trigger: StringName) -> PackedStringArray:
	var errors: PackedStringArray = ability.validation_errors()
	if ability.trigger_id != trigger: errors.append("Ability uses an unsupported collectible trigger.")
	for condition: ConditionDefinition in ability.conditions:
		if not condition is CombatMetricConditionDefinition or trigger != RELIC_TRIGGER:
			errors.append("Unsupported collectible combat condition.")
	for effect: EffectDefinition in ability.effects:
		if effect is GrantCombatStatEffectDefinition:
			if trigger != RELIC_TRIGGER: errors.append("Combat stat grants currently require the relic_stats trigger.")
			continue
		if not effect is ApplyStatusEffectDefinition:
			errors.append("Unsupported collectible effect type.")
			continue
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
		var errors: PackedStringArray = validation_errors(ability, trigger)
		if not errors.is_empty():
			push_error("Invalid collectible combat ability: " + "; ".join(errors))
			continue
		var matches: bool = true
		for condition: CombatMetricConditionDefinition in ability.conditions:
			matches = matches and condition.matches(context)
		if not matches: continue
		for effect: EffectDefinition in ability.effects:
			if effect is GrantCombatStatEffectDefinition:
				result[effect.stat] = int(result.get(effect.stat, 0)) + effect.amount
				continue
			var count: int = effect.applications(context) if effect is ScaledApplyStatusEffectDefinition else 1
			var stat: int = GameplayTypes.stat_from_id(effect.status.id)
			result[stat] = int(result.get(stat, 0)) + effect.stacks * count
	return result
