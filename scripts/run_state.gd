class_name PackRun
extends RefCounted

const GRID: Vector2i = Vector2i(8, 7)
const FLOORS: int = 20
const RELIC_FLOORS: Array[int] = [1, 5, 10, 15]
const ROSTER: Array[String] = PackCatalog.ROSTER
const NECROMANCER_COMPANION_CAP: int = 3
const NECROMANCER_COMPANION_DAMAGE: int = 2
const MAX_ITEM_PRIORITY: int = 9
enum Phase { RELIC, FIGHT, LOOT, VICTORY, DEFEAT }
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
# Mana/stamina capacities are the current round budgets; block retains its peak.
var mana_capacity: int = 0
var stamina_capacity: int = 0
var block_capacity: int = 0
var player_poison: int = 0
var enemy_poison: int = 0
var enemy_burn: int = 0
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
	items.clear()
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
	undead_companions = 1 if class_key == "necromancer" else 0
	var character: Dictionary = PackCatalog.classes()[class_key]
	max_hp = int(character["hp"])
	hp = max_hp
	fight = 0
	total_turns = 0
	last_thread_used = false
	for index in range(3):
		add_item(character["starters"][index], character["positions"][index])
	prepare_enemy()
	log_line("%s enters the cursed descent." % character["name"])

func add_item(key: String, cell: Variant = null) -> Dictionary:
	if not can_edit_inventory():
		return {}
	var item: Dictionary = definition(key)
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

func prepare_enemy() -> void:
	combat_state = CombatState.PREPARING
	pending_turn.clear()
	enemy = enemies()[fight].duplicate(true)
	enemy["max_hp"] = enemy["hp"]
	begin_stage(fight + 1, enemy["name"])
	turn = 1
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
	enemy_shield_spent = 0
	phase = Phase.FIGHT
	if RELIC_FLOORS.has(fight + 1) and not relic_floors_claimed.has(fight + 1) and not relic_rewards.has(fight + 1):
		relic_rewards.append(fight + 1)
		roll_relics()

func roll_relics() -> void:
	if relic_rewards.is_empty() or not relic_offers.is_empty():
		return
	var available: Array[String] = []
	for key in PackCatalog.RELICS:
		if not relics.has(key):
			available.append(key)
	for index in range(mini(3, available.size())):
		relic_offers.append(available.pop_at(rng.randi_range(0, available.size() - 1)))

func choose_relic(key: String) -> void:
	if not can_claim_rewards() or phase not in [Phase.FIGHT, Phase.VICTORY] or not pending_turn.is_empty() or relic_rewards.is_empty() or not relic_offers.has(key):
		return
	relics.append(key)
	relic_floors_claimed.append(relic_rewards.pop_front())
	relic_offers.clear()
	roll_relics()
	log_line("Relic bound: %s." % PackCatalog.relic(key)["name"])

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
	if source["id"] == target["id"] or not touches(source, target):
		return 0
	if source["key"] == "blood_gem" and target["role"] in ["weapon", "ranged", "spell"]:
		return 2
	if source["key"] == "iron_charm" and target["role"] == "shield":
		return 3
	if source["key"] == "quiver" and target["role"] == "ranged":
		return 2
	if source["key"] == "cursed_idol" and target["role"] in ["weapon", "ranged", "spell", "shield"]:
		return 3
	return 0

func item_bonus(target: Dictionary) -> int:
	var amount: int = 0
	for source in items:
		amount += bonus(source, target)
	return amount

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
	return (combat_state == CombatState.PREPARING and phase == Phase.FIGHT) or (combat_state == CombatState.FINISHED and phase == Phase.VICTORY)

func can_claim_rewards() -> bool:
	return combat_state == CombatState.PREPARING or (combat_state == CombatState.FINISHED and phase == Phase.VICTORY)

func set_combat_paused(value: bool) -> void:
	if value and combat_state == CombatState.RUNNING:
		combat_state = CombatState.PAUSED
	elif not value and combat_state == CombatState.PAUSED:
		combat_state = CombatState.RUNNING

