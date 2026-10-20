extends "res://tests/support/test_case.gd"

var game: Control
var render: bool = false

func fixture(character: String = "warrior") -> PackRun:
	var state: PackRun = PackRun.new()
	state.reset(42, character)
	state.choose_relic(state.relic_offers[0])
	state.relics.clear()
	if state.needs_arrows():
		state.choose_loot("arrow_broadhead")
	return state

func _wait_for_action() -> void:
	while game.busy:
		await process_frame

func _tab_index(tab_name: StringName) -> int:
	return game.character_tabs.get_tab_idx_from_control(game.character_tabs.get_node(NodePath(tab_name)))

func _catalog_checks() -> void:
	check(PackCatalog.ROSTER.size() == 28, "Twenty-eight item types including three elemental spells")
	check(PackCatalog.enemies().size() == 56, "Fifty-six enemies")
	var names: Dictionary = {}
	for enemy in PackCatalog.enemies():
		names[enemy["key"]] = true
	check(names.size() == 56, "Enemy identities are unique")
	for key in PackCatalog.ROSTER:
		var item: Dictionary = PackCatalog.item(key)
		check(not item["mask"].is_empty(), key + " has occupied cells")
		var original: Array[Vector2i] = PackRun.offsets(item)
		for rotation in range(4):
			var mask: Array[Vector2i] = PackRun.offsets(item, rotation)
			var unique: Dictionary = {}
			for point in mask:
				unique[point] = true
				check(point.x >= 0 and point.y >= 0, key + " rotation normalized")
			check(unique.size() == original.size(), key + " rotation preserves cells")
		check(PackRun.offsets(item, 4) == original, key + " returns after full revolution")
		var art: AtlasTexture = PackArt.item(key)
		var native_size: Vector2 = Vector2(32, 32) if key in ["rusty_knife", "cracked_shield", "iron_charm", "longsword", "blood_gem", "bandage", "cursed_idol", "tower_shield"] else Vector2(96, 96)
		if key in ["buckler", "spark_ring", "antidote"]: native_size = Vector2(32, 32)
		if key in ["venom_dagger", "shortbow", "ember_tome", "thorn_mail", "healing_herbs", "mirror_shard"]: native_size = Vector2(64, 64)
		if key in ["quiver", "vampire_fang"]: native_size = Vector2(32, 64)
		if key == "frost_wand": native_size = Vector2(32, 96)
		if key == "lightning_wand": native_size = Vector2(32, 96)
		if key in ["void_tome", "venom_orb"]: native_size = Vector2(64, 64)
		if key in ["battle_axe", "plate_mail", "hunting_trap", "hourglass"]: native_size = Vector2(96, 64)
		check(art.get_size() == native_size, key + " has art at its source resolution")
	var axe_art: Texture2D = PackArt.item("battle_axe").atlas
	check(axe_art.resource_path == "res://assets/items/battle_axe/art/item.png", "Executioner's Axe uses approved catalog redraw")
	for view_edge in [64, 128, 256]:
		check(PackArt.item("battle_axe", view_edge).atlas == axe_art, "Executioner's Axe keeps approved artwork across display sizes")
	var axe_image: Image = axe_art.get_image()
	var axe_forbidden: int = 0
	for y in range(32, 64):
		for x in range(96):
			if (x < 32 or x >= 64) and axe_image.get_pixel(x, y).a > 0: axe_forbidden += 1
	check(axe_forbidden == 0, "Executioner's Axe keeps both bottom corners transparent")
	var dagger_art: Texture2D = PackArt.item("longsword").atlas
	check(dagger_art.resource_path == "res://assets/items/iron_dagger/art/item.png", "Iron Dagger uses approved catalog redraw")
	for view_edge in [64, 128, 256]:
		check(PackArt.item("longsword", view_edge).atlas == dagger_art, "Iron Dagger keeps approved artwork across display sizes")
	var knife_art: Texture2D = PackArt.item("rusty_knife").atlas
	check(knife_art.resource_path == "res://assets/items/rusty_knife/art/item.png", "Rusty Knife uses approved catalog redraw")
	for view_edge in [64, 128, 256]:
		check(PackArt.item("rusty_knife", view_edge).atlas == knife_art, "Rusty Knife keeps approved artwork across display sizes")
	var charm_art: Texture2D = PackArt.item("iron_charm").atlas
	check(charm_art.resource_path == "res://assets/items/iron_charm/art/item.png", "Iron Charm uses approved catalog redraw")
	for view_edge in [64, 128, 256]:
		check(PackArt.item("iron_charm", view_edge).atlas == charm_art, "Iron Charm keeps approved artwork across display sizes")
	var approved_items: Dictionary = {
		"tower_shield": "shield_relic/art/item.png",
		"antidote": "antidote/art/item.png",
		"mirror_shard": "mirror_shard/art/item.png",
		"hourglass": "hourglass/art/item.png",
		"healing_herbs": "healing_herbs/art/item.png",
		"hunting_trap": "hunting_trap/art/item.png",
		"warding_sigil": "warding_sigil/art/item.png",
		"thorn_mail": "thorn_mail/art/item.png",
		"shortbow": "shortbow/art/item.png",
		"quiver": "quiver/art/item.png",
		"buckler": "buckler/art/item.png",
		"ember_tome": "ember_tome/art/item.png",
		"frost_wand": "frost_wand/art/item.png",
		"spark_ring": "spark_ring/art/item.png",
		"venom_dagger": "venom_dagger/art/item.png",
		"vampire_fang": "vampire_fang/art/item.png",
		"plate_mail": "plate_mail/art/item.png",
		"cracked_shield": "cracked_shield/art/item.png",
		"blood_gem": "blood_gem/art/item.png",
		"bandage": "bandage/art/item.png",
		"cursed_idol": "cursed_idol/art/item.png",
	}
	for key in approved_items:
		var approved_art: Texture2D = PackArt.item(key).atlas
		check(approved_art.resource_path == "res://assets/items/" + approved_items[key], key + " uses approved catalog redraw")
		for view_edge in [64, 128, 256]:
			check(PackArt.item(key, view_edge).atlas == approved_art, key + " keeps approved artwork across display sizes")
	var venom_art: Texture2D = PackArt.item("venom_dagger").atlas
	check(PackArt.item("venom_dagger", 64).atlas == venom_art, "Venom Dagger reuses its base for selection")
	var venom_image: Image = venom_art.get_image()
	var forbidden_pixels: int = 0
	for y in range(32, 64):
		for x in range(32):
			if venom_image.get_pixel(x, y).a > 0: forbidden_pixels += 1
	check(forbidden_pixels == 0, "Venom Dagger import keeps bottom-left cell transparent")
	var state: PackRun = fixture()
	state.items.clear()
	var venom: Dictionary = state.add_item("venom_dagger", Vector2i.ZERO)
	var interlocking_knife: Dictionary = state.add_item("rusty_knife")
	check(PackRun.offsets(venom) == [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)], "Venom Dagger retains inverted L footprint")
	check(state.can_place(interlocking_knife, Vector2i(0, 1)), "Venom Dagger empty corner allows interlocking")
	check(not state.can_place(interlocking_knife, Vector2i(1, 1)), "Venom Dagger grip rejects overlap")
	state.items.clear()
	var axe: Dictionary = state.add_item("battle_axe", Vector2i(0, 0))
	var knife: Dictionary = state.add_item("rusty_knife")
	check(state.can_place(knife, Vector2i(0, 1)), "An item can interlock inside a T shape's empty corner")
	check(not state.can_place(knife, Vector2i(1, 1)), "Occupied T-shape stem rejects overlap")
	check(not state.can_place(axe, PackRun.GRID - Vector2i.ONE), "Shaped item rejects out-of-bounds")

