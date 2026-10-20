@tool
class_name QuiverVolleyEffectDefinition
extends EffectDefinition
## Base Volley tuning or a selected arrow/upgrade contribution.
enum Kind { BASE = 0, ARROW = 1, UPGRADE = 2 }
@export var kind: Kind = Kind.UPGRADE
@export var arrow_type: StringName = &""
@export_range(0, 999, 1, "or_greater") var arrows: int = 0
@export_range(0, 999, 1, "or_greater") var interval: int = 0
@export_range(0, 999, 1, "or_greater") var interval_reduction: int = 0
@export_range(1, 999, 1, "or_greater") var cap: int = 1
@export var per_arrow_stats: Dictionary[GameplayTypes.Stat, int] = {}
@export var volley_stats: Dictionary[GameplayTypes.Stat, int] = {}
func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not Kind.values().has(kind): errors.append("Quiver effect kind must be valid.")
	if kind == Kind.BASE and (arrows <= 0 or interval <= 0): errors.append("Base Volley requires arrows and an interval.")
	if kind == Kind.ARROW and str(arrow_type).strip_edges().is_empty(): errors.append("Arrow selection requires an arrow_type ID.")
	if arrows < 0 or interval < 0 or interval_reduction < 0 or cap <= 0: errors.append("Quiver amounts must be nonnegative and cap positive.")
	for stats: Dictionary in [per_arrow_stats, volley_stats]:
		for stat: int in stats:
			if stat not in [GameplayTypes.Stat.DAMAGE, GameplayTypes.Stat.PIERCE, GameplayTypes.Stat.POISON, GameplayTypes.Stat.BURN, GameplayTypes.Stat.SLOW] or stats[stat] < 0: errors.append("Unsupported Volley stat or amount.")
	if kind == Kind.UPGRADE and arrows + interval_reduction == 0 and per_arrow_stats.is_empty() and volley_stats.is_empty(): errors.append("Upgrade must grant a bonus.")
	return errors

func _validate_property(property: Dictionary) -> void:
	if property.name in ["per_arrow_stats", "volley_stats"]:
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = GameplayTypes.enum_dictionary_hint(GameplayTypes.Stat)
