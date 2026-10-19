@tool
@abstract
class_name CombatantDefinition
extends Resource
## Authored baseline only; current health, resources and statuses belong to runtime state.

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
## Empty falls back to display_name in a future presentation resolver.
@export var log_name: String = ""
@export_multiline var description: String = ""
@export var tags: Array[StringName] = []

@export_group("Presentation")
@export var icon: Texture2D

@export_group("Combat")
@export var base_stats: Dictionary[GameplayTypes.Stat, int] = {}
## Capacities only. Starting/refill/reset policies remain combat rules.
## Health is represented here by ResourceType.HEALTH, not duplicated in base_stats.
@export var resource_capacities: Dictionary[GameplayTypes.ResourceType, int] = {}
@export var abilities: Array[AbilityDefinition] = []

func _validate_property(property: Dictionary) -> void:
	if property.name == "base_stats":
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = GameplayTypes.enum_dictionary_hint(GameplayTypes.Stat)
	elif property.name == "resource_capacities":
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = GameplayTypes.enum_dictionary_hint(GameplayTypes.ResourceType)

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for field: String in ["id", "display_name"]:
		if str(get(field)).strip_edges().is_empty():
			errors.append("%s must not be blank." % field)
	for stat: int in base_stats:
		if not GameplayTypes.Stat.values().has(stat):
			errors.append("base_stats[%d] must use a valid stat." % stat)
	for resource: int in resource_capacities:
		if not GameplayTypes.ResourceType.values().has(resource):
			errors.append("resource_capacities[%d] must use a valid resource." % resource)
		if resource_capacities[resource] < 0:
			errors.append("resource_capacities[%d] must be nonnegative." % resource)
	for index: int in range(abilities.size()):
		if abilities[index] == null:
			errors.append("abilities[%d] must not be null." % index)
		else:
			for error: String in abilities[index].validation_errors():
				errors.append("abilities[%d]: %s" % [index, error])
	return errors