func _mechanics_checks() -> void:
	var state: PackRun = fixture()
	check(state.max_hp == 40 and state.items[0]["key"] == "longsword", "Warrior loadout")
	var result: Dictionary = state.end_turn()
	check(result["retaliation"] == 0 and result["taken"] == 0 and state.momentum == 1, "Warrior builds Momentum after a fully blocked exchange without Riposte")
	state = fixture("ranger")
	var normal: int = state.effects()["damage"]
	state.volley_remaining = 1
	check(state.effects()["damage"] == normal + 8 and normal > 0, "Archer quiver launches an independent two-arrow Volley")
	state = fixture("mage")
	check(state.effects()["mana"] == 6 and state.effects()["mana_after"] == 1 and state.effects()["stamina"] == 0, "Elementalist funds both starting spells with innate mana and no stamina")
	state.items.clear()
	var ember: Dictionary = state.add_item("ember_tome", Vector2i(0, 0))
	var frost: Dictionary = state.add_item("frost_wand", Vector2i(4, 0))
	ember["cost"] = 5
	check(state.effects()["active_ids"].has(ember["id"]) and state.effects()["dormant_ids"].has(frost["id"]), "Insufficient mana leaves later spell dormant")
	ember["cell"] = Vector2i(2, 0)
	frost["cell"] = Vector2i(0, 0)
	check(state.effects()["active_ids"].has(frost["id"]) and state.effects()["dormant_ids"].has(ember["id"]), "Rearranging spells changes casting order")
	state.relics.append("arcane_barter")
	check(state.effects()["blood_cost"] == 1 and state.effects()["dormant_ids"].is_empty(), "Arcane Barter substitutes HP for missing mana")
	state.relics = ["mana_furnace"]
	state.items.clear()
	state.add_item("spark_ring", Vector2i.ZERO)
	check(state.effects()["block"] == 16 and state.effects()["mana_after"] == 0, "Mana Furnace converts and consumes mana")
	state = fixture()
	state.items.clear()
	var gem: Dictionary = state.add_item("blood_gem", Vector2i.ZERO)
	var knife: Dictionary = state.add_item("rusty_knife", Vector2i(1, 1))
	check(state.effects()["damage"] == 4, "Diagonal contact inactive by default")
	state.relics.append("diagonal_thread")
	check(state.effects()["damage"] == 6, "Diagonal Thread changes adjacency")
	state.relics = ["folded_space"]
	knife["cell"] = Vector2i(PackRun.GRID.x - 1, 0)
	check(state.effects()["damage"] == 6, "Folded Space connects opposite horizontal edges")
	gem["cell"] = null
	state.relics = ["echo_clock"]
	state.turn = 3
	check(state.effects()["damage"] == 8, "Echo Clock repeats first attack")
	state.relics.clear()
	state.add_item("hourglass", Vector2i(1, 1))
	state.turn = 4
	check(state.effects()["damage"] == 8, "Hourglass repeats melee every fourth turn")
	state = fixture()
	state.relics = ["returning_guard"]
	state.enemy["hp"] = 100
	state.enemy["max_hp"] = 100
	state.end_turn()
	check(state.block == 3 and state.effects()["block"] == 3, "Returning Guard preserves full remaining block")
	state = fixture()
	state.items.clear()
	state.add_item("healing_herbs", Vector2i.ZERO)
	state.relics = ["blood_pact"]
	check(state.outcome(state.effects())["dealt"] == 4, "Blood Pact converts excess regeneration to damage")
	state = fixture()
	state.items.clear()
	state.add_item("venom_dagger", Vector2i.ZERO)
	state.relics = ["plague_seal"]
	state.end_turn()
	check(state.enemy_poison == 3, "Plague Seal prevents enemy poison decay")
	state = fixture()
	state.items.clear()
	state.add_item("plate_mail", Vector2i.ZERO)
	state.fight = 11
	state.prepare_enemy()
	result = state.outcome(state.effects())
	check(result["taken"] == 6, "Plating reduces each of three strikes")
	state.add_item("warding_sigil", Vector2i(3, 0))
	state.player_poison = 5
	result = state.outcome(state.effects())
	check(result["special_taken"] == 1 and result["ward_absorbed"] == 4, "Ward absorbs status damage separately from attacks")
	state.add_item("antidote", Vector2i(5, 3))
	check(state.outcome(state.effects())["special_taken"] == 0, "Antidote cleanses poison before ward/tick")
	state = fixture()
	state.items.clear()
	state.add_item("vampire_fang", Vector2i.ZERO)
	state.hp = 10
	state.enemy["hp"] = 1
	result = state.outcome(state.effects())
	check(result["healed"] == 1 and result["hp_after"] == 11 and result["taken"] == 0, "Vampirism caps at HP damage actually dealt on killing blow")
	state = fixture()
	state.items.clear()
	state.add_item("longsword", Vector2i.ZERO)
	state.hp = 1
	state.relics = ["last_thread"]
	result = state.end_turn()
	check(result["revived"] and state.hp == 8 and state.items[0]["cell"] == null and state.last_thread_used, "Last Thread rescues once and unpacks largest item")
	state.hp = 1
	check(not state.outcome(state.effects())["revived"], "Last Thread cannot trigger twice")
	state = fixture()
	state.items.clear()
	var axe: Dictionary = state.add_item("battle_axe", Vector2i.ZERO)
	axe["rotation"] = 2
	state.add_item("rusty_knife", Vector2i.ZERO)
	state.relics = ["echo_clock"]
	state.turn = 3
	check(state.effects()["damage"] == 30, "Echo repeats the strongest attack regardless of acquisition or bounding box")
	state = fixture()
	state.items.clear()
	state.fight = 5
	state.prepare_enemy()
	result = state.outcome(state.effects())
	check(result["poison_after"] == 2, "Newly inflicted poison retains all stacks")
	state.player_poison = 2
	result = state.outcome(state.effects())
	check(result["special_taken"] == 2 and result["poison_after"] == 3, "Existing poison ticks and decays before new stacks arrive")
	state = fixture()
	state.items.clear()
	state.add_item("thorn_mail", Vector2i.ZERO)
	state.fight = 11
	state.prepare_enemy()
	state.enemy["hp"] = 3
	state.hp = 5
	result = state.outcome(state.effects())
	check(result["hp_after"] == 4 and result["enemy_hp_after"] == 0, "Lethal thorns interrupts remaining enemy strikes")
	state = fixture()
	state.items.clear()
	state.add_item("venom_dagger", Vector2i.ZERO)
	result = state.end_turn()
	check(result["poison_tick"] == 3 and state.history.has("Poison dealt 3 damage to %s." % state.enemy["name"]), "Battle record logs actual poison tick, without counting retained stacks twice")