func starting_resources() -> Dictionary:
	var resources: Dictionary = {"mana": PackCatalog.BASE_MANA + (PackCatalog.MAGE_MANA_BONUS if class_key == "mage" else 0), "stamina": PackCatalog.BASE_STAMINA, "block": 0}
	var equipped: Array[Dictionary] = packed()
	for item in equipped:
		resources["mana"] += int(item["mana"])
		resources["stamina"] += int(item.get("stamina", 0))
		resources["block"] += int(item["block"])
		if item["role"] == "shield":
			resources["block"] += item_bonus(item)
		if item["key"] == "mirror_shard":
			var best: Dictionary = _mirror_target(item, equipped)
			if not best.is_empty():
				resources["block"] += floori(float(best["block"]) / 2.0)
	resources["mana"] = maxi(0, int(resources["mana"]))
	resources["stamina"] = maxi(0, int(resources["stamina"]))
	return resources

func round_resources() -> Dictionary:
	var resources: Dictionary = starting_resources()
	for item in packed():
		resources["mana"] += int(item.get("mana_per_round", 0))
		resources["stamina"] += int(item.get("stamina_per_round", 0))
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
		if other["key"] != "mirror_shard" and touches(item, other) and strength > score:
			best = other
			score = strength
	return best

func start_combat() -> bool:
	if combat_state != CombatState.PREPARING or phase != Phase.FIGHT:
		return false
	var resources: Dictionary = starting_resources()
	_refill_round_resources()
	block = int(resources["block"])
	block_capacity = block
	combat_state = CombatState.RUNNING
	return true

func effects() -> Dictionary:
	var result: Dictionary = {"item_effects": [], "active_ids": [], "dormant_ids": [], "mana_after": 0, "blood_cost": 0, "repeats": 0, "echo_item_id": -1}
	for stat in PackCatalog.STATS:
		result[stat] = 0
	var equipped: Array[Dictionary] = packed()
	var has_hourglass: bool = false
	var resources: Dictionary = round_resources()
	if combat_state != CombatState.PREPARING:
		resources["block"] = block
	result["mana"] = int(resources["mana"])
	result["stamina"] = int(resources["stamina"])
	result["block"] = int(resources["block"])
	var regenerated_mana: int = 0
	var regenerated_stamina: int = 0
	var regenerated_block: int = 0
	for item in equipped:
		for resource: String in ["mana", "stamina", "block"]:
			var gain: int = int(item.get(resource + "_per_round", 0)) + (int(item.get(resource, 0)) if resource != "block" or turn == 1 else 0)
			if resource == "block" and turn == 1 and item["role"] == "shield":
				gain += item_bonus(item)
			if resource == "block" and turn == 1 and item["key"] == "mirror_shard":
				var target: Dictionary = _mirror_target(item, equipped)
				if not target.is_empty():
					gain += int(target["block"]) / 2
			if gain > 0:
				result["item_effects"].append({"id": item["id"], "key": resource, "amount": gain})
		regenerated_mana += int(item.get("mana_per_round", 0))
		regenerated_stamina += int(item.get("stamina_per_round", 0))
		regenerated_block += int(item.get("block_per_round", 0))
		has_hourglass = has_hourglass or item["key"] == "hourglass"
	var available_mana: int = int(resources["mana"])
	var available_stamina: int = int(resources["stamina"])
	result["block"] += regenerated_block
	result["mana_gained"] = regenerated_mana
	result["stamina_gained"] = regenerated_stamina
	result["block_gained"] = regenerated_block
	result["mana_spent"] = 0
	result["stamina_spent"] = 0
	result["mana_converted"] = 0
	var eligible: Array[Dictionary] = []
	# Reserve both costs atomically in priority/reading order. Skip failures.
	for item in activation_order():
		var cost: int = maxi(0, int(item["cost"]))
		var stamina_cost: int = maxi(0, int(item.get("stamina_cost", 0)))
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
		eligible.append(item)
	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return reading_rank(a) < reading_rank(b) if reading_rank(a) != reading_rank(b) else int(a["id"]) < int(b["id"]))
	# Select from one normal activation before Hourglass, Volley or Echo copies.
	var strongest_damage: int = -1
	if relics.has("echo_clock") and turn % 3 == 0:
		for item in eligible:
			if item["role"] in ["weapon", "ranged", "spell"]:
				var strength: int = int(item["damage"]) + item_bonus(item)
				if strength > strongest_damage:
					strongest_damage = strength
					result["echo_item_id"] = item["id"]
	# Aggregate all contributions atomically; copied activations pay no extra cost.
	for item in eligible:
		var before: Dictionary = result.duplicate()
		var is_attack: bool = item["role"] in ["weapon", "ranged", "spell"]
		var copies: int = 1
		if class_key == "ranger" and item["role"] == "ranged" and turn % 3 == 0:
			copies += 1
		if has_hourglass and item["role"] == "weapon" and turn % 4 == 0:
			copies += 1
		if item["id"] == result["echo_item_id"]:
			copies += 1
		result["repeats"] += copies - 1
		for stat in PackCatalog.STATS:
			if stat not in ["mana", "stamina", "block"]:
				result[stat] += int(item[stat]) * copies
		if is_attack:
			result["damage"] += item_bonus(item) * copies
		if item["key"] == "mirror_shard":
			var best: Dictionary = _mirror_target(item, equipped)
			if not best.is_empty():
				result["damage"] += floori(float(best["damage"]) / 2.0)
		for stat: String in PackCatalog.STATS:
			var contribution: int = int(result[stat]) - int(before[stat])
			if contribution > 0:
				var icon_key: String = ("magical_attack" if item["role"] == "spell" else "physical_attack") if stat == "damage" else ("piercing" if stat == "pierce" else stat)
				result["item_effects"].append({"id": item["id"], "key": icon_key, "amount": contribution})
		for resource: String in ["mana", "stamina"]:
			var spent: int = int(item.get("cost" if resource == "mana" else "stamina_cost", 0))
			if spent > 0:
				result["item_effects"].append({"id": item["id"], "key": resource, "amount": -spent})
	result["mana_after"] = available_mana
	result["stamina_after"] = available_stamina
	if relics.has("mana_furnace"):
		result["mana_converted"] = available_mana
		result["block"] += available_mana * 2
		result["block_gained"] += available_mana * 2
		result["mana_after"] = 0
	# Thralls join the direct attack, sharing its shield absorption and overflow.
	result["companion_damage"] = undead_companions * NECROMANCER_COMPANION_DAMAGE if class_key == "necromancer" else 0
	result["damage"] += int(result["companion_damage"])
	return result

