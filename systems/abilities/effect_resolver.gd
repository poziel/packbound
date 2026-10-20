class_name EffectResolver
extends RefCounted
## Resolves supported concrete effects against caller-owned combat state.
const CONTENT = preload("res://systems/content/runtime_content.gd")
const STATUSES = preload("res://systems/combat/status_resolver.gd")

static func application(id: StringName) -> ApplyStatusEffectDefinition:
	for effect: ApplyStatusEffectDefinition in CONTENT.content().status_applications:
		if effect.status.id == id: return effect
	return null

## Maps contain the statuses supported by each combatant. Callers supply copies
## for previews; this service neither chooses a combat phase nor writes run saves.
static func resolve(effect: EffectDefinition, source: Dictionary, opponent: Dictionary, applications: int = 1) -> Dictionary:
	var errors := PackedStringArray()
	if not effect is ApplyStatusEffectDefinition:
		errors.append("Unsupported effect type; no effect was applied.")
		return {"errors": errors}
	errors.append_array(effect.validation_errors())
	if applications < 0: errors.append("applications must be nonnegative.")
	if not errors.is_empty(): return {"errors": errors}
	var target: Dictionary = source if effect.target == ApplyStatusEffectDefinition.Target.SELF else opponent
	var value: Variant = target.get(effect.status.id)
	if not value is StatusEffectInstance or value.definition != effect.status:
		errors.append("Target must contain an instance of the referenced status definition.")
		return {"errors": errors}
	var before: int = value.stacks
	STATUSES.apply(value, effect.stacks * applications)
	return {"errors": errors, "status_id": effect.status.id, "target": effect.target, "stacks_before": before, "stacks_after": value.stacks, "remaining_rounds": value.remaining_rounds}
