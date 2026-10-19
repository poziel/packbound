extends "res://tests/support/test_case.gd"
## Render actual sprite pixels to verify environment and local Light3D response.
var game: Control
var background: Control
var world: Node3D
var render: SubViewport
var directory := preload("res://tests/support/artifact_paths.gd").path("monster-lighting")

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func draw() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func sample_sprite() -> Color:
	var image: Image = render.get_texture().get_image()
	var sprite: Sprite3D = world.enemy
	var source: Image = sprite.texture.get_image()
	var used: Rect2i = source.get_used_rect()
	var total := Vector3.ZERO
	var count: int = 0
	for y: int in range(used.position.y + 2, used.end.y - 2, 3):
		for x: int in range(used.position.x + 2, used.end.x - 2, 3):
			if source.get_pixel(x, y).a < 0.99:
				continue
			var local := Vector3((x + 0.5 - sprite.SOURCE_ANCHOR.x) * sprite.pixel_size, -(y + 0.5 - sprite.SOURCE_ANCHOR.y) * sprite.pixel_size, 0)
			var pixel := Vector2i(world.camera.unproject_position(sprite.to_global(local)))
			if not Rect2i(Vector2i.ZERO, image.get_size()).has_point(pixel):
				continue
			var color: Color = image.get_pixelv(pixel)
			total += Vector3(color.r, color.g, color.b)
			count += 1
	return Color(total.x / maxi(1, count), total.y / maxi(1, count), total.z / maxi(1, count), 1)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	create_timer(30).timeout.connect(func() -> void: printerr("Monster lighting test timed out"); quit(2))
	DirAccess.make_dir_recursive_absolute(directory)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	game.start_run("warrior", 42)
	game._choose(0)
	background = game.gameplay_background
	world = background.world
	render = background.get_node("Render/Viewport")
	game.enemy_card.set_feedback_paused(true)
	check(world.enemy.shaded, "Shared monster sprite receives 3D lighting by default")
	var authored_shading: bool = world.enemy.shaded
	for biome: String in ["stone", "cursed"]:
		world.set_room(background.encounter_room if biome == "stone" else background.deeper_encounter_room)
		game._refresh()
		for fight: int in [0, 8]:
			game.run.fight = fight
			game.run.prepare_enemy()
			game._refresh()
			world.enemy.shaded = false
			await draw()
			viewport.get_texture().get_image().save_png(directory + "/%s-%s-unlit.png" % [biome, game.run.enemy["key"]])
			var original: Color = sample_sprite()
			world.enemy.shaded = true
			await draw()
			viewport.get_texture().get_image().save_png(directory + "/%s-%s-lit.png" % [biome, game.run.enemy["key"]])
			var lit: Color = sample_sprite()
			check(Vector3(lit.r, lit.g, lit.b).distance_to(Vector3(original.r, original.g, original.b)) > 0.03, "Actual room lighting affects " + biome + " / " + game.run.enemy["key"])
			check(lit.r * 0.2126 + lit.g * 0.7152 + lit.b * 0.0722 > 0.085, "Lit monster keeps readable midtones in " + biome + " / " + game.run.enemy["key"])
			print("LIGHTING ", biome, " / ", game.run.enemy["key"], ": unlit ", original, " -> lit ", lit)
			viewport.get_texture().get_image().save_png(directory + "/%s-%s-lantern-on.png" % [biome, game.run.enemy["key"]])
			world.lantern.power = 0.0
			await draw()
			var without_lantern: Color = sample_sprite()
			viewport.get_texture().get_image().save_png(directory + "/%s-%s-lantern-off.png" % [biome, game.run.enemy["key"]])
			var lantern_brightness: float = lit.r * 0.2126 + lit.g * 0.7152 + lit.b * 0.0722
			var room_brightness: float = without_lantern.r * 0.2126 + without_lantern.g * 0.7152 + without_lantern.b * 0.0722
			check(lantern_brightness > room_brightness + 0.02, "Carried lantern brightens the monster in " + biome + " / " + game.run.enemy["key"])
			print("LANTERN ", biome, " / ", game.run.enemy["key"], ": room ", room_brightness, " -> carried light ", lantern_brightness)
			var previous := OmniLight3D.new()
			previous.light_color = Color(1.0, 0.87, 0.72)
			previous.light_energy = 4.0
			previous.light_specular = 0.0
			previous.light_cull_mask = 3
			previous.omni_range = 20.0
			world.lantern.add_child(previous)
			await draw()
			var previous_color: Color = sample_sprite()
			var previous_brightness: float = previous_color.r * 0.2126 + previous_color.g * 0.7152 + previous_color.b * 0.0722
			check(lantern_brightness > previous_brightness * 1.04, "Focused lantern brightens the monster more than the previous broad glow in " + biome + " / " + game.run.enemy["key"])
			print("FOCUSED / PREVIOUS: ", lantern_brightness, " / ", previous_brightness)
			previous.queue_free()
			world.lantern.power = 1.0
	# Isolate local-light response on the sprite's own rendering layer.
	world.lantern.power = 0.0
	for light: Light3D in world.active_room.find_children("*", "Light3D", true, false):
		light.hide()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 0.0
	world.world_environment.environment = environment
	var test_light := OmniLight3D.new()
	test_light.light_cull_mask = world.enemy.layers
	test_light.omni_range = 10.0
	test_light.light_energy = 3.0
	world.add_child(test_light)
	test_light.global_position = world.enemy.global_position + Vector3(0, 1.5, 3)
	test_light.light_color = Color.RED
	await draw()
	var red: Color = sample_sprite()
	test_light.light_color = Color.BLUE
	await draw()
	var blue: Color = sample_sprite()
	print("LOCAL LIGHT: red ", red, " / blue ", blue)
	check(red.r > blue.r + 0.08 and blue.b > red.b + 0.08, "Changing a 3D light's color changes the rendered monster pixels")
	test_light.position.z += 100.0
	await draw()
	var distant: Color = sample_sprite()
	check(distant.r + distant.g + distant.b < (blue.r + blue.g + blue.b) * 0.25, "Moving the light beyond its range removes its illumination from the monster")
	check(world.enemy.modulate == Color.WHITE, "Environment response does not paint a fixed tint onto the monster")
	check(not game.enemy_card.world_flash.shaded, "Hit flash retains clear feedback independently of room darkness")
	world.enemy.shaded = authored_shading
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, viewport)
	report("MONSTER LIGHTING RESULT")
	quit(1 if failures else 0)
