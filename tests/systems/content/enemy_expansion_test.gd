extends "res://tests/support/prototype_support.gd"

const EXPANSION = preload("res://systems/enemies/enemy_expansion.gd")
const PRESENTATION = preload("res://systems/enemies/enemy_presentation.gd")

func _run() -> void:
	var all: Array[Dictionary] = PackCatalog.enemies()
	check(all.size() == 56, "Twenty originals plus thirty-six new enemies")
	check(PackRun.FLOORS == 20, "Run length stays twenty floors")
	check(all[0].key == "ash_rat" and all[19].key == "zippered_maw", "Original encounter indices remain stable")
	var seen: Dictionary = {}
	var library: Resource = load("res://assets/enemies/presentation.tres")
	for enemy: Dictionary in all:
		check(not seen.has(enemy.key), "Unique enemy ID: " + enemy.key)
		seen[enemy.key] = true
		check(PackArt.ENEMY_TEXTURES.has(enemy.key), "Registered art: " + enemy.key)
		check(library.profile_for(enemy.key) != null, "Editable presentation: " + enemy.key)
	for floor_number in range(1, 21):
		var pool: Array[Dictionary] = EXPANSION.pool(floor_number, all[floor_number - 1])
		check(pool.size() == (1 if floor_number in [1, 20] else 3), "Floor-matched pool: %d" % floor_number)
	var selectable: Dictionary = {}
	for seed_value in range(80):
		var state: PackRun = fixture()
		state.rng.seed = seed_value
		for floor_number in range(2, 20):
			state.floor_index = floor_number - 2
			state.phase = PackRun.Phase.SELECTOR
			state.door_choices = [{"id": "combat", "kind": "combat"}]
			check(state.choose_destination("combat"), "Combat route commits")
			check(state.enemy.key in EXPANSION.pool(floor_number, all[floor_number - 1]).map(func(e: Dictionary): return e.key), "Selected enemy belongs to the correct floor")
			selectable[state.enemy.key] = true
	for enemy: Dictionary in EXPANSION.profiles():
		check(selectable.has(enemy.key), "New enemy reachable through actual route: " + enemy.key)
		var state: PackRun = fixture()
		state.prepare_enemy(enemy)
		var saves := PackRunSaves.new()
		var snapshot: Dictionary = saves.capture(state, 0)
		var reopened: PackRun = fixture()
		saves.restore(reopened, snapshot)
		check(reopened.enemy == state.enemy, "Selected profile survives save/restore: " + enemy.key)
		check(reopened.rng.state == state.rng.state, "RNG survives save/restore")
		for round_number in range(1, 5):
			state.turn = round_number
			var expected: int = int(enemy.attacks[(round_number - 1) % enemy.attacks.size()]) + int(enemy.enrage) * (round_number - 1)
			check(state.attack() == expected, "Attack cycle and enrage execute: " + enemy.key)
		var body: Rect2i = PackArt.enemy(enemy.key).atlas.get_image().get_used_rect()
		check(body.size.x <= 256 and body.size.y <= 256, "Body fits source limit: " + enemy.key)
		check(body.position.x > 0 and body.end.x < 288 and body.position.y > 0 and body.end.y < 320, "Complete silhouette has transparent margins")
		check(not PRESENTATION.skills(enemy).is_empty() or int(enemy.hits) > 1, "Inspection explains abilities or multi-attack stat: " + enemy.key)
		var source := "res://assets/enemies/%s/art/%s.pixloom" % [enemy.key, enemy.key]
		check(FileAccess.file_exists(source), "Native editable Pixloom source: " + enemy.key)
		# Exercise the shared resolver with no equipment to isolate authored skills.
		state.items.clear()
		state.turn = 1
		state.hp = 1000
		state.max_hp = 1000
		state.enemy.hp = int(enemy.hp) - 10
		var response: Dictionary = state.outcome(state.effects())
		var incoming: int = int(enemy.attacks[0]) * int(enemy.hits)
		check(response.taken == incoming, "Authored strike count resolves into health damage: " + enemy.key)
		check(int(response.poison_after) == (int(enemy.poison) if incoming > 0 else 0), "Poison applies once only after health damage")
		var healing: int = int(enemy.regen) + (int(enemy.drain) if incoming > 0 else 0)
		check(int(response.enemy_hp_after) == mini(int(enemy.hp), int(enemy.hp) - 10 + healing), "Regeneration and life drain use authored values")
	# Pool calls return independent dictionaries; combat mutation cannot alter authoring.
	var mutated: Array[Dictionary] = EXPANSION.profiles()
	mutated[0].hp = 1
	check(EXPANSION.profiles()[0].hp == 26, "Profile cache is isolated from combat mutation")
	report("ENEMY EXPANSION")
	quit(1 if failures else 0)
