extends "res://tests/support/prototype_support.gd"

const PRESENTATION = preload("res://systems/items/item_presentation.gd")

func _value(rows: Array, key: String) -> int:
	for row: Dictionary in rows:
		if row["key"] == key:
			return int(row["value"])
	return 0

func _run() -> void:
	var state: PackRun = fixture("ranger")
	state.items.clear()
	var quiver: Dictionary = state.add_item(PackCatalog.QUIVER.KEY, Vector2i(0, 0))
	quiver["arrow_type"] = "broadhead"
	var rack: Dictionary = state.add_item("winterflight_rack", Vector2i(1, 0))
	var shown: Array = PRESENTATION.volley_stats(state, quiver)
	check(_value(shown, "damage") == int(state.volley_stats()[GameplayTypes.Stat.DAMAGE]), "Quiver inspection shows actual augmented Volley damage")
	check(_value(shown, "slow") == int(state.volley_stats()[GameplayTypes.Stat.SLOW]) and _value(shown, "slow") > 0, "Quiver inspection includes equipment Slow")
	check(not PRESENTATION.bonuses(state, quiver).is_empty(), "Quiver equipment has a named source entry")
	var board = load("res://scenes/run/inventory/backpack/backpack_board.gd").new()
	board.run = state
	check(not board.bonus_markers(quiver).is_empty(), "Non-damage quiver equipment receives a contact marker")
	rack["cell"] = null
	check(_value(PRESENTATION.volley_stats(state, quiver), "slow") == 0, "Stashed equipment disappears from displayed Volley")
	state.items.clear()
	var bow: Dictionary = state.add_item("shortbow", Vector2i(0, 0))
	var tips: Dictionary = state.add_item("hunter_s_compass", Vector2i(1, 0))
	var stats: Array = PRESENTATION.item_stats(state, bow)
	check(_value(stats, "piercing") == int(state.adjacency_stats(bow).get("pierce", 0)) and _value(stats, "piercing") > 0, "Typed bow adjacency is included in the keyword list")
	check(not PRESENTATION.bonuses(state, bow).is_empty(), "Typed bow adjacency names its source")
	check(not board.bonus_markers(bow).is_empty(), "Typed bow adjacency gets a contact marker")
	tips["cell"] = null
	check(_value(PRESENTATION.item_stats(state, bow), "piercing") == 0, "Stashing removes displayed typed adjacency")
	board.free()
	report("EXPANSION PRESENTATION")
	quit(1 if failures else 0)
