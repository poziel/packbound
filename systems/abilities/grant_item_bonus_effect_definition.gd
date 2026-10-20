@tool
class_name GrantItemBonusEffectDefinition
extends EffectDefinition
## Primary bonuses feed item_bonus; activation bonuses feed all authored stats.
enum Scope { ACTIVATION_STATS = 0, PRIMARY_STAT = 1 }
@export var scope: Scope = Scope.ACTIVATION_STATS
@export var stats: Dictionary[GameplayTypes.Stat, int] = {}
@export_range(0, 999, 1, "or_greater") var arrows: int = 0
func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not Scope.values().has(scope): errors.append("scope must be valid.")
	if stats.is_empty() and arrows <= 0: errors.append("An item bonus must grant stats or arrows.")
	if arrows < 0: errors.append("arrows must be nonnegative.")
	for stat: int in stats:
		if not GameplayTypes.Stat.values().has(stat) or stats[stat] <= 0: errors.append("Bonus stats require valid enums and positive amounts.")
		if scope == Scope.PRIMARY_STAT and stat not in [GameplayTypes.Stat.DAMAGE, GameplayTypes.Stat.BLOCK]: errors.append("Primary bonuses support damage and block only.")
	return errors

func _validate_property(property: Dictionary) -> void:
	if property.name in ["stats"]:
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = GameplayTypes.enum_dictionary_hint(GameplayTypes.Stat)
