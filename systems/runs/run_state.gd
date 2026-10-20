class_name PackRun
extends RefCounted

const CATEGORIES = preload("res://systems/content/collectible_categories.gd")

const CRAFTING = preload("res://systems/crafting/pack_crafting.gd")
const QUIVER = preload("res://systems/characters/archer_quiver.gd")
const ELEMENTS = preload("res://systems/combat/elemental_combat.gd")
const GRID: Vector2i = Vector2i(8, 7)
const FLOORS: int = 20
const RELIC_FLOORS: Array[int] = [1, 5, 10, 15]
const ROSTER: Array[String] = PackCatalog.ROSTER
const NECROMANCER_COMPANION_CAP: int = 3
const NECROMANCER_COMPANION_DAMAGE: int = 2
const MAX_ITEM_PRIORITY: int = 9
enum Phase { RELIC, FIGHT, LOOT, VICTORY, DEFEAT, SELECTOR, ROOM, ROOM_COMPLETE }
enum CombatState { PREPARING, RUNNING, PAUSED, FINISHED }

var combat_state: CombatState = CombatState.PREPARING

var items: Array[Dictionary] = []
var class_key: String = "warrior"
var undead_companions: int = 0
var max_hp: int = 40
var hp: int = 40
var block: int = 0
var carry_block: int = 0
var mana: int = 0
var stamina: int = 0
var momentum: int = 0
# Shared Momentum modifiers; Momentum has no gameplay cap.
var momentum_gain_bonus: int = 0
var momentum_cost_reduction: int = 0
# Mana/stamina capacities are the current round budgets; block retains its peak.
var resource_overrides: Dictionary = {} # Explicit developer-authored round budgets; empty in ordinary runs.
var mana_capacity: int = 0
var stamina_capacity: int = 0
var block_capacity: int = 0
var player_poison: int = 0
var enemy_poison: int = 0
var enemy_burn: int = 0
var enemy_slow: int = 0
var enemy_spark: int = 0
var enemy_doom: int = 0
var enemy_doom_turns: int = 0
var elemental_traces: Dictionary = {}
var enemy_shield_spent: int = 0
var fight: int = 0
var turn: int = 1
var total_turns: int = 0
var phase: Phase = Phase.FIGHT
var enemy: Dictionary = {}
var offers: Array[String] = []
var relics: Array[String] = []
var relic_offers: Array[String] = []
var relic_floors_claimed: Array[int] = []
var item_rewards: Array[Dictionary] = []
var relic_rewards: Array[int] = []
var last_thread_used: bool = false
var history: Array[String] = []
var stage_history: Array[Dictionary] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var next_id: int = 0
var pending_turn: Dictionary = {}
var volley_remaining: int = 3
var crafting_events: Array[Dictionary] = []
var floor_index: int = 0
var room_kind: String = "combat"
var door_choices: Array[Dictionary] = []
var noncombat_streak: int = 0
var room_resolved: bool = false
var room_event: String = ""
var room_relic_offers: Array[String] = []
var room_reward_pending: bool = false
var room_flow_version: int = 1

static func definition(key: String) -> Dictionary:
	return PackCatalog.item(key)

static func enemies() -> Array[Dictionary]:
	return PackCatalog.enemies()

func reset(seed_value: int = -1, chosen_class: String = "warrior") -> void:
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	combat_state = CombatState.PREPARING
	phase = Phase.FIGHT
	pending_turn.clear()
	resource_overrides.clear()
	items.clear()
	crafting_events.clear()
	history.clear()
	stage_history.clear()
	offers.clear()
	relics.clear()
	relic_offers.clear()
	relic_floors_claimed.clear()
	item_rewards.clear()
	relic_rewards.clear()
	next_id = 0
	class_key = chosen_class
	momentum_gain_bonus = 0
	momentum_cost_reduction = 0
	undead_companions = 1 if class_key == "necromancer" else 0
	var character: Dictionary = PackCatalog.classes()[class_key]
	max_hp = int(character["hp"])
	hp = max_hp
	fight = 0
	floor_index = 0
	room_kind = "combat"
	door_choices.clear()
	noncombat_streak = 0
	room_resolved = false
	room_event = ""
	room_relic_offers.clear()
	room_reward_pending = false
	room_flow_version = 1
	total_turns = 0
	last_thread_used = false
	for index in range(character["starters"].size()):
		var starter: Dictionary = add_item(character["starters"][index], character["positions"][index])
		starter["rotation"] = character["rotations"][index]
		starter["shape"] = dimensions(starter, starter["rotation"])
	prepare_enemy()
	if class_key == "ranger":
		item_rewards.push_front({"floor": 0, "offers": QUIVER.INITIAL.duplicate()})
		offers.assign(QUIVER.INITIAL)
	log_line("%s enters the cursed descent." % character["name"])

func quiver() -> Dictionary:
	for item in items:
		if item["key"] == QUIVER.KEY:
			return item
	return {}

func is_permanent(item: Dictionary) -> bool:
	return item.get("key", "") == QUIVER.KEY

func needs_arrows() -> bool:
	return class_key == "ranger" and not quiver().is_empty() and str(quiver().get("arrow_type", "")).is_empty()

func quiver_description() -> String:
	return QUIVER.describe(quiver(), volley_remaining, item_bonus(quiver())) if not quiver().is_empty() else ""

func add_item(key: String, cell: Variant = null) -> Dictionary:
	if not can_edit_inventory():
		return {}
	if key == QUIVER.KEY and (class_key != "ranger" or not quiver().is_empty()):
		return {}
	if QUIVER.OPTIONS.has(key):
		return {}
	var item: Dictionary = definition(key)
	if not item_enabled(item):
		return {}
	item["id"] = next_id
	next_id += 1
	item["cell"] = cell
	items.append(item)
	return item

func auto_place(item: Dictionary) -> bool:
	if not can_edit_inventory():
		return false
	# Keep the existing layout and prefer the item's current orientation.
	for quarter in range(4):
		var rotation: int = posmod(int(item["rotation"]) + quarter, 4)
		for y in range(GRID.y):
			for x in range(GRID.x):
				var cell := Vector2i(x, y)
				if can_place(item, cell, rotation):
					item["cell"] = cell
					item["rotation"] = rotation
					item["shape"] = dimensions(item, rotation)
					return true
	return false

func prepare_enemy(selected: Dictionary = {}) -> void:
	floor_index = fight
	crafting_events.clear()
	combat_state = CombatState.PREPARING
	pending_turn.clear()
	enemy = (enemies()[fight] if selected.is_empty() else selected).duplicate(true)
	enemy["max_hp"] = enemy["hp"]
	begin_stage(fight + 1, enemy["name"])
	turn = 1
	volley_remaining = int(QUIVER.stats(quiver())["interval"]) if not quiver().is_empty() else 3
	momentum = 0
	block = 0
	carry_block = 0
	mana = 0
	mana_capacity = 0
	stamina = 0
	stamina_capacity = 0
	block_capacity = 0
	player_poison = 0
	enemy_poison = 0
	enemy_burn = 0
	enemy_slow = 0
	enemy_spark = 0
	enemy_doom = 0
	enemy_doom_turns = 0
	elemental_traces.clear()
	enemy_shield_spent = 0
	phase = Phase.FIGHT
	if (fight == 0 or room_flow_version == 0) and RELIC_FLOORS.has(fight + 1) and not relic_floors_claimed.has(fight + 1) and not relic_rewards.has(fight + 1):
		relic_rewards.append(fight + 1)
		roll_relics()

func momentum_gain() -> int:
	return maxi(0, 1 + momentum_gain_bonus) if class_key == "warrior" else 0

func momentum_cost(amount: int) -> int:
	return maxi(0, amount - momentum_cost_reduction)

func spend_momentum(amount: int) -> bool:
	if class_key != "warrior" or amount < 0 or combat_state != CombatState.RUNNING or not pending_turn.is_empty():
		return false
	var cost: int = momentum_cost(amount)
	if momentum < cost:
		return false
	momentum -= cost
	return true

func roll_relics() -> void:
	if relic_rewards.is_empty() or not relic_offers.is_empty():
		return
	var available: Array[String] = []
	for key in PackCatalog.RELICS:
		if item_enabled(PackCatalog.relic(key)) and not relics.has(key) and not room_relic_offers.has(key):
			available.append(key)
	for index in range(mini(3, available.size())):
		relic_offers.append(available.pop_at(rng.randi_range(0, available.size() - 1)))

func choose_relic(key: String) -> void:
	if not can_claim_rewards() or not pending_turn.is_empty() or relic_rewards.is_empty() or not relic_offers.has(key) or relics.has(key) or not item_enabled(PackCatalog.relic(key)):
		return
	relics.append(key)
	relic_floors_claimed.append(relic_rewards.pop_front())
	relic_offers.clear()
	roll_relics()

