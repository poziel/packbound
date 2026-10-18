extends "res://tests/prototype_test.gd"

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(2))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run("warrior", 42)
	game._open_reward(true)
	game._choose(0)
	await process_frame
	await process_frame
	var card: PackEnemyCard = game.enemy_card
	var sprite: Sprite3D = game.gameplay_background.enemy
	var rat_shadow: float = card.shadow.mesh.size.x
	check(card.shadow.visible and not card.flying, "Grounded rat has a shadow and no hover")
	for key: String in ["mirror_wisp", "carrion_swarm", "rust_knight"]:
		game.enemy_art.texture = PackArt.enemy(key)
		sprite.set_art(game.enemy_art.texture)
		card.set_monster(key)
		check(card.flying == (key != "rust_knight"), "Explicit flying classification: " + key)
		check(card.shadow.mesh.size.x > rat_shadow, "Shadow follows actual silhouette width: " + key)
		check(card.world_flash.texture.get_image().get_used_rect() == sprite.texture.get_image().get_used_rect(), "Flash preserves silhouette alpha: " + key)
		await _capture(key)
	card.set_monster("mirror_wisp")
	card.hover_time = 0.45
	card._apply_pose()
	check(sprite.position.y > card.world_rest.y, "Flying body lifts smoothly")
	check(is_equal_approx(card.shadow.position.y, 0.055), "Flying shadow stays on floor")
	var frozen: float = card.hover_time
	card.set_feedback_paused(true)
	card._process(0.3)
	check(is_equal_approx(card.hover_time, frozen), "Pause freezes hover")
	card.set_feedback_paused(false)
	card.hover_time = 0
	var hit: Tween = card.play_hit(true)
	hit.pause()
	hit.custom_step(0.07)
	card._apply_pose()
	check(sprite.scale.x > 1.1 and sprite.scale.y < 0.9, "Impact squashes wide and short")
	check(card.flash_color.is_equal_approx(Color.WHITE), "Opaque white silhouette at first peak")
	await _capture("white-squash")
	hit.custom_step(0.09)
	card._apply_pose()
	check(sprite.scale.x < 0.95 and sprite.scale.y > 1.08, "Rebound stretches tall and narrow")
	check(card.flash_color.r > 0.8 and card.flash_color.g < 0.2, "Rebound changes to red")
	await _capture("red-stretch")
	hit.custom_step(0.15)
	card._apply_pose()
	check(sprite.scale.is_equal_approx(Vector3.ONE) and is_zero_approx(card.flash_color.a), "Hit restores exact scale and palette")
	game._sync_enemy_vitals()
	check(absf(game.enemy_vitals.get_global_rect().end.y - game.gameplay_background.enemy_screen_bounds().position.y + 12) <= 1, "Vitals follow the current silhouette after impact")
	hit = card.play_hit(false)
	hit.pause()
	hit.custom_step(0.07)
	check(is_zero_approx(card.flash_color.a) and card.reaction_scale.x > 1.1, "Flash-off keeps squash without tint")
	card.reset_feedback()
	var strike: Tween = card.play_strike()
	strike.pause()
	strike.custom_step(0.09)
	card._apply_pose()
	check(sprite.position.z > card.world_rest.z and sprite.position.y < card.world_rest.y and sprite.scale.x > 1.1, "Strike slides down and approaches camera with zoom")
	await _capture("attack-approach")
	strike.custom_step(0.2)
	card._apply_pose()
	check(is_zero_approx(card.approach), "Strike returns to idle")
	for speed: float in [1.0, 4.0]:
		card.reset_feedback()
		hit = card.play_hit(true, speed, true)
		hit.pause()
		hit.custom_step(0.31 / speed)
		check(card.defeated and not sprite.visible and not card.shadow.visible, "Lethal hit removes body and shadow at speed %s" % speed)
		check(not card.death_pixels.pieces.is_empty(), "Lethal debris samples body pixels at speed %s" % speed)
		card.death_pixels.paused = true
		await _capture("death-%s" % speed)
		card.death_pixels.paused = false
		card.set_feedback_paused(true)
		card.death_pixels._process(0.2)
		check(is_zero_approx(card.death_pixels.elapsed), "Pause freezes death debris")
		card.set_feedback_paused(false)
		card.death_pixels._process(0.43 / speed)
		check(card.death_pixels.pieces.is_empty(), "Debris finishes at combat speed")
	card.reset_feedback()
	check(sprite.visible and card.shadow.visible and card.death_pixels.pieces.is_empty(), "Reset removes death state and restores next encounter")
	game.start_run("ranger", 42)
	game.front.settings["combat_speed"] = 4
	game.run.items.clear()
	game.run.relics.clear()
	game.run.add_item("thorn_mail", Vector2i.ZERO)
	game.run.enemy["hp"] = 2
	game.run.enemy["attacks"] = [5]
	game._refresh()
	game._act()
	await game.playback.monster_resolved
	check(game.run.enemy["hp"] == 0 and not card.defeated, "Retaliation kill first shows the monster's approach")
	await create_timer(0.16).timeout
	check(card.defeated and not card.death_pixels.pieces.is_empty() and game.playback.active, "Retaliation gets hit and death feedback before fight finishes")
	await create_timer(0.12).timeout
	check(not game.playback.active and game.run.fight == 1, "Retaliation death completes before descent")
	print("MONSTER ANIMATION RESULT: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tmp/monster-%s.png" % label)
