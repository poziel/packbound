class_name StatusResolver
extends RefCounted
## Status lifecycle rules. Combat owns when phases commit and how damage spends HP/Ward.
const CONTENT = preload("res://systems/content/runtime_content.gd")
const DAMAGE = preload("res://systems/combat/elemental_combat.gd")

static func definition(id: StringName) -> StatusEffectDefinition:
	for value: StatusEffectDefinition in CONTENT.content().status_effects:
		if value.id == id: return value
	push_error("Unknown status definition: " + str(id))
	return null

static func create(id: StringName, stacks: int = 0) -> StatusEffectInstance:
	var authored := definition(id)
	if authored == null: return null
	var value := StatusEffectInstance.new(authored)
	apply(value, stacks)
	return value

static func copy(value: StatusEffectInstance) -> StatusEffectInstance:
	return StatusEffectInstance.new(value.definition, value.stacks, value.remaining_rounds)

static func active(value: StatusEffectInstance) -> bool:
	return value.stacks > 0 and (value.definition.duration_rounds == 0 or value.remaining_rounds > 0)

static func apply(value: StatusEffectInstance, amount: int) -> void:
	if amount <= 0: return
	var was_active: bool = active(value)
	if not was_active: value.stacks = 0
	match value.definition.stack_policy:
		StatusEffectDefinition.StackPolicy.ADD: value.stacks += amount
		StatusEffectDefinition.StackPolicy.REPLACE: value.stacks = amount
		StatusEffectDefinition.StackPolicy.KEEP_HIGHEST: value.stacks = maxi(value.stacks, amount)
	if value.definition.max_stacks > 0:
		value.stacks = mini(value.stacks, value.definition.max_stacks)
	if not was_active or value.definition.refresh_duration_on_application:
		value.remaining_rounds = value.definition.duration_rounds

static func cleanse(value: StatusEffectInstance, amount: int = -1) -> int:
	if not value.definition.cleansable: return 0
	var removed: int = value.stacks if amount == -1 else mini(value.stacks, maxi(0, amount))
	value.stacks -= removed
	if value.stacks == 0: value.remaining_rounds = 0
	return removed

static func _prevents_decay(value: StatusEffectInstance, context: Dictionary) -> bool:
	if context.get("owner", "") != "enemy": return false
	for effect: EffectDefinition in value.definition.effects:
		if effect is CatalogRuleEffectDefinition and effect.rule_id == &"poison_status_rules":
			var id: String = str(effect.parameters.get("prevent_enemy_decay_relic_id", ""))
			if not id.is_empty() and context.get("relics", []).has(id): return true
	return false

static func decay(value: StatusEffectInstance, context: Dictionary = {}) -> void:
	if not _prevents_decay(value, context):
		value.stacks = maxi(0, value.stacks - value.definition.decay_per_round)
	if value.stacks == 0: value.remaining_rounds = 0

static func advance_round(value: StatusEffectInstance, context: Dictionary = {}) -> void:
	decay(value, context)
	if value.definition.duration_rounds > 0:
		value.remaining_rounds = maxi(0, value.remaining_rounds - 1)
		if value.remaining_rounds == 0: value.stacks = 0

## Pure tick calculation. Only Poison's existing coded binding is migrated here.
## Additional effect handlers must be introduced explicitly, one condition at a time.
static func tick(value: StatusEffectInstance, trigger: StringName, context: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"damage": 0, "wardable_damage": 0}
	if not active(value) or value.definition.tick_trigger_id != trigger: return result
	for effect: EffectDefinition in value.definition.effects:
		if not effect is CatalogRuleEffectDefinition or effect.rule_id != &"poison_status_rules":
			push_error("Status tick handler has not been migrated: " + str(value.definition.id))
			continue
		var rule: Dictionary = effect.parameters
		var kind: String = str(rule.get("damage_type", "magical"))
		var raw: int = value.stacks * int(rule.get("damage_per_stack", 0))
		var damage: int = DAMAGE.resist(raw, int(context.get("resistances", {}).get(kind, 0)))
		result.damage += damage
		if context.get("owner", "") == "player" and bool(rule.get("player_ward_absorbs", false)):
			result.wardable_damage += damage
	return result

static func snapshot(value: StatusEffectInstance) -> Dictionary:
	return {"definition_id": str(value.definition.id), "stacks": value.stacks, "remaining_rounds": value.remaining_rounds}

static func is_snapshot_valid(data: Variant, expected_id: StringName = &"") -> bool:
	if not data is Dictionary: return false
	if not data.get("definition_id") is String or str(data.definition_id).is_empty(): return false
	if expected_id != &"" and StringName(data.definition_id) != expected_id: return false
	for key: String in ["stacks", "remaining_rounds"]:
		if not data.get(key) is int or int(data[key]) < 0: return false
	return true

static func restore(data: Dictionary) -> StatusEffectInstance:
	if not is_snapshot_valid(data):
		push_error("Invalid status snapshot")
		return null
	var authored := definition(StringName(data.definition_id))
	if authored == null: return null
	return StatusEffectInstance.new(authored, data.stacks, data.remaining_rounds)