func attack() -> int:
	var pattern: Array = enemy["attacks"]
	return int(pattern[(turn - 1) % pattern.size()]) + int(enemy["enrage"]) * (turn - 1)

func shield_capacity(at_turn: int = -1) -> int:
	var current: int = turn if at_turn < 0 else at_turn
	return int(enemy["armor"]) + (int(enemy["opening_armor"]) if current <= 2 else 0) + (int(enemy["cycle_armor"]) if current % 2 == 1 else 0) + (int(enemy["parry"]) if current % 3 == 0 else 0)

func shield() -> int:
	return maxi(0, shield_capacity() - enemy_shield_spent)

# Preserve legacy serialized armor/spent fields and APIs for existing saves.
func enemy_block() -> int:
	return shield()

func enemy_block_capacity(at_turn: int = -1) -> int:
	return shield_capacity(at_turn)

func is_invisible() -> bool:
	return class_key == "assassin" and (turn - 1) % 3 == 0

func enemy_conditions() -> Dictionary:
	return {"poison": enemy_poison, "burn": enemy_burn, "slow": enemy_slow, "spark": enemy_spark, "doom": enemy_doom}

static func offsets(item: Dictionary, rotation: int = -1) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var angle: int = int(item["rotation"]) if rotation < 0 else posmod(rotation, 4)
	var minimum: Vector2i = Vector2i(100, 100)
	for point: Vector2i in item["mask"]:
		var transformed: Vector2i = point
		for quarter in range(angle):
			transformed = Vector2i(-transformed.y, transformed.x)
		result.append(transformed)
		minimum = minimum.min(transformed)
	for index in range(result.size()):
		result[index] -= minimum
	return result

static func dimensions(item: Dictionary, rotation: int = -1) -> Vector2i:
	var extent: Vector2i = Vector2i.ZERO
	for point in offsets(item, rotation):
		extent = extent.max(point + Vector2i.ONE)
	return extent

func cells(item: Dictionary, cell: Variant = null, rotation: int = -1) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin: Variant = item["cell"] if cell == null else cell
	if origin == null:
		return result
	for point in offsets(item, rotation):
		result.append(Vector2i(origin) + point)
	return result

func can_place(item: Dictionary, cell: Vector2i, rotation: int = -1) -> bool:
	var proposed: Array[Vector2i] = cells(item, cell, rotation)
	for point in proposed:
		if point.x < 0 or point.y < 0 or point.x >= GRID.x or point.y >= GRID.y:
			return false
	for other in items:
		if other["id"] == item["id"]:
			continue
		for occupied in cells(other):
			if proposed.has(occupied):
				return false
	return true

func placement_plan(item: Dictionary, cell: Vector2i, rotation: int = -1) -> Array[Dictionary]:
	# Plan the entire displacement without mutating live items. The first displaced
	# item is held by the cursor; null cells on other moves mean the stash.
	var angle: int = int(item["rotation"]) if rotation < 0 else posmod(rotation, 4)
	var proposed: Array[Vector2i] = cells(item, cell, angle)
	if not _cells_fit(proposed, {}):
		return []
	var occupied: Dictionary = {}
	for other in items:
		if other["id"] == item["id"]:
			continue
		for point in cells(other):
			occupied[point] = other
	var displaced: Array[Dictionary] = []
	for point in proposed:
		if not occupied.has(point):
			continue
		var other: Dictionary = occupied[point]
		if not displaced.has(other):
			displaced.append(other)
	var moves: Array[Dictionary] = [{"item": item, "cell": cell, "rotation": angle, "shape": dimensions(item, angle)}]
	if displaced.is_empty():
		return moves
	# Largest occupied footprint first; ties use the original reading order.
	displaced.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["mask"].size() != b["mask"].size():
			return a["mask"].size() > b["mask"].size()
		return reading_rank(a) < reading_rank(b))
	for other in displaced:
		if is_permanent(other):
			return []
		for point in cells(other):
			occupied.erase(point)
	for point in proposed:
		occupied[point] = item
	for index in range(displaced.size()):
		var other: Dictionary = displaced[index]
		var destination: Variant = null
		var origin: Vector2i = other["cell"]
		# Squared Euclidean distance gives a circular radius, including (2, 2)
		# but excluding (3, 1). Rotation and all unrelated items stay unchanged.
		var best_distance: int = 10
		for y in range(GRID.y):
			for x in range(GRID.x):
				if index == 0:
					continue
				var at := Vector2i(x, y)
				var distance: int = (at - origin).length_squared()
				if distance < best_distance and _cells_fit(cells(other, at), occupied):
					destination = at
					best_distance = distance
		if destination != null:
			for point in cells(other, destination):
				occupied[point] = other
		moves.append({"item": other, "cell": destination, "rotation": other["rotation"], "shape": other["shape"], "held": index == 0})
	return moves

func _cells_fit(proposed: Array[Vector2i], occupied: Dictionary) -> bool:
	for point in proposed:
		if point.x < 0 or point.y < 0 or point.x >= GRID.x or point.y >= GRID.y or occupied.has(point):
			return false
	return true

func touches(a: Dictionary, b: Dictionary) -> bool:
	for first in cells(a):
		for second in cells(b):
			var dx: int = absi(first.x - second.x)
			var dy: int = absi(first.y - second.y)
			if relics.has("folded_space"):
				dx = mini(dx, GRID.x - dx)
			if dx + dy == 1 or (relics.has("diagonal_thread") and maxi(dx, dy) == 1):
				return true
	return false

func bonus(source: Dictionary, target: Dictionary) -> int:
	if source["id"] == target["id"] or not touches(source, target) or not item_enabled(source) or not item_enabled(target):
		return 0
	var supplied: Dictionary = source.get("adjacency_bonus", {})
	if CATEGORIES.matches_any(target, CATEGORIES.target_ids(supplied)):
		return int(supplied.get("stats", {}).get("block" if CATEGORIES.matches(target, &"shields") else "damage", 0))
	if source["key"] == "blood_gem" and CATEGORIES.matches_any(target, ["melee_weapons", "ranged_weapons", "magic_weapons", "quivers", "companions"]):
		return 2
	if source["key"] == "iron_charm" and CATEGORIES.matches(target, &"shields"):
		return 3
	if source["key"] in ["quiver", QUIVER.KEY] and CATEGORIES.matches(target, &"ranged_weapons"):
		return 2
	if source["key"] == "cursed_idol" and CATEGORIES.matches_any(target, ["melee_weapons", "ranged_weapons", "magic_weapons", "shields", "quivers"]):
		return 3
	return 0

func item_bonus(target: Dictionary) -> int:
	var amount: int = 0
	for source in items:
		amount += bonus(source, target)
	return amount

func supplied_bonus(source: Dictionary, target: Dictionary) -> Dictionary:
	if source.get("cell") == null or target.get("cell") == null or source["id"] == target["id"] or not touches(source, target) or not item_enabled(source) or not item_enabled(target):
		return {}
	var supplied: Dictionary = source.get("adjacency_bonus", {})
	var result: Dictionary = {}
	if CATEGORIES.matches_any(target, CATEGORIES.target_ids(supplied)):
		result = supplied.get("stats", {}).duplicate()
	if target["key"] == QUIVER.KEY:
		for stat: String in source.get("quiver_bonus", {}):
			result[stat] = int(result.get(stat, 0)) + int(source["quiver_bonus"][stat])
	if supplied.is_empty():
		var legacy: int = bonus(source, target)
		if legacy > 0:
			var stat: String = "block" if CATEGORIES.matches(target, &"shields") else "damage"
			result[stat] = int(result.get(stat, 0)) + legacy
	return result

func has_bonus(source: Dictionary, target: Dictionary) -> bool:
	for value: Variant in supplied_bonus(source, target).values():
		if int(value) != 0:
			return true
	return false

