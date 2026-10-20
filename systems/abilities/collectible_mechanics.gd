class_name CollectibleMechanics
extends RefCounted
## Shared lookup; callers own eligibility, timing and committed state.
const CATEGORIES = preload("res://systems/content/collectible_categories.gd")
static func effect(id: String, mechanic: CollectibleMechanicEffectDefinition.Mechanic, context: Dictionary = {}) -> CollectibleMechanicEffectDefinition:
	var owner: CollectibleDefinition = CATEGORIES.definition_for_key(id)
	if owner == null: return null
	for ability: AbilityDefinition in owner.abilities:
		if ability.trigger_id not in [&"item_mechanic", &"relic_mechanic"]: continue
		var matches: bool = true
		for condition: ConditionDefinition in ability.conditions:
			matches = matches and condition.matches(context)
		if not matches: continue
		for candidate: EffectDefinition in ability.effects:
			if candidate is CollectibleMechanicEffectDefinition and candidate.mechanic == mechanic: return candidate
	return null
