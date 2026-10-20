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
	var value := StatusEffectInstance.new(authored, 0, 0)
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
	if value.remaining_rounds == 0 or value.definition.refresh_duration_on_application:
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
	var had_stacks: bool = value.stacks > 0
	if not _prevents_decay(value, context):
		value.stacks = maxi(0, value.stacks - value.definition.decay_per_round)
	if had_stacks and value.stacks == 0: value.remaining_rounds = 0

static func advance_round(value: StatusEffectInstance, context: Dictionary = {}) -> void:
	decay(value, context)
	if value.definition.duration_rounds > 0:
		value.remaining_rounds = maxi(0, value.remaining_rounds - 1)
		if value.remaining_rounds == 0: value.stacks = 0

## Pure calculation; consumption, lifetime and combat commits are explicit steps.
static func tick(value: StatusEffectInstance, trigger: StringName, context: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"damage": 0, "wardable_damage": 0, "reduction": 0, "consumed_stacks": 0, "consume_all": false}
	if not active(value) or value.definition.tick_trigger_id != trigger: return result
	for effect: EffectDefinition in value.definition.effects:
		if not effect is CatalogRuleEffectDefinition:
			push_error("Unsupported status effect: " + str(value.definition.id))
			continue
		var rule: Dictionary = effect.parameters
		match effect.rule_id:
			&"slow_status_rules":
				if not bool(rule.get("applies_to_each_strike", true)) and int(context.get("strike_index", 0)) > 0: continue
				result.reduction += mini(maxi(0, int(context.get("damage", 0))), value.stacks * int(rule.get("reduction_per_stack", 0)))
				continue
			&"spark_status_rules":
				if bool(rule.get("requires_positive_damage", true)) and int(context.get("magical_damage", 0)) <= 0: continue
				result.consumed_stacks += int(rule.get("consumed_stacks", 0))
			&"doom_status_rules":
				if not bool(rule.get("detonate_at_expiration", true)) or value.definition.duration_rounds == 0 or value.remaining_rounds > 1: continue
				result.consume_all = bool(rule.get("consume_all_on_detonation", true))
			&"poison_status_rules", &"burn_status_rules": pass
			_:
				push_error("Unsupported status rule: " + str(effect.rule_id))
				continue
		var kind: int = rule.get("damage_type", GameplayTypes.DamageType.MAGICAL)
		var raw: int = value.stacks * int(rule.get("damage_per_stack", 0))
		var damage: int = DAMAGE.resist(raw, int(context.get("resistances", {}).get(kind, 0)))
		result.damage += damage
		if context.get("owner", "") == "player" and bool(rule.get("player_ward_absorbs", false)):
			result.wardable_damage += damage
	return result

## Tick consumption is independent of cleansing permission.
static func resolve_tick(value: StatusEffectInstance, trigger: StringName, context: Dictionary = {}) -> Dictionary:
	var result: Dictionary = tick(value, trigger, context)
	if result.consume_all or int(result.consumed_stacks) > 0:
		value.stacks = 0 if result.consume_all else maxi(0, value.stacks - int(result.consumed_stacks))
		if value.stacks == 0: value.remaining_rounds = 0
	return result

## Spark normally resolves old stacks before applying this action's fresh stacks.
static func resolve_application(value: StatusEffectInstance, amount: int, trigger: StringName, context: Dictionary = {}) -> Dictionary:
	var wait_for_later: bool = false
	for effect: EffectDefinition in value.definition.effects:
		if effect is CatalogRuleEffectDefinition:
			wait_for_later = wait_for_later or bool(effect.parameters.get("fresh_stacks_wait", false))
	if not wait_for_later: apply(value, amount)
	var result: Dictionary = resolve_tick(value, trigger, context)
	if wait_for_later: apply(value, amount)
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