func _progression_checks() -> void:
	var state: PackRun = PackRun.new()
	state.reset(17)
	var milestone_count: int = 0
	for floor_index in range(20):
		check(state.fight == floor_index, "Floor advancement %d" % (floor_index + 1))
		if floor_index == 0:
			check(state.phase == PackRun.Phase.FIGHT and state.relic_offers.size() == 3, "Relic choices at floor %d" % (floor_index + 1))
			state.choose_relic(state.relic_offers[0])
			milestone_count += 1
		check(state.phase == PackRun.Phase.FIGHT, "Each encounter is ready for an attack")
		# Isolate the floor/reward state machine; balance runs use untouched enemies.
		state.enemy["hp"] = 1
		state.hp = state.max_hp
		state.end_turn()
		check(state.phase == PackRun.Phase.LOOT and state.offers.size() == 3, "Every floor awards an item, including floor20")
		state.advance_encounter()
		if state.phase == PackRun.Phase.SELECTOR:
			check(state.display_floor() == floor_index + 1, "Selector preserves completed depth")
			state.choose_destination("combat")
		state.choose_loot(state.offers[0])
	check(state.phase == PackRun.Phase.VICTORY and state.items.size() == 23 and milestone_count == 1, "Twenty combat rewards, starting relic and victory")
	for index in range(20):
		state = fixture()
		state.fight = index
		state.prepare_enemy()
		if state.phase == PackRun.Phase.RELIC:
			state.choose_relic(state.relic_offers[0])
		var expected: Dictionary = state.outcome(state.effects())
		state.end_turn()
		check(state.hp == expected["hp_after"] and state.enemy["hp"] == expected["enemy_hp_after"], "Enemy %d preview matches outcome" % index)