func _record_amount(events: Array[String], message: String, amount: int) -> void:
	if amount > 0:
		events.append(message % amount)

func outcome(stats: Dictionary) -> Dictionary:
	# Previews and committed turns share the same pure resolution and event list.
	var result: Dictionary = stats.duplicate(true)
	var my_events: Array[String] = []
	var monster_events: Array[String] = []
	var foe: String = enemy["name"]
	_record_amount(my_events, "I gained %d mana.", int(stats.get("mana_gained", 0)))
	_record_amount(my_events, "I gained %d stamina.", int(stats.get("stamina_gained", 0)))
	_record_amount(my_events, "I spent %d mana on items.", int(stats.get("mana_spent", 0)))
	_record_amount(my_events, "I spent %d stamina on items.", int(stats.get("stamina_spent", 0)))
	_record_amount(my_events, "Mana Furnace converted %d mana into block.", int(stats.get("mana_converted", 0)))
	_record_amount(my_events, "I gained %d block.", int(stats.get("block_gained", 0)))
	var health: int = mini(max_hp, hp + int(stats["healing"]))
	var healed: int = health - hp
	_record_amount(my_events, "I healed %d HP.", healed)
	var direct: int = int(stats["damage"])
	if relics.has("blood_pact"):
		direct += maxi(0, int(stats["healing"]) - healed)
	var shield_before: int = shield()
	var shield_absorbed: int = mini(shield_before, maxi(0, direct - int(stats["pierce"])))
	var shield_spent: int = enemy_shield_spent + shield_absorbed
	var dealt: int = direct - shield_absorbed
	result["direct_damage_actual"] = mini(maxi(0, dealt), int(enemy["hp"]))
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
	if int(enemy["cleanse"]) > 0 and turn % int(enemy["cleanse"]) == 0:
		if foe_hp > 0:
			_record_amount(my_events, foe + " cleansed %d poison.", poison)
			_record_amount(my_events, foe + " cleansed %d burn.", burn)
		poison = 0
		burn = 0
	if foe_hp > 0:
		_record_amount(my_events, "I applied %d poison to " + foe + ".", int(stats["poison"]))
		_record_amount(my_events, "I applied %d burn to " + foe + ".", int(stats["burn"]))
	poison += int(stats["poison"])
	burn += int(stats["burn"])
	_record_amount(my_events, "Poison dealt %d damage to " + foe + ".", mini(poison, foe_hp))
	result["poison_damage_actual"] = mini(poison, foe_hp)
	foe_hp = maxi(0, foe_hp - poison)
	_record_amount(my_events, "Burn dealt %d damage to " + foe + ".", mini(burn, foe_hp))
	result["burn_damage_actual"] = mini(burn, foe_hp)
	foe_hp = maxi(0, foe_hp - burn)
	var cleansed: int = mini(player_poison, int(stats["cleanse"]))
	_record_amount(my_events, "I cleansed %d poison.", cleansed)
	var toxin: int = player_poison - cleansed
	var reflection: int = int(enemy["reflect"]) if dealt > 0 else 0
	var special: int = toxin + int(stats["curse"]) + reflection
	var ward_absorbed: int = mini(int(stats["ward"]), special)
	var ward_left: int = int(stats["ward"])
	# Attribute the shared ward pool to each source without changing its total.
	for source: Dictionary in [{"amount": toxin, "name": "Poison"}, {"amount": int(stats["curse"]), "name": "Curse"}, {"amount": reflection, "name": foe + "'s reflection"}]:
		var absorbed: int = mini(ward_left, int(source["amount"]))
		ward_left -= absorbed
		_record_amount(my_events, "My ward blocked %d damage from " + str(source["name"]).to_lower() + ".", absorbed)
		var damage: int = int(source["amount"]) - absorbed
		_record_amount(my_events, str(source["name"]) + " dealt %d damage to me.", mini(damage, maxi(0, health)))
		health -= damage
	_record_amount(my_events, "Arcane Barter cost me %d HP.", mini(int(stats["blood_cost"]), maxi(0, health)))
	health -= int(stats["blood_cost"])
	# Incoming poison is applied after this tick and retains all new stacks.
	toxin = maxi(0, toxin - 1)
	# The UI commits this checkpoint first, then the response after its delay.
	result["player_state"] = {"hp": maxi(0, health), "enemy_hp": foe_hp, "mana": stats["mana_after"], "stamina": stats.get("stamina_after", 0), "block": stats["block"], "player_poison": toxin, "enemy_poison": poison if relics.has("plague_seal") else maxi(0, poison - 1), "enemy_burn": maxi(0, burn - 1), "enemy_shield_spent": shield_spent}
	result["has_response"] = health > 0 and foe_hp > 0
	var guard: int = int(stats["block"])
	var taken: int = 0
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
			var slowed: int = mini(attack(), int(stats["slow"]))
			var plated: int = mini(maxi(0, attack() - slowed), int(stats["plating"]))
			reactive_amounts["slow"] += slowed
			reactive_amounts["plating"] += plated
			var threat: int = maxi(0, attack() - slowed - plated)
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
			taken += threat - absorbed
			_record_amount(monster_events, foe + " dealt %d damage to me.", mini(threat - absorbed, maxi(0, health)))
			health -= threat - absorbed
			if threat > absorbed and not poison_logged:
				_record_amount(monster_events, foe + " applied %d poison to me.", int(enemy["poison"]))
				poison_logged = true
			if attack() > 0:
				retaliation += int(stats["thorns"])
				reactive_amounts["thorns"] += mini(int(stats["thorns"]), foe_hp)
				_record_amount(monster_events, "My thorns dealt %d damage to " + foe + ".", mini(int(stats["thorns"]), foe_hp))
				foe_hp = maxi(0, foe_hp - int(stats["thorns"]))
		if class_key == "warrior" and taken == 0 and attack() > 0 and foe_hp > 0:
			var riposte: int = 4 + int(stats["plating"])
			retaliation += riposte
			_record_amount(monster_events, "My Riposte dealt %d damage to " + foe + ".", mini(riposte, foe_hp))
			foe_hp = maxi(0, foe_hp - riposte)
		if taken > 0:
			toxin += int(enemy["poison"])
		if foe_hp > 0:
			var regeneration: int = mini(int(enemy["regen"]), int(enemy["max_hp"]) - foe_hp)
			foe_hp += regeneration
			_record_amount(monster_events, foe + " regenerated %d HP.", regeneration)
			var drain: int = mini(int(enemy["drain"]), int(enemy["max_hp"]) - foe_hp) if taken > 0 else 0
			foe_hp += drain
			_record_amount(monster_events, foe + " drained %d HP to heal itself.", drain)
	result.merge({"hp_after": maxi(0, health), "enemy_hp_after": foe_hp, "dealt": dealt, "taken": taken, "blocked": blocked, "retaliation": retaliation, "healed": healed + leech_heal, "ward_absorbed": ward_absorbed, "special_taken": special - ward_absorbed + int(stats["blood_cost"]), "poison_after": toxin, "poison_tick": poison, "burn_tick": burn, "enemy_poison_after": poison if relics.has("plague_seal") else maxi(0, poison - 1), "enemy_burn_after": maxi(0, burn - 1), "block_after": guard, "carry_after": guard, "revived": false, "shield_absorbed": shield_absorbed}, true)
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
	pending_turn = outcome(effects())
	var checkpoint: Dictionary = pending_turn["player_state"]
	mana_capacity = int(pending_turn["mana"])
	stamina_capacity = int(pending_turn["stamina"])
	block_capacity = maxi(block_capacity, int(checkpoint["block"]))
	hp = int(checkpoint["hp"])
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
			if largest.is_empty() or item["mask"].size() > largest["mask"].size():
				largest = item
		if not largest.is_empty():
			largest["cell"] = null
			log_line("Last Thread unpacked my %s." % largest["name"])
	if hp <= 0:
		log_line("I was defeated.")
		phase = Phase.DEFEAT
		combat_state = CombatState.FINISHED
	elif int(enemy["hp"]) <= 0:
		if result["raised_companion"]:
			undead_companions += 1
			log_line("Raise Dead: I raised %s as a bone thrall." % enemy["name"])
		log_line("%s defeated. An item choice is available whenever I am ready." % enemy["name"])
		phase = Phase.LOOT
		combat_state = CombatState.FINISHED
		roll_loot()
	turn += 1
	if combat_state == CombatState.RUNNING:
		_refill_round_resources()
	return result

