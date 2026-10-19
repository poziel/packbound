extends "res://tests/prototype_test.gd"
## Rendered review also checks projected interaction targets at game resolution.

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run_saves.directory = "res://workspace/logs/selector-render-saves"
	game.start_run("warrior", 42)
	game.active_run_id = ""
	game.run.hp = 12
	for depth: int in [1, 10]:
		for count in range(2, 5):
			game.run.floor_index = depth - 1
			game.run.fight = depth - 1
			game.run.phase = PackRun.Phase.SELECTOR
			game.run.door_choices.clear()
			for index in range(count):
				var kind: String = ["combat", "relic", "rest", "encounter"][index]
				game.run.door_choices.append({"id": kind, "kind": kind})
			game.gameplay_background.world.set_room(game.gameplay_background.scene_for_state(game.run))
			game._configure_floor_scene()
			game._refresh()
			await frames()
			if depth == 1:
				var active: Node3D = game.gameplay_background.world.active_room
				var view_camera: Camera3D = game.gameplay_background.world.camera
				var midpoint_x: float = 0.0
				for door: Node3D in active.visible_doors():
					midpoint_x += view_camera.unproject_position(door.get_node("Interaction").global_position).x
				midpoint_x /= active.visible_doors().size()
				check(absf(midpoint_x - view_camera.get_viewport().size.x * 0.25) < 1.0, "Door bank centers on the left gameplay controls with %d choices" % count)
			for button: Button in game.floor_flow.door_buttons:
				check(button.get_global_rect().position.x >= 16 and button.get_global_rect().end.x <= 640, "Door targets remain in the gameplay half")
				check(button.get_global_rect().position.y >= 65 and button.get_global_rect().end.y <= 580, "Door targets stay clear of heading and action controls")
			await capture("selector-%s-%d" % ["dungeon" if depth == 1 else "cursed", count])
			if count == 4:
				var room: Node3D = game.gameplay_background.world.active_room
				var doors: Array[Node3D] = room.visible_doors()
				var selected_light: OmniLight3D = _door_light(doors[1])
				var unselected: float = selected_light.light_energy
				game.floor_flow._highlight("relic")
				await create_timer(0.24).timeout
				check(selected_light.light_energy > unselected + 2, "Hover lights the doorway from inside")
				check(_door_light(doors[0]).light_energy < 0.2, "Other doorways remain unselected")
				await frames()
				check(doors[1].get_node("Sign").modulate.is_equal_approx(doors[1].hover_glow_color) and doors[1].get_node("Sign").outline_modulate.is_equal_approx(doors[1].hover_glow_color), "Rendered sign fill and outline match the door glow")
				await capture("selector-%s-hover" % ["dungeon" if depth == 1 else "cursed"])
				if depth == 1:
					game.gameplay_background.transitioning = true
					game.gameplay_background.fade.show()
					var high: float = 0.0
					for amount: float in [0.2, 0.5, 0.85, 1.0]:
						game.gameplay_background._reveal_room(amount)
						if amount == 0.2:
							high = game.gameplay_background.world.camera.position.y
						await frames()
						await capture("selector-dungeon-arrival-%02d" % roundi(amount * 100))
					check(high > game.gameplay_background.world.camera.position.y + 2.0, "Selector arrival descends the dungeon's full staircase before approaching doors")
					check(game.gameplay_background.world.camera.position.is_equal_approx(game.gameplay_background.world.camera_home), "Arrival settles at the front-facing door position")
					room.select_exit("rest")
					room.highlight("rest")
					for amount: float in [0.3, 0.65, 1.0]:
						game.gameplay_background._advance_passage(amount)
						await frames()
						await capture("selector-dungeon-departure-%02d" % roundi(amount * 100))
					check(game.gameplay_background.world.camera.position.y < game.gameplay_background.world.camera_home.y - 3.5, "Departure uses the full dungeon exit stair rise")
					check(game.gameplay_background.world.camera.global_position.is_equal_approx(room.travel_marker("ExitEnd").global_position), "Departure reaches the chosen door's actual stair bottom")
					game.gameplay_background.world.reset_camera()
					game.gameplay_background.fade.hide()
					game.gameplay_background.transitioning = false
	for kind: String in ["rest", "relic", "encounter"]:
		game.run.floor_index = 0
		game.run.phase = PackRun.Phase.SELECTOR
		game.run.door_choices.assign([{"id": kind, "kind": kind}])
		game.run.choose_destination(kind)
		game.gameplay_background.world.set_room(game.gameplay_background.scene_for_state(game.run))
		game._refresh()
		await frames()
		await capture("room-" + kind)
		# Retain a scenery-only review alongside the real choice UI capture.
		game.floor_flow.activity_panel.hide()
		await frames()
		await capture("room-" + kind + "-scenery")
		game.floor_flow.activity_panel.show()
	check(not game.enemy_card.visible and not game.gameplay_background.enemy.has_spawn, "Noncombat rendered view has no enemy")
	print("FLOOR RENDER: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)

func frames() -> void:
	for index in range(5):
		await process_frame
	await RenderingServer.frame_post_draw

func _door_light(door: Node3D) -> OmniLight3D:
	var stairs_light: OmniLight3D = door.get_node_or_null("ExitStairs/Visuals/InteriorLight")
	return stairs_light if stairs_light else door.get_node("Glow")

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png("res://workspace/logs/" + label + ".png")