func _mouse(at: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func _motion(at: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	root.push_input(event, true)

func _click(button: Control) -> void:
	var at: Vector2 = button.get_global_rect().get_center()
	_motion(at)
	_mouse(at, true)
	_mouse(at, false)

func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)

func _drag_checks() -> void:
	game.start_run("ranger", 7)
	game._open_reward(true)
	_click(game.choice_buttons[0])
	var board: BackpackBoard = game.board
	game.run.items.clear()
	var bow: Dictionary = game.run.add_item("shortbow", Vector2i(0, 0))
	var knife: Dictionary = game.run.add_item("rusty_knife", Vector2i(1, 0))
	game._refresh()
	check(board.hit_item(BackpackBoard.ORIGIN + Vector2(BackpackBoard.STEP + 32, 32)) == knife, "Hit testing reaches item inside another item's empty corner")
	var start: Vector2 = board.global_position + BackpackBoard.ORIGIN + Vector2(23, BackpackBoard.STEP + 28)
	_motion(start)
	_mouse(start, true)
	check(board.dragging == bow and game.action.disabled, "Actual pointer grabs lower part of irregular item")
	var original_grab: Vector2 = board.grab
	_key(KEY_Q)
	check(board.drag_rotation == 3, "Q rotates counterclockwise")
	_key(KEY_E)
	check(board.drag_rotation == 0 and board.grab.is_equal_approx(original_grab), "E undoes Q with grab offset preserved")
	for index in range(4):
		_key(KEY_E)
	check(board.drag_rotation == 0 and board.grab.is_equal_approx(original_grab), "Four clockwise rotations preserve original orientation and grab")
	var target: Vector2 = board.global_position + BackpackBoard.ORIGIN + Vector2(3, 1) * BackpackBoard.STEP + board.grab
	_motion(target)
	await _snapshot("v2-07-shaped-drag")
	_mouse(target, false)
	check(bow["cell"] == Vector2i(3, 1), "Shaped drag snaps by anchor")
	board.begin_drag(bow, board.item_rect(bow).position + Vector2(20, 20))
	_key(KEY_Q)
	target = board.global_position + BackpackBoard.ORIGIN + Vector2(3, 1) * BackpackBoard.STEP + board.grab
	_motion(target)
	_mouse(target, false)
	check(bow["rotation"] == 3 and bow["cell"] == Vector2i(3, 1), "Counterclockwise rotation commits with placement")
	board.begin_drag(bow, board.item_rect(bow).position + Vector2(PackRun.offsets(bow)[0]) * BackpackBoard.STEP + Vector2(20, 20))
	_key(KEY_E)
	target = board.global_position + BackpackBoard.ORIGIN + Vector2(3, 1) * BackpackBoard.STEP + board.grab
	_motion(target)
	_mouse(target, false)
	check(bow["rotation"] == 0 and bow["cell"] == Vector2i(3, 1), "Clockwise rotation commits with placement")
	board.begin_drag(bow, board.item_rect(bow).position + Vector2(20, 20))
	board.drop_at(BackpackBoard.ORIGIN + Vector2(PackRun.GRID - Vector2i.ONE) * BackpackBoard.STEP + board.grab)
	check(bow["cell"] == Vector2i(3, 1), "Out-of-bounds shape returns to origin")
	board.begin_drag(bow, board.item_rect(bow).position + Vector2(20, 20))
	_key(KEY_Q)
	_key(KEY_ESCAPE)
	check(bow["rotation"] == 0 and board.dragging.is_empty(), "Escape cancels orientation and position changes")
	board.begin_drag(bow, board.item_rect(bow).position + Vector2(20, 20))
	board.drop_at(game.storage_button.get_global_rect().get_center() - board.global_position)
	check(bow["cell"] == null, "Shaped item can be unpacked")
	for key in PackCatalog.ROSTER:
		game.run.add_item(key)
	game._toggle_storage()
	board.refresh()
	var stash: Array[Dictionary] = board.unpacked()
	check(game.storage.bodies.size() == stash.size(), "All unused items coexist in the physics pile")
	board.begin_drag(stash[0], board.item_rect(stash[0]).get_center())
	check(board.dragging == stash[0], "Physics stash item can be picked for backpack placement")
	board.cancel_drag()
	check(game.storage.bodies.size() == stash.size(), "Cancelling preserves every stashed item")
	await _snapshot("v2-08-inventory")

func _ui_reward_checks() -> void:
	game.start_run("mage", 14)
	game._open_reward(true)
	_click(game.choice_buttons[0])
	game.front.settings["combat_speed"] = 4
	# Pin reward flow independently of finite-resource build balance.
	game.run.enemy["hp"] = 1
	_click(game.action)
	while game.busy or game.playback.active or game.gameplay_background.transitioning:
		await process_frame
	check(game.run.fight == 1 and not game.modal.visible, "Forced-lethal first-floor fixture defers loot")
	game._open_reward(false)
	await _snapshot("v2-09-loot")
	_click(game.choice_buttons[0])
	check(game.run.fight == 1 and game.run.items.size() == 4, "Loot button grants item and advances")
	await _wait_for_action()
	game.run.hp = 1
	game.run.items.clear()
	game._refresh()
	_click(game.action)
	await _wait_for_action()
	check(game.run.phase == PackRun.Phase.DEFEAT and game.modal_kind == "result", "Death result reachable")
	await _snapshot("v2-10-defeat")
	_click(game.result_buttons[0])
	check(game.front.selection.visible, "New descent returns to class selection")
	game.start_run("warrior", 3)
	game._open_reward(true)
	_click(game.choice_buttons[0])

func _layout_checks() -> void:
	var bounds: Rect2 = Rect2(0, 0, 1280, 800)
	for child in game.combat.get_children():
		if child is Control and child.visible:
			check(bounds.encloses(child.get_global_rect()), "Combat control fits: " + child.name)
	check(game.enemy_bar.size.y >= 24 and game.hp_bar.size.y >= 24, "Framed health bars remain readable")

func _all_copy_checks() -> void:
	for key in PackCatalog.ROSTER:
		game._close_modal()
		game.run.phase = PackRun.Phase.FIGHT
		game.run.offers.assign([key, key, key])
		game.run.item_rewards.assign([{ "floor": 1, "offers": [key, key, key]}])
		game._open_reward(false)
		var tooltip_item: Dictionary = game.run.add_item(key)
		var tooltip: Control = game.board._make_custom_tooltip(str(tooltip_item["id"]))
		root.add_child(tooltip)
		await process_frame
		await process_frame
		for index in range(3):
			var card: Button = game.choice_buttons[index]
			check(Rect2(Vector2.ZERO, card.size).encloses(game.choice_details[index].get_rect()), key + " reward description fits")
			check(game.choice_shapes[index].get_meta("cells").size() == PackCatalog.item(key)["mask"].size(), key + " reward shows occupied shape")
		var readable_copy: String = tooltip.get_node("Description").get_parsed_text().replace(" \u2060\u00a0", "").replace("\ufffc", "")
		check(readable_copy == PackCatalog.item(key)["detail"], key + " tooltip explains the full effect")
		check(tooltip.size.y < 500 and tooltip.size.x < 400, key + " tooltip fits the screen")
		tooltip.free()
	for key in PackCatalog.RELICS:
		game._close_modal()
		game.run.phase = PackRun.Phase.FIGHT
		game.run.relic_rewards.assign([1])
		game.run.relic_offers.assign([key, key, key])
		game._open_reward(true)
		await process_frame
		await process_frame
		check(Rect2(Vector2.ZERO, game.choice_buttons[0].size).encloses(game.choice_details[0].get_rect()), key + " relic description fits: card=%s detail=%s" % [game.choice_buttons[0].size, game.choice_details[0].get_rect()])
	game.start_run("warrior", 3)
	game._open_reward(true)
	_click(game.choice_buttons[0])

func _resolution_checks() -> void:
	if not render:
		return
	for dimensions in [Vector2i(960, 600), Vector2i(1600, 900), Vector2i(800, 900)]:
		root.size = dimensions
		await create_timer(0.1).timeout
		_layout_checks()
		check(root.get_visible_rect().size.is_equal_approx(Vector2(1280, 800)), "Logical canvas preserved at %s" % dimensions)
		await _snapshot("v2-size-%dx%d" % [dimensions.x, dimensions.y])

func _snapshot(filename: String) -> void:
	if not render:
		await process_frame
		await process_frame
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(preload("res://tests/support/artifact_paths.gd").path())
	var picture: Image = root.get_texture().get_image()
	check(not picture.is_empty(), "Framebuffer nonempty: " + filename)
	var background: Color = picture.get_pixel(0, 0)
	var visible_samples: int = 0
	# A sparse 20px lattice can miss the small glyphs of pixel fonts entirely.
	# Sample densely enough to detect the foreground in text-only dialogs.
	for y in range(0, picture.get_height(), 4):
		for x in range(0, picture.get_width(), 4):
			var pixel: Color = picture.get_pixel(x, y)
			if absf(pixel.r - background.r) + absf(pixel.g - background.g) + absf(pixel.b - background.b) > 0.3:
				visible_samples += 1
	check(visible_samples > 200, "Framebuffer contains foreground content: " + filename)
	picture.save_png(preload("res://tests/support/artifact_paths.gd").path("%s.png") % filename)
