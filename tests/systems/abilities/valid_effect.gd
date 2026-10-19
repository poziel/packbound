@tool
extends "res://systems/abilities/effect_definition.gd"
## Test-only concrete subtype, not an implemented gameplay effect.

@export var amount: int = 1

func validation_errors() -> PackedStringArray:
	return PackedStringArray(["amount must be positive."]) if amount < 1 else PackedStringArray()
