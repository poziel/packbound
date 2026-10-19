extends "res://tests/support/test_case.gd"
class DrawProbe extends BackpackBoard:
	func _draw_footprint(_at: Vector2, _points: Array[Vector2i], _accent: Color, _highlighted: bool = false, _segments: Array[Dictionary] = []) -> void:
		pass
	func _draw_item_art(_item: Dictionary, _rect: Rect2, _points: Array[Vector2i], _rotation: int, _alpha: Color) -> void:
		pass

func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("run_test")
func run_test() -> void:
	var board = load("res://scenes/run/inventory/backpack/backpack.tscn").instantiate()
	root.add_child(board)
	await process_frame
	var tee: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]
	board._cover_empty_cells(board.ORIGIN, tee)
	board._sync_empty_cells()
	check(not board.get_node("Cell1_1").visible and not board.get_node("Cell3_1").visible and not board.get_node("Cell2_2").visible, "Occupied T cells hidden")
	check(board.get_node("Cell1_2").visible and board.get_node("Cell3_2").visible, "Empty T notches remain visible")
	board._covered_empty_cells.clear()
	board._cover_empty_cells(board.ORIGIN + Vector2(30, 20), [Vector2i.ZERO] as Array[Vector2i])
	board._sync_empty_cells()
	check(not board.get_node("Cell1_1").visible and not board.get_node("Cell2_2").visible, "Explicit coverage hides overlapped slots")
	board._covered_empty_cells.clear()
	board._sync_empty_cells()
	check(board.get_node("Cell1_1").visible and board.get_node("Cell2_2").visible, "Slots return after moving item away")
	var probe := DrawProbe.new()
	var state := PackRun.new()
	state.reset(42, "warrior")
	var item: Dictionary = state.add_item("battle_axe")
	probe.drag_rotation = 0
	var rect := Rect2(probe.ORIGIN, probe.footprint(item["shape"]))
	probe._draw_item(item, rect, true)
	check(probe._covered_empty_cells.is_empty(), "Floating drag artwork does not hide slots")
	probe._draw_item(item, rect, false)
	check(not probe._covered_empty_cells.is_empty(), "Stationary artwork hides its occupied slots")
	probe.free()
	var portrait = load("res://components/characters/character_preview/character_preview.tscn").instantiate()
	root.add_child(portrait)
	portrait.size = Vector2(104, 104)
	portrait.texture = PackArt.character_head("warrior")
	portrait._update_art()
	check(portrait.get_node("Art").size == Vector2(98, 98), "Portrait fills interior without integer scale dead space")
	check(portrait.get_node("Art").position == Vector2(3, 3), "Portrait preserves border and clear gap")
	board.queue_free()
	portrait.queue_free()
	print("TILE OCCLUSION / PORTRAIT: ", failures, " failures")
	report("tile_occlusion_portrait")
	quit(1 if failures else 0)
