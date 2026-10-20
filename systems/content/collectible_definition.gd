@tool
@abstract
class_name CollectibleDefinition
extends Resource
## Shared authored item/relic data. Treat definitions as read-only in gameplay.
## Live quantities, placement, cooldowns and other instance state belong elsewhere.

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = "":
	set(value):
		display_name = value
		resource_name = value
@export_multiline var description: String = ""
@export_multiline var lore: String = ""

@export_group("Classification")
@export var rarity: GameplayTypes.Rarity = GameplayTypes.Rarity.COMMON
@export var tags: Array[StringName] = []
## Optional shared category IDs. A catalog resolves ancestors and references.
@export var category_ids: Array[StringName] = []

@export_group("Eligibility")
## Empty means unrestricted. Entries within one list are alternatives.
@export var allowed_class_ids: Array[StringName] = []
## Both eligibility lists must match when both are populated.
@export var allowed_character_ids: Array[StringName] = []

@export_group("Offer Preferences")
## Optional soft affinities for reward weighting; empty means no preference.
## Never grants eligibility. A class and character match should boost only once.
@export var preferred_class_ids: Array[StringName] = []
@export var preferred_character_ids: Array[StringName] = []

@export_group("Presentation")
@export var icon: Texture2D

@export_group("Base Values")
## Ordinary authored values, not conditional effects or runtime aggregation rules.
@export var base_stats: Dictionary[GameplayTypes.Stat, int] = {}

@export_group("Abilities")
@export var abilities: Array[AbilityDefinition] = []

func _validate_property(property: Dictionary) -> void:
	if property.name == "base_stats":
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = GameplayTypes.enum_dictionary_hint(GameplayTypes.Stat)

## Intrinsic checks only; catalog-wide references are validated by their owner.
func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for field: String in ["id", "display_name"]:
		if str(get(field)).strip_edges().is_empty():
			errors.append("%s must not be blank." % field)
	if not GameplayTypes.Rarity.values().has(rarity):
		errors.append("rarity must be a valid GameplayTypes.Rarity value.")
	var seen: Dictionary[StringName, bool] = {}
	for field: String in ["preferred_class_ids", "preferred_character_ids"]:
		var preferred_ids: Array[StringName] = get(field)
		var seen_preferences: Dictionary[StringName, bool] = {}
		for index: int in range(preferred_ids.size()):
			var preferred_id: StringName = preferred_ids[index]
			if str(preferred_id).strip_edges().is_empty():
				errors.append("%s[%d] must not be blank." % [field, index])
			if seen_preferences.has(preferred_id):
				errors.append("%s[%d] duplicates preference ID %s." % [field, index, preferred_id])
			seen_preferences[preferred_id] = true
	for index: int in range(category_ids.size()):
		var category_id: StringName = category_ids[index]
		if str(category_id).strip_edges().is_empty():
			errors.append("category_ids[%d] must not be blank." % index)
		if seen.has(category_id):
			errors.append("category_ids[%d] duplicates category ID %s." % [index, category_id])
		seen[category_id] = true
	for stat: int in base_stats:
		if not GameplayTypes.Stat.values().has(stat):
			errors.append("base_stats[%d] must use a valid GameplayTypes.Stat key." % stat)
	for index: int in range(abilities.size()):
		if abilities[index] == null:
			errors.append("abilities[%d] must not be null." % index)
		else:
			for error: String in abilities[index].validation_errors():
				errors.append("abilities[%d]: %s" % [index, error])
	for ability: AbilityDefinition in abilities:
		if ability == null or ability.trigger_id == &"coded_catalog_rule": continue
		var has_status_effect: bool = false
		for effect: EffectDefinition in ability.effects:
			has_status_effect = has_status_effect or effect is ApplyStatusEffectDefinition
			if effect is ApplyStatusEffectDefinition and effect.status != null:
				var status_stat: int = GameplayTypes.stat_from_id(effect.status.id)
				if base_stats.has(status_stat): errors.append("Status grants must not be duplicated in base_stats.")
		if not has_status_effect: continue
		errors.append_array(CollectibleAbilityResolver.validation_errors(ability, _status_ability_trigger()))
	return errors

func _status_ability_trigger() -> StringName:
	return &""