func roll_loot() -> void:
	var offense: Dictionary = {"warrior": ["longsword", "battle_axe", "venom_dagger", "vampire_fang", "rusty_knife"], "ranger": ["shortbow", "hunting_trap", "venom_dagger", "vampire_fang"], "mage": ["ember_tome", "frost_wand", "venom_dagger", "vampire_fang"], "assassin": ["venom_dagger", "vampire_fang", "rusty_knife", "hunting_trap"], "necromancer": ["ember_tome", "frost_wand", "vampire_fang", "venom_dagger"]}
	var groups: Array = [offense[class_key], ["cracked_shield", "tower_shield", "buckler", "plate_mail", "thorn_mail", "healing_herbs", "bandage", "warding_sigil"], ["blood_gem", "iron_charm", "quiver", "spark_ring", "hourglass", "mirror_shard", "antidote", "cursed_idol"]]
	var rolled: Array[String] = []
	for group in groups:
		rolled.append(group[rng.randi_range(0, group.size() - 1)])
	item_rewards.append({"floor": fight + 1, "offers": rolled})
	if offers.is_empty():
		offers.assign(rolled)

func choose_loot(key: String) -> void:
	if not can_claim_rewards() or phase not in [Phase.FIGHT, Phase.VICTORY] or not pending_turn.is_empty() or item_rewards.is_empty() or not offers.has(key):
		return
	var item: Dictionary = add_item(key)
	auto_place(item)
	log_line("Claimed %s." % definition(key)["name"])
	item_rewards.pop_front()
	offers.clear()
	if not item_rewards.is_empty():
		offers.assign(item_rewards[0]["offers"])

func advance_encounter() -> void:
	if phase != Phase.LOOT:
		return
	if fight == FLOORS - 1:
		phase = Phase.VICTORY
		return
	fight += 1
	prepare_enemy()

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
