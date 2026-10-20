@tool
class_name RelicDefinition
extends CollectibleDefinition
## Authored relic data. Inherits identity, eligibility, categories, stats and
## abilities without backpack geometry or ordinary item activation costs.

func _combat_ability_trigger() -> StringName:
	return CollectibleAbilityResolver.RELIC_TRIGGER
