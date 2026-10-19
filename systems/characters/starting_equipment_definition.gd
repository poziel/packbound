@tool
class_name StartingEquipmentDefinition
extends Resource
## One placed starting item. Repeat entries to supply multiple physical items.
@export var item_id: StringName = &""
@export var position: Vector2i = Vector2i.ZERO
## Clockwise quarter turns. The loader also checks item rotatability and board fit.
@export_range(0, 3) var rotation: int = 0

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if str(item_id).strip_edges().is_empty():
		errors.append("item_id must not be blank.")
	if position.x < 0 or position.y < 0:
		errors.append("position must be nonnegative.")
	if rotation < 0 or rotation > 3:
		errors.append("rotation must be between 0 and 3.")
	return errors
