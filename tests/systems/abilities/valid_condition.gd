@tool
extends "res://systems/abilities/condition_definition.gd"
## Test-only concrete subtype for validation and Resource serialization coverage.

@export var minimum_count: int = 1

func validation_errors() -> PackedStringArray:
	return PackedStringArray(["minimum_count must be positive."]) if minimum_count < 1 else PackedStringArray()
