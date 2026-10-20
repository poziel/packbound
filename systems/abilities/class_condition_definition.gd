@tool
class_name ClassConditionDefinition
extends ConditionDefinition
@export var class_id: StringName = &"warrior"
func matches(context: Dictionary) -> bool:
	return StringName(context.get("class_id", "")) == class_id
func validation_errors() -> PackedStringArray:
	return PackedStringArray(["class_id must not be blank."]) if str(class_id).strip_edges().is_empty() else PackedStringArray()

func tooltip_keyword_id() -> String:
	return "warrior" if class_id == &"warrior" else ""
