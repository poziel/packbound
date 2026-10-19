@tool
class_name ActionDefinition
extends Resource
## An explicitly chosen action; unlike a triggered passive, it has targeting and costs.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Known target selectors are checked by a future execution registry.
@export var target_id: StringName = &"self"
@export var activation_costs: Dictionary[GameplayTypes.ResourceType, int] = {}
## All conditions must pass. Effects resolve in authored order.
@export var conditions: Array[ConditionDefinition] = []
@export var effects: Array[EffectDefinition] = []

func _validate_property(property: Dictionary) -> void:
	if property.name == "activation_costs":
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = GameplayTypes.enum_dictionary_hint(GameplayTypes.ResourceType)

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for field: String in ["id", "display_name", "target_id"]:
		if str(get(field)).strip_edges().is_empty():
			errors.append("%s must not be blank." % field)
	for resource: int in activation_costs:
		if not GameplayTypes.ResourceType.values().has(resource):
			errors.append("activation_costs[%d] must use a valid resource." % resource)
		if activation_costs[resource] < 0:
			errors.append("activation_costs[%d] must be nonnegative." % resource)
	if effects.is_empty():
		errors.append("effects must contain at least one effect.")
	for field: String in ["conditions", "effects"]:
		var entries: Array = get(field)
		for index: int in range(entries.size()):
			if entries[index] == null:
				errors.append("%s[%d] must not be null." % [field, index])
			else:
				for error: String in entries[index].validation_errors():
					errors.append("%s[%d]: %s" % [field, index, error])
	return errors
