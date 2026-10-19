@tool
@abstract
class_name EffectDefinition
extends Resource
## Authored effect contract. Concrete subclasses declare typed parameters.
## This data model does not execute effects or hold per-owner runtime state.

@abstract func validation_errors() -> PackedStringArray
