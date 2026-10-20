@tool
class_name ItemDefinition
extends CollectibleDefinition
## Authored backpack equipment data. Treat as read-only after content loading.
## Placement, chosen priority and other live state belong to an item instance.

@export_group("Equipment")
## Occupied cells in the unrotated footprint, relative to its top-left origin.
@export var footprint: Array[Vector2i] = []
@export var rotatable: bool = true

@export_group("Activation Costs")
## Resource IDs and amounts charged by an ordinary activation.
@export var activation_costs: Dictionary[GameplayTypes.ResourceType, int] = {}

@export_group("Damage Identity")
@export var damage_type: GameplayTypes.DamageType = GameplayTypes.DamageType.PHYSICAL
@export var element: GameplayTypes.Element = GameplayTypes.Element.NONE

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "activation_costs":
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = GameplayTypes.enum_dictionary_hint(GameplayTypes.ResourceType)

func _combat_ability_trigger() -> StringName:
	return CollectibleAbilityResolver.ITEM_TRIGGER

## Intrinsic validation only. The loader must check known IDs and references.
## Returns all errors without changing this definition or accessing game state.
func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = super.validation_errors()
	if footprint.is_empty():
		errors.append("footprint must contain at least one occupied cell.")
	var occupied: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in footprint:
		if cell.x < 0 or cell.y < 0:
			errors.append("footprint cell %s must have nonnegative coordinates." % cell)
		if occupied.has(cell):
			errors.append("footprint contains duplicate cell %s." % cell)
		occupied[cell] = true
	if not GameplayTypes.DamageType.values().has(damage_type):
		errors.append("damage_type must be a valid GameplayTypes.DamageType value.")
	if not GameplayTypes.Element.values().has(element):
		errors.append("element must be a valid GameplayTypes.Element value.")
	for resource_id: int in activation_costs:
		if not GameplayTypes.ResourceType.values().has(resource_id):
			errors.append("activation_costs[%d] must use a valid GameplayTypes.ResourceType key." % resource_id)
		if activation_costs[resource_id] < 0:
			errors.append("activation_costs[%s] must be nonnegative." % resource_id)
	return errors