func adjacency_stats(target: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if not item_enabled(target):
		return result
	# Addition does not depend on reading order. Avoid sorting the whole pack
	# again for every recipient while evaluating a live placement preview.
	for source: Dictionary in items:
		if source.get("cell") == null or source["id"] == target["id"]:
			continue
		var supplied: Dictionary = source.get("adjacency_bonus", {})
		if supplied.is_empty() or not touches(source, target) or not CATEGORIES.matches_any(target, CATEGORIES.target_ids(supplied)) or not item_enabled(source):
			continue
		for stat: String in supplied.get("stats", {}):
			result[stat] = int(result.get(stat, 0)) + int(supplied["stats"][stat])
	return result

func item_enabled(item: Dictionary) -> bool:
	return preload("res://systems/content/content_restrictions.gd").allows(item, class_key)

func normalize_reward_restrictions() -> void:
	for reward: Dictionary in item_rewards:
		_replace_restricted_offers(reward["offers"], PackCatalog.ROSTER, false)
	if not item_rewards.is_empty():
		offers.assign(item_rewards[0]["offers"])
	else:
		_replace_restricted_offers(offers, PackCatalog.ROSTER, false)
	var deferred_pool: Array = PackCatalog.RELICS.filter(func(key: String) -> bool: return not relics.has(key) and not room_relic_offers.has(key))
	_replace_restricted_offers(relic_offers, deferred_pool, true)
	_replace_restricted_offers(room_relic_offers, available_room_relics(), true)
	if room_reward_pending and room_relic_offers.is_empty():
		room_reward_pending = false

func _replace_restricted_offers(choices: Array, pool: Array, is_relic: bool) -> void:
	# Keep valid saved rolls and RNG state. Prefer a replacement of the same rarity.
	for index: int in range(choices.size() - 1, -1, -1):
		var content: Dictionary = PackCatalog.relic(choices[index]) if is_relic else PackCatalog.item(choices[index])
		if item_enabled(content):
			continue
		var replacement: String = ""
		for key: String in pool:
			if key in choices:
				continue
			var candidate: Dictionary = PackCatalog.relic(key) if is_relic else PackCatalog.item(key)
			if not item_enabled(candidate):
				continue
			if replacement.is_empty():
				replacement = key
			if candidate.get("rarity") == content.get("rarity"):
				replacement = key
				break
		if replacement.is_empty():
			choices.remove_at(index)
		else:
			choices[index] = replacement

func volley_stats() -> Dictionary:
	var special: Dictionary = quiver()
	var result: Dictionary = QUIVER.stats(special, item_bonus(special))
	result["slow"] = 0
	if special.is_empty() or special.get("cell") == null:
		return result
	for source: Dictionary in packed():
		if not item_enabled(source) or source["id"] == special["id"] or not touches(source, special):
			continue
		var supplied: Dictionary = source.get("quiver_bonus", {})
		var arrows: int = int(supplied.get("arrows", 0))
		var upgrades: Dictionary = special.get("upgrades", {})
		result["arrows"] += arrows
		result["damage"] += arrows * (QUIVER.DAMAGE + int(upgrades.get("quiver_mechanism", 0)) + (1 if special.get("arrow_type") == "broadhead" else 0))
		result["pierce"] += arrows * (2 if special.get("arrow_type") == "bodkin" else 0)
		result["poison"] += arrows * (int(upgrades.get("quiver_poison", 0)) + (1 if special.get("arrow_type") == "venom" else 0))
		result["burn"] += arrows * int(upgrades.get("quiver_fire", 0))
		for stat: String in ["damage", "pierce", "poison", "burn", "slow"]:
			result[stat] += int(supplied.get(stat, 0))
	return result

func packed() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in items:
		if item["cell"] != null:
			result.append(item)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return reading_rank(a) < reading_rank(b) if reading_rank(a) != reading_rank(b) else int(a["id"]) < int(b["id"]))
	return result

func reading_rank(item: Dictionary) -> int:
	var rank_value: int = GRID.x * GRID.y
	for point in cells(item):
		rank_value = mini(rank_value, point.y * GRID.x + point.x)
	return rank_value

func activation_order() -> Array[Dictionary]:
	var result: Array[Dictionary] = packed()
	# Stable tie-breaks use occupied-cell reading order, then item ID.
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap: int = int(a.get("priority", 0))
		var bp: int = int(b.get("priority", 0))
		# Zero is unprioritized and allocates after every explicit level.
		if ap == 0: ap = MAX_ITEM_PRIORITY + 1
		if bp == 0: bp = MAX_ITEM_PRIORITY + 1
		if ap != bp:
			return ap < bp
		return reading_rank(a) < reading_rank(b) if reading_rank(a) != reading_rank(b) else int(a["id"]) < int(b["id"]))
	return result

func set_item_priority(item_id: int, priority: int) -> bool:
	if not can_edit_inventory() or priority < 0 or priority > MAX_ITEM_PRIORITY:
		return false
	for item in items:
		if int(item["id"]) == item_id:
			item["priority"] = priority
			return true
	return false

func can_edit_inventory() -> bool:
	return pending_turn.is_empty() and combat_state not in [CombatState.RUNNING, CombatState.PAUSED] and phase != Phase.DEFEAT

func can_claim_rewards() -> bool:
	return can_edit_inventory()

func set_combat_paused(value: bool) -> void:
	if value and combat_state == CombatState.RUNNING:
		combat_state = CombatState.PAUSED
	elif not value and combat_state == CombatState.PAUSED:
		combat_state = CombatState.RUNNING

func starting_resources() -> Dictionary:
	var resources: Dictionary = PackCatalog.base_resources(class_key)
	var passives: Dictionary = relic_passives()
	for resource: String in ["mana", "stamina", "block"]:
		resources[resource] += int(passives.get(resource, 0))
		resources[resource] += preload("res://systems/relics/expansion_relics.gd").resource_bonus(self, resource)
	var equipped: Array[Dictionary] = packed()
	for item in equipped:
		if not item_enabled(item):
			continue
		var supplied: Dictionary = adjacency_stats(item)
		resources["mana"] += int(item["mana"])
		resources["stamina"] += int(item.get("stamina", 0))
		resources["block"] += int(item["block"])
		for resource: String in ["mana", "stamina", "block"]:
			if resource != "block" or not CATEGORIES.matches(item, &"shields"):
				resources[resource] += int(supplied.get(resource, 0))
		if CATEGORIES.matches(item, &"shields"):
			resources["block"] += item_bonus(item)
		if item["key"] == "mirror_shard":
			var best: Dictionary = _mirror_target(item, equipped)
			if not best.is_empty():
				resources["block"] += floori(float(best["block"]) / 2.0)
	for resource: String in resource_overrides:
		resources[resource] = int(resource_overrides[resource])
	resources["mana"] = maxi(0, int(resources["mana"]))
	resources["stamina"] = maxi(0, int(resources["stamina"]))
	return resources

func round_resources() -> Dictionary:
	var resources: Dictionary = starting_resources()
	for item in packed():
		if not item_enabled(item):
			continue
		resources["mana"] += int(item.get("mana_per_round", 0))
		resources["stamina"] += int(item.get("stamina_per_round", 0))
	for resource: String in resource_overrides:
		resources[resource] = int(resource_overrides[resource])
	resources["mana"] = maxi(0, int(resources["mana"]))
	resources["stamina"] = maxi(0, int(resources["stamina"]))
	return resources

func _refill_round_resources() -> void:
	var resources: Dictionary = round_resources()
	mana = int(resources["mana"])
	stamina = int(resources["stamina"])
	mana_capacity = mana
	stamina_capacity = stamina

