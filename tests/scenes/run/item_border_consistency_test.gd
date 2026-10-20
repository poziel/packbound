extends "res://tests/support/test_case.gd"

class BoardSample extends BackpackBoard:
	var sample: Dictionary
	var held: bool = false
	var synergy: bool = false
	func _draw() -> void:
		_bonus_related.assign([int(sample.id)] if synergy else [])
		drag_shape = Vector2i.ONE
		hovered_id = sample.id if held else -1
		_draw_item(sample, Rect2(32, 32, 64, 64), held)

class StashSample extends Control:
	var body: RigidBody2D
	func _draw() -> void:
		body.draw_art(self, Transform2D(0.0, Vector2(64, 64)))


func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func _run() -> void:
	var state := PackRun.new()
	state.reset(42)
	state.items.clear()
	var item: Dictionary = state.add_item("buckler", Vector2i.ZERO)
	var views: Array[SubViewport] = []
	for index in range(2):
		var view := SubViewport.new()
		view.size = Vector2i(128, 128)
		view.transparent_bg = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		views.append(view)
	var board := BoardSample.new()
	board.sample = item
	board.run = state
	views[0].add_child(board)
	board.set_process(false)
	var stash := StashSample.new()
	stash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stash.body = preload("res://scenes/run/inventory/storage_inventory/stash_body.gd").new()
	stash.body.setup(item, BackpackBoard.CELL)
	views[1].add_child(stash)
	for rarity: int in [GameplayTypes.Rarity.COMMON, GameplayTypes.Rarity.RARE, GameplayTypes.Rarity.LEGENDARY]:
		var rarity_label: String = str(GameplayTypes.rarity_id(rarity))
		item.rarity = rarity
		var settled: Array[Image] = []
		for held: bool in [false, true]:
			board.held = held
			stash.body.held = held
			board.queue_redraw()
			stash.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var a: Image = views[0].get_texture().get_image()
			var b: Image = views[1].get_texture().get_image()
			check(a.get_data() == b.get_data(), "Backpack and stash render the same rarity frame: " + rarity_label)
			if not held: settled.assign([a, b])
			else:
				check(a.get_data() == settled[0].get_data(), "Backpack hover/drag keeps its rarity border: " + rarity_label)
				check(b.get_data() == settled[1].get_data(), "Stash grab/release keeps its rarity border: " + rarity_label)
		board.held = false
		board.synergy = true
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var lit: Image = views[0].get_texture().get_image()
		check(lit.get_data() != settled[0].get_data(), "Synergy restores a visible border highlight: " + rarity_label)
		var glow_pixels: int = 0
		var glow_color: Color = preload("res://components/inventory/item_slot/item_frame.gd").SYNERGY_COLOR
		for y in lit.get_height():
			for x in lit.get_width():
				if lit.get_pixel(x, y).is_equal_approx(Color(glow_color.to_html())):
					glow_pixels += 1
		check(glow_pixels > 0, "Synergy border uses the shared yellow-beige caret color: " + rarity_label)
		board.synergy = false
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(views[0].get_texture().get_image().get_data() == settled[0].get_data(), "Leaving synergy restores the exact rarity frame: " + rarity_label)
	board.hide()
	var slot: PackItemSlot = load("res://components/inventory/item_slot/item_slot.tscn").instantiate()
	slot.position = Vector2(32, 32)
	slot.size = Vector2(64, 64)
	slot.occupied = true
	slot.accent = Color("a87bd9")
	views[0].add_child(slot)
	slot.border_color = Color.YELLOW
	await process_frame
	await RenderingServer.frame_post_draw
	var yellow: Image = views[0].get_texture().get_image()
	slot.border_color = Color.CYAN
	await process_frame
	await RenderingServer.frame_post_draw
	var cyan: Image = views[0].get_texture().get_image()
	var only_border_changed: bool = true
	var changes: int = 0
	for y in yellow.get_height():
		for x in yellow.get_width():
			if yellow.get_pixel(x, y) != cyan.get_pixel(x, y):
				changes += 1
				only_border_changed = only_border_changed and yellow.get_pixel(x, y) == Color.YELLOW and cyan.get_pixel(x, y) == Color.CYAN
	check(changes > 0 and only_border_changed, "Component border override changes only the rim, preserving fill")
	stash.body.free()
	for view: SubViewport in views: view.queue_free()
	await process_frame
	report("ITEM BORDER CONSISTENCY")
	quit(1 if failures else 0)
