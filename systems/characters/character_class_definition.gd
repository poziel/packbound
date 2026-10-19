@tool
class_name CharacterClassDefinition
extends Resource
## Shared class identity and innate capabilities. Character baselines stay explicit;
## no implicit stat/default merging is defined by this Resource.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var abilities: Array[AbilityDefinition] = []

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for field: String in ["id", "display_name"]:
		if str(get(field)).strip_edges().is_empty():
			errors.append("%s must not be blank." % field)
	for index: int in range(abilities.size()):
		if abilities[index] == null:
			errors.append("abilities[%d] must not be null." % index)
		else:
			for error: String in abilities[index].validation_errors():
				errors.append("abilities[%d]: %s" % [index, error])
	return errors
