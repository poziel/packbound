@tool
class_name CatalogRuleEffectDefinition
extends EffectDefinition
## Transitional binding to an existing coded catalog rule. Not a generic interpreter.
## Preserves rules not represented by typed fields until individual effects migrate.
@export var rule_id: StringName = &""
@export var parameters: Dictionary = {}

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if str(rule_id).strip_edges().is_empty():
		errors.append("rule_id must not be blank.")
	# Rule handlers own parameter schemas. Keep existing bindings compatible while
	# rejecting unusable field names; known rule IDs are a future resolver concern.
	for key: Variant in parameters:
		if key is int and GameplayTypes.Stat.values().has(key):
			if not parameters[key] is int:
				errors.append("Enum stat parameters must contain integer values.")
			continue
		if not (key is String or key is StringName) or str(key).strip_edges().is_empty():
			errors.append("parameters keys must be nonblank strings or StringNames.")
	return errors
