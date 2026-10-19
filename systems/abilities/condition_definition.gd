@tool
@abstract
class_name ConditionDefinition
extends Resource
## Authored condition contract. Concrete subclasses declare typed parameters.
## Runtime evaluation belongs to a separately defined resolver and context.

@abstract func validation_errors() -> PackedStringArray
