extends SceneTree
## Exercise biome boundaries through actual run restoration and floor travel.
var checks: int = 0
var failures: int = 0
var game: Control
var swapped_under_black: bool = false

const STONE: String = "res://scenes/gameplay/rooms/dungeon/dungeon_room.tscn"
const CURSED: String = "res://scenes/gameplay/rooms/cursed/cursed_room.tscn"

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func restore_floor(floor_number: int) -> void:
	game.run.fight = floor_number - 1
	game.run.prepare_enemy()
	var saved: Dictionary = game.run_saves.capture(game.run, 15.0, game.playback)
	saved["id"] = game.active_run_id
	game.start_run("warrior", -1, saved)

func _run() -> void:
	create_timer(25).timeout.connect(func() -> void: printerr("Biome test timed out"); quit(2))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var background: Control = game.gameplay_background
	check(background.has_method("room_for_floor"), "Gameplay has a floor-based biome selection")
	if failures:
		await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
		print("FLOOR BIOME RESULT: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	for floor_number: int in range(1, 21):
		check(background.room_for_floor(floor_number).resource_path == (STONE if floor_number <= 10 else CURSED), "Correct biome for floor %d" % floor_number)
	game.start_run("warrior", 42)
	game._choose(0)
	for floor_number: int in [10, 11, 20]:
		restore_floor(floor_number)
		check(background.world.active_room.scene_file_path == (STONE if floor_number <= 10 else CURSED), "Resumed floor %d immediately restores its biome" % floor_number)
	game.start_run("warrior", 42)
	game._choose(0)
	check(background.world.active_room.scene_file_path == STONE, "Starting again restores the first biome")
	restore_floor(10)
	var stone_room_id: int = background.world.active_room.get_instance_id()
	background.world.room_changed.connect(func() -> void:
		if background.world.active_room.scene_file_path == CURSED:
			swapped_under_black = background.fade.modulate.a > 0.999 and not game.enemy_card.visible
	)
	game.front.settings["combat_speed"] = 4
	game.run.phase = PackRun.Phase.LOOT
	game._advance_encounter()
	check(background.world.active_room.get_instance_id() == stone_room_id and game.busy, "Floor 10 departure stays in the stone room")
	while game.busy:
		await process_frame
	check(swapped_under_black, "Floor 11 biome swaps only under full darkness before enemy reveal")
	check(game.run.fight == 10 and background.world.active_room.scene_file_path == CURSED, "Arrival reaches floor 11 in Cursed Depths")
	check(background.world.camera.position.is_equal_approx(background.world.camera_home), "Floor 11 arrival settles at the new room's camera")
	var cursed_id: int = background.world.active_room.get_instance_id()
	game.run.phase = PackRun.Phase.LOOT
	game._advance_encounter()
	while game.busy:
		await process_frame
	check(game.run.fight == 11 and background.world.active_room.get_instance_id() == cursed_id, "Floor 12 reuses the cursed room")
	restore_floor(20)
	game.run.phase = PackRun.Phase.LOOT
	game._advance_encounter()
	check(game.run.phase == PackRun.Phase.VICTORY and not background.transitioning and background.world.active_room.scene_file_path == CURSED, "Floor 20 victory keeps its biome without a floor 21 transition")
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	print("FLOOR BIOME RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