func _mirror_target(item: Dictionary, equipped: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var score: int = 0
	for other in equipped:
		var strength: int = int(other["damage"]) + int(other["block"])
		if item_enabled(other) and other["key"] != "mirror_shard" and touches(item, other) and strength > score:
			best = other
			score = strength
	return best

func start_combat() -> bool:
	if combat_state != CombatState.PREPARING or phase != Phase.FIGHT:
		return false
	if needs_arrows() or (class_key == "ranger" and (quiver().is_empty() or quiver().get("cell") == null)):
		return false
	crafting_events = CRAFTING.resolve(self)
	var resources: Dictionary = starting_resources()
	_refill_round_resources()
	block = int(resources["block"])
	block_capacity = block
	combat_state = CombatState.RUNNING
	return true

func relic_passives() -> Dictionary:
	var result: Dictionary = {}
	for key: String in relics:
		var stats: Dictionary = PackCatalog.relic(key).get("stats", {})
		for stat: String in stats:
			result[stat] = int(result.get(stat, 0)) + int(stats[stat])
	return result

func _dev_flag(key: String) -> bool:
	return bool(get_meta("pack_dev_policy", {}).get(key, false))

func effects() -> Dictionary:
	var result: Dictionary = {"item_effects": [], "active_ids": [], "dormant_ids": [], "mana_after": 0, "blood_cost": 0, "repeats": 0, "echo_item_id": -1}
	var activation_events: Array[String] = []
	result["activation_events"] = activation_events
	result.merge({"physical_damage": 0, "magical_damage": 0, "elemental_inputs": [], "reactions": [], "traces_after": elemental_traces.duplicate(true)})
	for stat in PackCatalog.STATS:
		result[stat] = 0
	var passives: Dictionary = relic_passives()
	for stat: String in ["healing", "ward", "plating"]:
		result[stat] = int(passives.get(stat, 0))
	for key: String in relics:
		var relic: Dictionary = PackCatalog.relic(key)
		var stats: Dictionary = relic.get("stats", {})
		for stat: String in stats:
			activation_events.append("%s grants +%d %s." % [relic["name"], stats[stat], stat])
	var equipped: Array[Dictionary] = packed()
	var has_hourglass: bool = false
	var resources: Dictionary = round_resources()
	if not can_edit_inventory():
		resources["block"] = block
	result["mana"] = int(resources["mana"])
	result["stamina"] = int(resources["stamina"])
	result["block"] = int(resources["block"])
	var regenerated_mana: int = 0
	var regenerated_stamina: int = 0
	var regenerated_block: int = 0
	var innate: Dictionary = PackCatalog.base_resources(class_key)
	for resource: String in ["mana", "stamina"]:
		if int(innate[resource]) > 0:
			activation_events.append("Refilled %d %s." % [innate[resource], resource])
	if class_key == "mage":
		var cleanses_traces: bool = int(enemy["cleanse"]) > 0 and turn % int(enemy["cleanse"]) == 0
		for trace: String in elemental_traces:
			var remaining: int = 0
			for life: int in elemental_traces[trace]:
				if life > 1:
					remaining += 1
			if cleanses_traces and not elemental_traces[trace].is_empty():
				activation_events.append("%s cleanses %d %s traces before casts." % [enemy["name"], elemental_traces[trace].size(), trace])
			elif remaining > 0:
				activation_events.append("%s already carries %d %s trace(s)." % [enemy["name"], remaining, trace])
			var expired: int = elemental_traces[trace].size() - remaining
			if not cleanses_traces and expired > 0:
				activation_events.append("%d %s trace(s) expire on %s." % [expired, trace, enemy["name"]])
	for item in equipped:
		if not item_enabled(item):
			continue
		var grants: Array[String] = []
		for resource: String in ["mana", "stamina", "block"]:
			var gain: int = int(item.get(resource + "_per_round", 0)) + (int(item.get(resource, 0)) if resource != "block" or turn == 1 else 0)
			if resource == "block" and turn == 1 and CATEGORIES.matches(item, &"shields"):
				gain += item_bonus(item)
			if resource == "block" and turn == 1 and item["key"] == "mirror_shard":
				var target: Dictionary = _mirror_target(item, equipped)
				if not target.is_empty():
					gain += int(target["block"]) / 2
					if int(target["block"]) / 2 > 0:
						grants.append("Copies %d block from %s." % [int(target["block"]) / 2, _log_item(target)])
			if gain > 0:
				result["item_effects"].append({"id": item["id"], "key": resource, "amount": gain})
				if resource == "block" and turn == 1 and CATEGORIES.matches(item, &"shields"):
					grants.append_array(_log_bonus_sources(item, equipped))
				grants.append("Granted %d %s%s." % [gain, resource, " at combat start" if turn == 1 else " before activations"])
		if not grants.is_empty():
			activation_events.append(_log_item(item) + " activation")
			for grant: String in grants:
				activation_events.append(_log_effect(grant))
		regenerated_mana += int(item.get("mana_per_round", 0))
		regenerated_stamina += int(item.get("stamina_per_round", 0))
		regenerated_block += int(item.get("block_per_round", 0))
		has_hourglass = has_hourglass or item["key"] == "hourglass"
	var available_mana: int = int(resources["mana"])
	var available_stamina: int = int(resources["stamina"])
	var available_momentum: int = momentum
	result["momentum_spent"] = 0
	result["item_momentum_gained"] = 0
	result["block"] += regenerated_block
	result["mana_gained"] = regenerated_mana
	result["stamina_gained"] = regenerated_stamina
	result["block_gained"] = regenerated_block
	result["mana_spent"] = 0
	result["stamina_spent"] = 0
	result["mana_converted"] = 0
	var eligible: Array[Dictionary] = []
	var activation_costs: Dictionary = {}
	# Reserve both costs atomically in priority/reading order. Skip failures.
	for item in activation_order():
		if not item_enabled(item):
			result["dormant_ids"].append(item["id"])
			continue
		var cost: int = 0 if _dev_flag("infinite_mana") else maxi(0, int(item["cost"]))
		var stamina_cost: int = 0 if _dev_flag("infinite_stamina") else maxi(0, int(item.get("stamina_cost", 0)))
		var paid_mana: int = mini(cost, available_mana)
		var required_momentum: int = momentum_cost(int(item.get("momentum_cost", 0))) if int(item.get("momentum_cost", 0)) > 0 else 0
		var requires_warrior: bool = int(item.get("momentum_cost", 0)) > 0 or int(item.get("momentum_gain", 0)) > 0
		if (requires_warrior and class_key != "warrior") or required_momentum > available_momentum:
			result["dormant_ids"].append(item["id"])
			continue
		if stamina_cost > available_stamina:
			result["dormant_ids"].append(item["id"])
			continue
		if cost > available_mana:
			if relics.has("arcane_barter"):
				result["blood_cost"] += cost - available_mana
				result["mana_spent"] += available_mana
				available_mana = 0
			else:
				result["dormant_ids"].append(item["id"])
				continue
		else:
			result["mana_spent"] += cost
			available_mana -= cost
		available_stamina -= stamina_cost
		result["stamina_spent"] += stamina_cost
		result["active_ids"].append(item["id"])
		available_momentum -= required_momentum
		var gained_momentum: int = int(item.get("momentum_gain", 0)) if class_key == "warrior" else 0
		available_momentum += gained_momentum
		result["momentum_spent"] += required_momentum
		result["item_momentum_gained"] += gained_momentum
		activation_costs[item["id"]] = {"mana": paid_mana, "stamina": stamina_cost, "health": cost - paid_mana, "momentum": required_momentum}
		eligible.append(item)
	# Select from one normal activation before Hourglass, Volley or Echo copies.
	var strongest_damage: int = -1
	if relics.has("echo_clock") and turn % 3 == 0:
		for item in eligible:
			if CATEGORIES.matches_any(item, ["melee_weapons", "ranged_weapons", "magic_weapons", "companions"]):
				var strength: int = int(item["damage"]) + item_bonus(item)
				if strength > strongest_damage or (strength == strongest_damage and reading_rank(item) < reading_rank(_item_by_id(int(result["echo_item_id"])))):
					strongest_damage = strength
					result["echo_item_id"] = item["id"]
	# Aggregate all contributions atomically; copied activations pay no extra cost.
	for item in activation_order():
		if not activation_costs.has(item["id"]):
			activation_events.append("%s skips activation: insufficient mana, stamina or Momentum; no costs are spent." % _log_item(item))
			continue
		var activates: bool = CATEGORIES.matches_any(item, ["melee_weapons", "ranged_weapons", "magic_weapons", "companions"]) or item["key"] == "mirror_shard"
		for stat: String in PackCatalog.STATS:
			activates = activates or (stat not in ["mana", "stamina", "block"] and int(item[stat]) != 0)
		if not activates:
			continue
		var before: Dictionary = result.duplicate()
		var source: String = _log_item(item)
		var payments: PackedStringArray = []
		for resource: String in ["mana", "stamina", "health", "momentum"]:
			var paid: int = int(activation_costs[item["id"]][resource])
			if paid > 0:
				payments.append("%d %s" % [paid, resource])
		activation_events.append(source + " activation" + (" (cost: %s)" % " and ".join(payments) if not payments.is_empty() else ""))
		for received: String in _log_bonus_sources(item, equipped):
			activation_events.append(_log_effect(received))
		var is_attack: bool = CATEGORIES.matches_any(item, ["melee_weapons", "ranged_weapons", "magic_weapons", "companions"])
		var copies: int = 1
		if has_hourglass and CATEGORIES.matches(item, &"melee_weapons") and turn % 4 == 0:
			copies += 1
		if item["id"] == result["echo_item_id"]:
			copies += 1
		result["repeats"] += copies - 1
		if copies > 1:
			activation_events.append(_log_effect("Repeated %d extra time(s)%s%s." % [copies - 1, " from Hourglass" if has_hourglass and CATEGORIES.matches(item, &"melee_weapons") and turn % 4 == 0 else "", " from Echo Clock" if item["id"] == result["echo_item_id"] else ""]))
		var supplied: Dictionary = adjacency_stats(item)
		for stat in PackCatalog.STATS:
			if stat not in ["mana", "stamina", "block"]:
				result[stat] += (int(item[stat]) + (int(supplied.get(stat, 0)) if stat != "damage" else 0)) * copies
		if is_attack:
			result["damage"] += item_bonus(item) * copies
			result["damage"] += int(activation_costs[item["id"]]["momentum"]) * int(item.get("momentum_damage", 0)) * copies
		if item["key"] == "mirror_shard":
			var best: Dictionary = _mirror_target(item, equipped)
			if not best.is_empty():
				result["damage"] += floori(float(best["damage"]) / 2.0)
		var typed_damage: String = ELEMENTS.damage_type(item) + "_damage"
		if item["key"] == "mirror_shard":
			var reflected: Dictionary = _mirror_target(item, equipped)
			if not reflected.is_empty():
				typed_damage = ELEMENTS.damage_type(reflected) + "_damage"
		result[typed_damage] += int(result["damage"]) - int(before["damage"])
		var element: String = str(item.get("element", ""))
		if ELEMENTS.ELEMENTS.has(element):
			for copy in range(copies):
				result["elemental_inputs"].append(element)
		for stat: String in PackCatalog.STATS:
			var contribution: int = int(result[stat]) - int(before[stat])
			if contribution > 0:
				var icon_key: String = ("magical_attack" if CATEGORIES.matches(item, &"magic_weapons") else "physical_attack") if stat == "damage" else ("piercing" if stat == "pierce" else stat)
				result["item_effects"].append({"id": item["id"], "key": icon_key, "amount": contribution})
				activation_events.append(_log_effect("Contributes %d %s%s." % [contribution, typed_damage.replace("_", " ") if stat == "damage" else stat.replace("_", " "), " to the combined attack" if stat == "damage" else ""]))
		if class_key == "mage" and ELEMENTS.ELEMENTS.has(element):
			activation_events.append(_log_effect("Places %d %s trace%s on %s." % [copies, element.capitalize(), "s" if copies != 1 else "", enemy["name"]]))
		for resource: String in ["mana", "stamina"]:
			var spent: int = int(activation_costs[item["id"]][resource])
			if spent > 0:
				result["item_effects"].append({"id": item["id"], "key": resource, "amount": -spent})
	result["mana_after"] = available_mana
	result["stamina_after"] = available_stamina
	result["momentum_after_items"] = available_momentum
	if relics.has("mana_furnace"):
		result["mana_converted"] = available_mana
		result["block"] += available_mana * 2
		result["block_gained"] += available_mana * 2
		result["mana_after"] = 0
		activation_events.append("Mana Furnace converts %d unused mana into %d block." % [available_mana, available_mana * 2])
	# Thralls join the direct attack, sharing its shield absorption and overflow.
	result["companion_damage"] = undead_companions * NECROMANCER_COMPANION_DAMAGE if class_key == "necromancer" else 0
	result["damage"] += int(result["companion_damage"])
	result["physical_damage"] += int(result["companion_damage"])
	if int(result["companion_damage"]) > 0:
		activation_events.append("Bone thralls contribute %d physical damage to the combined attack." % result["companion_damage"])
	result["volley_damage"] = 0
	var special: Dictionary = quiver()
	if class_key == "ranger" and not special.is_empty() and special.get("cell") != null and not needs_arrows() and volley_remaining <= 1:
		var volley: Dictionary = volley_stats()
		result["volley_damage"] = volley["damage"]
		activation_events.append(_log_item(special) + " activation")
		activation_events.append(_log_effect("Unleashes Volley."))
		for stat: String in ["damage", "pierce", "poison", "burn", "slow"]:
			if int(volley[stat]) > 0:
				activation_events.append(_log_effect("Contributes %d %s." % [volley[stat], "physical damage to the combined attack" if stat == "damage" else ("piercing" if stat == "pierce" else stat)]))
		result["physical_damage"] += int(volley["damage"])
		for stat: String in ["damage", "pierce", "poison", "burn", "slow"]:
			result[stat] += int(volley[stat])
			if int(volley[stat]) > 0:
				result["item_effects"].append({"id": special["id"], "key": "physical_attack" if stat == "damage" else ("piercing" if stat == "pierce" else stat), "amount": volley[stat]})
	if class_key == "mage":
		var cleanses_now: bool = int(enemy["cleanse"]) > 0 and turn % int(enemy["cleanse"]) == 0
		var reaction: Dictionary = ELEMENTS.react({} if cleanses_now else elemental_traces, result["elemental_inputs"])
		result["reactions"] = reaction["reactions"]
		result["traces_after"] = reaction["traces"]
		for reaction_id: String in reaction["reactions"]:
			var recipe: Dictionary = ELEMENTS.reaction(reaction_id)
			var ingredients: PackedStringArray = []
			for trace: String in recipe["needs"]:
				ingredients.append("1 " + trace)
			activation_events.append("%s cause %s on %s; consumed these traces." % [" + ".join(ingredients), recipe["name"], enemy["name"]])
			for stat: String in ["damage", "burn", "slow", "spark", "doom", "poison", "pierce"]:
				if int(recipe.get(stat, 0)) > 0:
					activation_events.append("%s contributes %d %s." % [recipe["name"], recipe[stat], "magical damage to the combined attack" if stat == "damage" else stat])
			for trace: String in recipe["produces"]:
				activation_events.append("%s places 1 %s trace on %s." % [recipe["name"], trace.capitalize(), enemy["name"]])
		for stat: String in ["damage", "burn", "slow", "spark", "doom", "poison", "pierce"]:
			result[stat] += int(reaction[stat])
		result["magical_damage"] += int(reaction["damage"])
	preload("res://systems/relics/expansion_relics.gd").apply_stats(self, result)
	return result

func _item_by_id(item_id: int) -> Dictionary:
	for item: Dictionary in items:
		if int(item["id"]) == item_id:
			return item
	return {}

func _log_item(item: Dictionary) -> String:
	return "[url=catalog_item_%s]%s[/url]" % [item["key"], preload("res://systems/items/item_presentation.gd").display_name(item)]

func _log_bonus_sources(item: Dictionary, equipped: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	for booster: Dictionary in equipped:
		var supplied: Dictionary = supplied_bonus(booster, item)
		for stat: String in supplied:
			var amount: int = int(supplied[stat])
			if amount > 0:
				lines.append("Receives +%d %s%s from touching %s." % [amount, stat.replace("_", " "), " per Volley" if item["key"] == QUIVER.KEY else "", _log_item(booster)])
	return lines

func _log_effect(message: String) -> String:
	return "[indent]– " + message + "[/indent]"

func _record_amount(events: Array[String], message: String, amount: int) -> void:
	if amount > 0:
		events.append(message % amount)

func outcome(stats: Dictionary) -> Dictionary:
	# Previews and committed turns share the same pure resolution and event list.
	var result: Dictionary = stats.duplicate(true)
	var my_events: Array[String] = []
	var monster_events: Array[String] = []
	var foe: String = enemy["name"]
	my_events.assign(stats.get("activation_events", []))
	result["volley_after"] = volley_remaining
	if class_key == "ranger" and not quiver().is_empty() and not needs_arrows():
		result["volley_after"] = int(QUIVER.stats(quiver())["interval"]) if volley_remaining <= 1 else volley_remaining - 1
	var health: int = mini(max_hp, hp + int(stats["healing"]))
	var healed: int = health - hp
	_record_amount(my_events, "I healed %d HP.", healed)
	var physical: int = int(stats.get("physical_damage", stats["damage"]))
	var magical: int = int(stats.get("magical_damage", 0))
	if relics.has("blood_pact"):
		physical += maxi(0, int(stats["healing"]) - healed)
	var physical_after: int = ELEMENTS.resist(physical, int(enemy.get("physical_resistance", 0)))
	var magical_after: int = ELEMENTS.resist(magical, int(enemy.get("magical_resistance", 0)))
	_record_amount(my_events, foe + " resisted %d physical damage.", physical - physical_after)
	_record_amount(my_events, foe + " resisted %d magical damage.", magical - magical_after)
	var direct: int = physical_after + magical_after
	var shield_before: int = shield()
	var shield_absorbed: int = mini(shield_before, maxi(0, direct - int(stats["pierce"])))
	var shield_spent: int = enemy_shield_spent + shield_absorbed
	var dealt: int = direct - shield_absorbed
	result["direct_damage_actual"] = mini(maxi(0, dealt), int(enemy["hp"]))
	result["direct_physical_actual"] = mini(int(result["direct_damage_actual"]), maxi(0, physical_after - shield_absorbed))
	result["direct_magical_actual"] = int(result["direct_damage_actual"]) - int(result["direct_physical_actual"])
	var foe_hp: int = maxi(0, int(enemy["hp"]) - dealt)
	_record_amount(my_events, foe + "'s block absorbed %d damage.", shield_absorbed)
	if shield_before > 0 and shield_absorbed == shield_before:
		my_events.append("I broke %s's block." % foe)
	_record_amount(my_events, "I dealt %d damage to " + foe + ".", mini(dealt, int(enemy["hp"])))
	var leech: int = mini(int(stats["vampirism"]), mini(dealt, int(enemy["hp"])))
	var leech_heal: int = mini(max_hp - health, leech)
	health += leech_heal
	_record_amount(my_events, "Vampirism restored %d HP to me.", leech_heal)
	var poison: int = enemy_poison
	var burn: int = enemy_burn
	var doom: int = enemy_doom
	var doom_turns: int = enemy_doom_turns
	var spark: int = enemy_spark
	var slow: int = enemy_slow
	if int(enemy["cleanse"]) > 0 and turn % int(enemy["cleanse"]) == 0:
		if foe_hp > 0:
			_record_amount(my_events, foe + " cleansed %d poison.", poison)
			_record_amount(my_events, foe + " cleansed %d burn.", burn)
			_record_amount(my_events, foe + " cleansed %d Doom.", doom)
			_record_amount(my_events, foe + " cleansed %d Spark.", spark)
			_record_amount(my_events, foe + " cleansed %d Slow.", slow)
		poison = 0
		burn = 0
		doom = 0
		doom_turns = 0
		spark = 0
		slow = 0
	if foe_hp > 0:
		_record_amount(my_events, "I applied %d poison to " + foe + ".", int(stats["poison"]))
		_record_amount(my_events, "I applied %d burn to " + foe + ".", int(stats["burn"]))
		for key: String in ["doom", "spark", "slow"]:
			_record_amount(my_events, "I applied %d " + key.capitalize() + " to " + foe + ".", int(stats.get(key, 0)))
	poison += int(stats["poison"])
	burn += int(stats["burn"])
	var poison_damage: int = ELEMENTS.resist(poison, int(enemy.get("magical_resistance", 0)))
	_record_amount(my_events, "Poison dealt %d damage to " + foe + ".", mini(poison_damage, foe_hp))
	result["poison_damage_actual"] = mini(poison_damage, foe_hp)
	foe_hp = maxi(0, foe_hp - poison_damage)
	var burn_damage: int = ELEMENTS.resist(burn, int(enemy.get("magical_resistance", 0)))
	_record_amount(my_events, "Burn dealt %d damage to " + foe + ".", mini(burn_damage, foe_hp))
	result["burn_damage_actual"] = mini(burn_damage, foe_hp)
	foe_hp = maxi(0, foe_hp - burn_damage)
	var spark_damage: int = ELEMENTS.resist(spark * ELEMENTS.SPARK_DAMAGE, int(enemy.get("magical_resistance", 0))) if magical_after > 0 else 0
	result["spark_damage_actual"] = mini(spark_damage, foe_hp)
	_record_amount(my_events, "Spark dealt %d damage to " + foe + ".", int(result["spark_damage_actual"]))
	foe_hp = maxi(0, foe_hp - spark_damage)
	if magical_after > 0:
		spark = maxi(0, spark - 1)
	spark += int(stats.get("spark", 0))
	doom += int(stats.get("doom", 0))
	if doom > 0 and doom_turns == 0:
		doom_turns = ELEMENTS.DOOM_ROUNDS
	doom_turns = maxi(0, doom_turns - 1)
	var doom_damage: int = ELEMENTS.resist(doom * ELEMENTS.DOOM_DAMAGE, int(enemy.get("magical_resistance", 0))) if doom > 0 and doom_turns == 0 else 0
	result["doom_damage_actual"] = mini(doom_damage, foe_hp)
	_record_amount(my_events, "Doom dealt %d damage to " + foe + ".", int(result["doom_damage_actual"]))
	foe_hp = maxi(0, foe_hp - doom_damage)
	if doom_turns == 0:
		doom = 0
	slow += int(stats["slow"])
	result["slow"] = slow
	result["enemy_slow_after"] = maxi(0, slow - 1)
	result["enemy_spark_after"] = spark
	result["enemy_doom_after"] = doom
	result["enemy_doom_turns_after"] = doom_turns
	var cleansed: int = mini(player_poison, int(stats["cleanse"]))
	_record_amount(my_events, "I cleansed %d poison.", cleansed)
	var toxin: int = player_poison - cleansed
	var reflection: int = int(enemy["reflect"]) if dealt > 0 else 0
	var toxin_damage: int = ELEMENTS.resist(toxin, int(stats.get("magical_resistance", 0)))
	reflection = ELEMENTS.resist(reflection, int(stats.get("magical_resistance", 0)))
	var special: int = toxin_damage + int(stats["curse"]) + reflection
	var ward_absorbed: int = mini(int(stats["ward"]), special)
	var ward_left: int = int(stats["ward"])
	# Attribute the shared ward pool to each source without changing its total.
	for source: Dictionary in [{"amount": toxin_damage, "name": "Poison"}, {"amount": int(stats["curse"]), "name": "Curse"}, {"amount": reflection, "name": foe + "'s reflection"}]:
		var absorbed: int = mini(ward_left, int(source["amount"]))
		ward_left -= absorbed
		_record_amount(my_events, "My ward blocked %d damage from " + str(source["name"]).to_lower() + ".", absorbed)
		var damage: int = 0 if _dev_flag("invulnerable") else int(source["amount"]) - absorbed
		_record_amount(my_events, str(source["name"]) + " dealt %d damage to me.", mini(damage, maxi(0, health)))
		health -= damage
	var blood_damage: int = 0 if _dev_flag("invulnerable") else int(stats["blood_cost"])
	_record_amount(my_events, "Arcane Barter cost me %d HP.", mini(blood_damage, maxi(0, health)))
	health -= blood_damage
	# Incoming poison is applied after this tick and retains all new stacks.
	toxin = maxi(0, toxin - 1)
	# The UI commits this checkpoint first, then the response after its delay.
	result["player_state"] = {"hp": maxi(0, health), "enemy_hp": foe_hp, "mana": stats["mana_after"], "stamina": stats.get("stamina_after", 0), "block": stats["block"], "player_poison": toxin, "enemy_poison": poison if relics.has("plague_seal") else maxi(0, poison - 1), "enemy_burn": maxi(0, burn - 1), "enemy_shield_spent": shield_spent}
	result["has_response"] = health > 0 and foe_hp > 0
	var guard: int = int(stats["block"])
	var taken: int = 0
	var contact_damage: int = 0 # Preserve on-contact effects when developer immunity blocks health loss.
	var retaliation: int = 0
	var blocked: int = 0
	var reactive_amounts: Dictionary = {"slow": 0, "plating": 0, "thorns": 0}
	var poison_logged: bool = false
	result["player_shield_broken"] = false
	result["player_hit_shielded"] = false
	result["player_hit_unshielded"] = false
	result["invisible"] = is_invisible()
	if health > 0 and foe_hp > 0:
		var sundered: int = mini(guard, int(enemy["sunder"]))
		guard -= sundered
		_record_amount(monster_events, foe + " destroyed %d of my block.", sundered)
		if sundered > 0 and guard == 0:
			result["player_shield_broken"] = true
			monster_events.append("%s broke my block." % foe)
		if is_invisible() and attack() > 0:
			monster_events.append("I avoided %s's attack with Shadowstep." % foe)
		for hit in range(0 if is_invisible() else int(enemy["hits"])):
			if health <= 0 or foe_hp <= 0:
				break
			var slowed: int = mini(attack(), int(result["slow"]))
			var plated: int = mini(maxi(0, attack() - slowed), int(stats["plating"]))
			reactive_amounts["slow"] += slowed
			reactive_amounts["plating"] += plated
			var threat: int = maxi(0, attack() - slowed - plated)
			var incoming_type: String = str(enemy.get("damage_type", "physical"))
			var incoming_after: int = ELEMENTS.resist(threat, int(stats.get(incoming_type + "_resistance", 0)))
			_record_amount(monster_events, "My resistance prevented %d damage.", threat - incoming_after)
			threat = incoming_after
			_record_amount(monster_events, "My slow effect prevented %d damage.", slowed)
			_record_amount(monster_events, "My plating prevented %d damage.", plated)
			var piercing: int = mini(threat, int(enemy["pierce"]))
			var absorbed: int = mini(guard, threat - piercing)
			guard -= absorbed
			blocked += absorbed
			_record_amount(monster_events, "My block absorbed %d damage.", absorbed)
			if absorbed > 0 and guard == 0:
				result["player_shield_broken"] = true
				monster_events.append("%s broke my block." % foe)
			if attack() > 0:
				result["player_hit_shielded" if guard > 0 else "player_hit_unshielded"] = true
			var health_damage: int = 0 if _dev_flag("invulnerable") else threat - absorbed
			contact_damage += threat - absorbed
			taken += health_damage
			_record_amount(monster_events, foe + " dealt %d damage to me.", mini(health_damage, maxi(0, health)))
			health -= health_damage
			if threat > absorbed and not poison_logged:
				_record_amount(monster_events, foe + " applied %d poison to me.", int(enemy["poison"]))
				poison_logged = true
			if attack() > 0:
				var thorns: int = ELEMENTS.resist(int(stats["thorns"]), int(enemy.get("physical_resistance", 0)))
				retaliation += thorns
				reactive_amounts["thorns"] += mini(thorns, foe_hp)
				_record_amount(monster_events, "My thorns dealt %d damage to " + foe + ".", mini(thorns, foe_hp))
				foe_hp = maxi(0, foe_hp - thorns)
		if contact_damage > 0:
			toxin += int(enemy["poison"])
		if foe_hp > 0:
			var regeneration: int = mini(int(enemy["regen"]), int(enemy["max_hp"]) - foe_hp)
			foe_hp += regeneration
			_record_amount(monster_events, foe + " regenerated %d HP.", regeneration)
			var drain: int = mini(int(enemy["drain"]), int(enemy["max_hp"]) - foe_hp) if contact_damage > 0 else 0
			foe_hp += drain
			_record_amount(monster_events, foe + " drained %d HP to heal itself.", drain)
	result.merge({"hp_after": maxi(0, health), "enemy_hp_after": foe_hp, "dealt": dealt, "taken": taken, "blocked": blocked, "retaliation": retaliation, "healed": healed + leech_heal, "ward_absorbed": ward_absorbed, "special_taken": 0 if _dev_flag("invulnerable") else special - ward_absorbed + int(stats["blood_cost"]), "poison_after": toxin, "poison_tick": poison, "burn_tick": burn, "enemy_poison_after": poison if relics.has("plague_seal") else maxi(0, poison - 1), "enemy_burn_after": maxi(0, burn - 1), "block_after": guard, "carry_after": guard, "revived": false, "shield_absorbed": shield_absorbed}, true)
	if health <= 0 and relics.has("last_thread") and not last_thread_used:
		result["hp_after"] = mini(8, max_hp)
		result["revived"] = true
	# Timed guard abilities explicitly replenish or expire; ordinary shields stay spent.
	if foe_hp > 0 and int(result["hp_after"]) > 0:
		var shield_remaining: int = maxi(0, shield_capacity() - shield_spent)
		if shield_capacity(turn + 1) > shield_capacity():
			shield_spent = 0
		var shield_change: int = maxi(0, shield_capacity(turn + 1) - shield_spent) - shield_remaining
		_record_amount(monster_events, foe + " restored %d block.", shield_change)
		_record_amount(monster_events, foe + " lost %d temporary block.", -shield_change)
	result["enemy_shield_spent_after"] = shield_spent
	result["enemy_shield_after"] = maxi(0, shield_capacity(turn + 1) - shield_spent)
	# Award only after a full exchange, never on previews or a killing opening action.
	result["momentum_gained"] = momentum_gain() if result["has_response"] and int(result["hp_after"]) > 0 else 0
	result["momentum_after"] = int(stats.get("momentum_after_items", momentum)) + int(result["momentum_gained"])
	_record_amount(monster_events, "I gained %d Momentum.", int(result["momentum_gained"]))
	result["player_events"] = my_events
	# Limit conditional feedback to effects that actually resolved. Allocation
	# follows the same deterministic source order as backpack aggregation.
	var budgets: Dictionary = {"healing": healed, "vampirism": leech_heal, "ward": ward_absorbed, "cleanse": cleansed}
	result["response_item_effects"] = []
	var applied_effects: Array[Dictionary] = []
	for source: Dictionary in stats.get("item_effects", []):
		var effect: Dictionary = source.duplicate()
		var key: String = effect["key"]
		if reactive_amounts.has(key):
			var total: int = int(stats.get(key, 0))
			# Persistent defenses can apply on several enemy hits.
			effect["amount"] = mini(int(reactive_amounts[key]), int(effect["amount"]) * int(enemy["hits"])) if total > 0 else 0
			reactive_amounts[key] -= int(effect["amount"])
			if int(effect["amount"]) > 0:
				result["response_item_effects"].append(effect)
			continue
		if budgets.has(key):
			effect["amount"] = mini(int(effect["amount"]), int(budgets[key]))
			budgets[key] -= int(effect["amount"])
		if key in ["poison", "burn"] and int(enemy["hp"]) - dealt <= 0:
			continue
		if int(effect["amount"]) != 0:
			applied_effects.append(effect)
	result["item_effects"] = applied_effects
	result["monster_events"] = monster_events
	result["raised_companion"] = class_key == "necromancer" and int(enemy["hp"]) > 0 and foe_hp <= 0 and int(result["hp_after"]) > 0 and undead_companions < NECROMANCER_COMPANION_CAP
	return result

func end_turn() -> Dictionary:
	# Immediate resolution starts preparation once for simulations.
	if combat_state == CombatState.PREPARING:
		start_combat()
	if begin_turn().is_empty():
		return {}
	return complete_turn()

func begin_turn() -> Dictionary:
	if combat_state != CombatState.RUNNING or phase != Phase.FIGHT or not pending_turn.is_empty():
		return {}
	if _dev_flag("restore_health"):
		hp = max_hp
	pending_turn = outcome(effects())
	momentum = int(pending_turn.get("momentum_after_items", momentum))
	var checkpoint: Dictionary = pending_turn["player_state"]
	mana_capacity = int(pending_turn["mana"])
	stamina_capacity = int(pending_turn["stamina"])
	block_capacity = maxi(block_capacity, int(checkpoint["block"]))
	hp = int(checkpoint["hp"])
	enemy_slow = int(pending_turn["enemy_slow_after"])
	enemy_spark = int(pending_turn["enemy_spark_after"])
	enemy_doom = int(pending_turn["enemy_doom_after"])
	enemy_doom_turns = int(pending_turn["enemy_doom_turns_after"])
	elemental_traces = pending_turn.get("traces_after", {}).duplicate(true)
	volley_remaining = int(pending_turn.get("volley_after", volley_remaining))
	enemy["hp"] = checkpoint["enemy_hp"]
	for property: String in ["mana", "stamina", "block", "player_poison", "enemy_poison", "enemy_burn", "enemy_shield_spent"]:
		set(property, int(checkpoint[property]))
	total_turns += 1
	log_action(pending_turn["player_events"])
	return pending_turn

func complete_turn() -> Dictionary:
	if combat_state != CombatState.RUNNING or pending_turn.is_empty():
		return {}
	var result: Dictionary = pending_turn
	pending_turn = {}
	momentum = int(result.get("momentum_after", momentum))
	hp = int(result["hp_after"])
	enemy["hp"] = result["enemy_hp_after"]
	mana = int(result["mana_after"])
	stamina = int(result.get("stamina_after", stamina))
	block = int(result["block_after"])
	carry_block = 0 # Legacy field; full retention now lives in block.
	player_poison = int(result["poison_after"])
	enemy_poison = int(result["enemy_poison_after"])
	enemy_burn = int(result["enemy_burn_after"])
	enemy_shield_spent = int(result["enemy_shield_spent_after"])
	log_action(result["monster_events"])
	if result["revived"]:
		last_thread_used = true
		log_line("Last Thread saved me with %d HP." % hp)
		var largest: Dictionary = {}
		for item in packed():
			if is_permanent(item):
				continue
			if largest.is_empty() or item["mask"].size() > largest["mask"].size():
				largest = item
		if not largest.is_empty():
			largest["cell"] = null
			log_line("Last Thread unpacked my %s." % _log_item(largest))
	if hp <= 0:
		log_line("I was defeated.")
		phase = Phase.DEFEAT
		combat_state = CombatState.FINISHED
	elif int(enemy["hp"]) <= 0:
		finish_defeated_enemy(bool(result["raised_companion"]))
	turn += 1
	if combat_state == CombatState.RUNNING:
		_refill_round_resources()
	return result

func finish_defeated_enemy(raise_companion: bool = true) -> bool:
	if phase != Phase.FIGHT or hp <= 0 or int(enemy.get("hp", 1)) > 0:
		return false
	if raise_companion and class_key == "necromancer" and undead_companions < NECROMANCER_COMPANION_CAP:
		undead_companions += 1
		log_line("Raise Dead: I raised %s as a bone thrall." % enemy["name"])
	log_line("%s defeated." % enemy["name"])
	phase = Phase.LOOT
	combat_state = CombatState.FINISHED
	roll_loot()
	return true

func roll_loot() -> void:
	var offense: Dictionary = {"warrior": ["longsword", "battle_axe", "venom_dagger", "vampire_fang", "rusty_knife"], "ranger": ["shortbow", "hunting_trap", "venom_dagger", "vampire_fang"], "mage": ["ember_tome", "frost_wand", "venom_dagger", "vampire_fang"], "assassin": ["venom_dagger", "vampire_fang", "rusty_knife", "hunting_trap"], "necromancer": ["ember_tome", "frost_wand", "vampire_fang", "venom_dagger"]}
	offense["mage"] = ["ember_tome", "frost_wand", "lightning_wand", "void_tome", "venom_orb"]
	offense["necromancer"].append_array(["lightning_wand", "void_tome", "venom_orb"])
	var groups: Array = [offense[class_key], ["cracked_shield", "tower_shield", "buckler", "plate_mail", "thorn_mail", "healing_herbs", "bandage", "warding_sigil"], ["blood_gem", "iron_charm", "quiver", "spark_ring", "hourglass", "mirror_shard", "antidote", "cursed_idol"]]
	# New progression equipment joins normal rewards as deeper tiers open.
	# Preserve class-specific legacy pools and the quiver-upgrade choice.
	var tier_limit: int = mini(4, floori(float(fight) / 4.0))
	for key: String in PackCatalog.CONTENT.ITEM_KEYS:
		var definition: Dictionary = PackCatalog.item(key)
		if PackCatalog.RARITY.TIERS.find(definition["rarity"]) <= tier_limit:
			groups[0 if CATEGORIES.matches(definition, &"melee_weapons") else 1].append(key)
	for key: String in PackCatalog.EXPANSION_ITEMS.ITEM_KEYS:
		var definition: Dictionary = PackCatalog.item(key)
		if not item_enabled(definition) or PackCatalog.RARITY.TIERS.find(definition["rarity"]) > tier_limit:
			continue
		var group_index: int = 2
		if CATEGORIES.matches_any(definition, ["melee_weapons", "ranged_weapons", "magic_weapons", "companions"]):
			group_index = 0
		elif CATEGORIES.matches_any(definition, ["shields", "body_armor", "boots", "healing_supplies"]):
			group_index = 1
		groups[group_index].append(key)
	var rolled: Array[String] = []
	for group in groups:
		var eligible: Array = group.filter(func(key: String) -> bool: return item_enabled(PackCatalog.item(key)))
		if not eligible.is_empty():
			rolled.append(eligible[rng.randi_range(0, eligible.size() - 1)])
	if class_key == "ranger" and (fight + 1) % 3 == 0 and not quiver().is_empty():
		var upgrades: Array[String] = QUIVER.available(quiver())
		if not upgrades.is_empty():
			rolled[2] = upgrades[rng.randi_range(0, upgrades.size() - 1)]
	item_rewards.append({"floor": fight + 1, "offers": rolled})
	if offers.is_empty():
		offers.assign(rolled)

func choose_loot(key: String) -> void:
	if not can_claim_rewards() or not pending_turn.is_empty() or item_rewards.is_empty() or not offers.has(key) or not item_enabled(PackCatalog.item(key)):
		return
	if QUIVER.OPTIONS.has(key):
		if not apply_quiver_option(key):
			return
	else:
		var item: Dictionary = add_item(key)
		auto_place(item)
	item_rewards.pop_front()
	_normalize_quiver_rewards()
	offers.clear()
	if not item_rewards.is_empty():
		offers.assign(item_rewards[0]["offers"])

func apply_quiver_option(key: String) -> bool:
	if not can_edit_inventory() or not QUIVER.OPTIONS.has(key) or class_key != "ranger":
		return false
	var special: Dictionary = quiver()
	if special.is_empty():
		return false
	if QUIVER.INITIAL.has(key):
		if not needs_arrows():
			return false
		special["arrow_type"] = QUIVER.OPTIONS[key]["type"]
	else:
		if not QUIVER.available(special).has(key):
			return false
		special["upgrades"][key] = int(special["upgrades"].get(key, 0)) + 1
		if key == "quiver_loader":
			volley_remaining = mini(volley_remaining, int(QUIVER.stats(special)["interval"]))
	_normalize_quiver_rewards()
	return true

func _normalize_quiver_rewards() -> void:
	# Deferred choices must not retain an upgrade that is now capped.
	for reward: Dictionary in item_rewards:
		for index in range(reward["offers"].size()):
			var offered: String = reward["offers"][index]
			if QUIVER.OPTIONS.has(offered) and not offered in QUIVER.INITIAL and not QUIVER.available(quiver()).has(offered):
				reward["offers"][index] = "blood_gem"
	if not item_rewards.is_empty():
		offers.assign(item_rewards[0]["offers"])

func advance_encounter() -> void:
	enter_selector()

func display_floor() -> int:
	return floor_index + 1

func has_combat_room() -> bool:
	return phase in [Phase.FIGHT, Phase.LOOT, Phase.DEFEAT, Phase.VICTORY]

func available_room_relics() -> Array[String]:
	var available: Array[String] = []
	for key: String in PackCatalog.RELICS:
		if item_enabled(PackCatalog.relic(key)) and not relics.has(key) and not relic_offers.has(key):
			available.append(key)
	return available

func enter_selector() -> bool:
	if phase not in [Phase.LOOT, Phase.ROOM_COMPLETE] or not pending_turn.is_empty():
		return false
	if floor_index >= FLOORS - 1:
		phase = Phase.VICTORY
		return true
	phase = Phase.SELECTOR
	combat_state = CombatState.FINISHED
	room_resolved = true
	door_choices = preload("res://systems/runs/room_routes.gd").choices(floor_index + 2, hp, max_hp, not available_room_relics().is_empty(), noncombat_streak, rng)
	return true

func choose_destination(id: String) -> bool:
	if phase != Phase.SELECTOR:
		return false
	var kind: String = ""
	for door: Dictionary in door_choices:
		if door.id == id:
			kind = door.kind
	if kind not in ["combat", "rest", "relic", "encounter"]:
		return false
	return enter_room(floor_index + 1, kind)

func enter_room(index: int, kind: String) -> bool:
	if index < 0 or index >= FLOORS or kind not in ["combat", "rest", "relic", "encounter"]:
		return false
	floor_index = index
	fight = floor_index
	room_kind = kind
	door_choices.clear()
	room_resolved = false
	room_reward_pending = false
	room_relic_offers.clear()
	room_event = ""
	noncombat_streak = 0 if kind == "combat" else noncombat_streak + 1
	if kind == "combat":
		var pool: Array[Dictionary] = preload("res://systems/enemies/enemy_expansion.gd").pool(display_floor(), enemies()[fight])
		prepare_enemy(pool[rng.randi_range(0, pool.size() - 1)])
	else:
		phase = Phase.ROOM
		combat_state = CombatState.FINISHED
		begin_stage(display_floor(), {"rest": "Rest area", "relic": "Relic chamber", "encounter": "Encounter"}[kind])
		if kind == "relic":
			_roll_room_relics()
		elif kind == "encounter":
			room_event = "interrogation" if rng.randi_range(0, 1) == 0 or available_room_relics().is_empty() else "blood_offering"
	return true

func _roll_room_relics() -> void:
	var available: Array[String] = available_room_relics()
	for index in range(mini(3, available.size())):
		room_relic_offers.append(available.pop_at(rng.randi_range(0, available.size() - 1)))
	room_reward_pending = not room_relic_offers.is_empty()

func offering_cost() -> int:
	return maxi(1, ceili(max_hp * 0.20))

func resolve_room(action: String) -> bool:
	if phase != Phase.ROOM or room_resolved:
		return false
	if action == "leave":
		pass
	elif room_reward_pending and action.begins_with("relic:"):
		var key: String = action.trim_prefix("relic:")
		if not room_relic_offers.has(key) or relics.has(key) or not item_enabled(PackCatalog.relic(key)):
			return false
		relics.append(key)
		log_line("Claimed %s." % PackCatalog.relic(key)["name"])
	elif room_kind == "rest" and action == "rest" and hp < max_hp:
		var amount: int = mini(max_hp - hp, ceili(max_hp * 0.30))
		hp += amount
		log_line("Rest restored %d health." % amount)
	elif room_kind == "encounter" and not room_reward_pending:
		if room_event == "blood_offering" and action == "offer" and hp > offering_cost():
			if available_room_relics().is_empty():
				return false
			hp -= offering_cost()
			log_line("Paid %d health to the blood altar." % offering_cost())
			_roll_room_relics()
			return true
		elif room_event == "interrogation" and action == "answer":
			roll_loot()
			log_line("The keeper granted an item choice.")
		elif room_event == "interrogation" and action == "refuse":
			noncombat_streak = 0
			prepare_enemy()
			return true
		else:
			return false
	else:
		return false
	room_resolved = true
	room_reward_pending = false
	room_relic_offers.clear()
	phase = Phase.ROOM_COMPLETE
	roll_relics()
	return true

func normalize_room_state(saved_state: Dictionary) -> void:
	if not saved_state.has("floor_index"):
		floor_index = fight
		room_kind = "combat"
		door_choices.clear()
		room_relic_offers.clear()
		room_reward_pending = false
		room_resolved = false
		room_event = ""
		noncombat_streak = 0
		# Preserve old queued entitlements; all subsequent floors use room choices.
		room_flow_version = 1

func log_action(events: Array) -> void:
	if events.is_empty():
		return
	# Keep presentation boundaries separate from the plain event history.
	if not stage_history.is_empty():
		var stage: Dictionary = stage_history.back()
		stage["action_starts"].append(stage["lines"].size())
	for event: String in events:
		log_line(event)

func log_line(message: String) -> void:
	history.append(message)
	if not stage_history.is_empty():
		stage_history.back()["lines"].append(message)

func begin_stage(number: int, stage_name: String) -> void:
	# Group by stage, so encounters without combat can use the same log browser.
	if not stage_history.is_empty() and stage_history.back()["number"] == number:
		return
	stage_history.append({"number": number, "name": stage_name, "lines": [], "action_starts": []})
