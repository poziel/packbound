extends "res://tests/prototype_test.gd"

func room(kind: String) -> PackRun:
	var state: PackRun = fixture()
	state.phase = PackRun.Phase.SELECTOR
	state.door_choices = [{"id": kind, "kind": kind}]
	state.choose_destination(kind)
	return state

func _run() -> void:
	var state: PackRun = room("rest")
	state.hp = 1
	check(state.resolve_room("rest") and state.hp == 13, "Rest restores thirty percent")
	check(not state.resolve_room("rest") and state.hp == 13, "Rest resolves only once")
	state = room("rest")
	state.hp = state.max_hp - 1
	state.resolve_room("rest")
	check(state.hp == state.max_hp, "Rest cannot overheal")
	state = room("relic")
	var old_rewards: Array[int] = state.relic_rewards.duplicate()
	check(state.room_relic_offers.size() == 3, "Room offers three unowned relics")
	var key: String = state.room_relic_offers[0]
	check(state.resolve_room("relic:" + key) and state.relics.has(key), "Room relic is claimable")
	check(state.relic_rewards == old_rewards, "Claiming a room relic preserves deferred rewards")
	state = room("encounter")
	state.room_event = "blood_offering"
	state.hp = state.offering_cost()
	check(not state.resolve_room("offer"), "Unaffordable blood offering is rejected")
	state.hp = state.max_hp
	check(state.resolve_room("offer") and state.hp == 32, "Blood offering charges exact health cost")
	check(not state.resolve_room("offer") and state.hp == 32, "Blood cost cannot be repeated")
	check(state.resolve_room("relic:" + state.room_relic_offers[0]), "Paid relic can be claimed")
	state = room("encounter")
	state.room_event = "interrogation"
	var depth: int = state.display_floor()
	check(state.resolve_room("refuse") and state.phase == PackRun.Phase.FIGHT, "Refusing starts a fight")
	check(state.display_floor() == depth, "Encounter combat stays on its floor")
	state = room("encounter")
	state.room_event = "interrogation"
	state.resolve_room("answer")
	check(state.item_rewards.size() == 1 and state.can_claim_rewards(), "Answer grants a claimable deferred item")
	state.choose_loot(state.offers[0])
	check(state.item_rewards.is_empty(), "Room reward uses existing inventory claim")
	state = fixture()
	state.relics.assign(PackCatalog.RELICS)
	state.phase = PackRun.Phase.LOOT
	state.enter_selector()
	check(not state.door_choices.any(func(door: Dictionary) -> bool: return door.kind == "relic"), "Exhausted relic pool is excluded")
	var reservation_valid: bool = true
	for seed_value in range(30):
		state = fixture()
		state.rng.seed = seed_value
		state.relic_rewards.assign([1, 5, 10])
		state.relic_offers.clear()
		state.roll_relics()
		state.phase = PackRun.Phase.SELECTOR
		state.door_choices = [{"id": "relic", "kind": "relic"}]
		state.choose_destination("relic")
		state.choose_relic(state.relic_offers[0])
		for offered: String in state.relic_offers:
			reservation_valid = reservation_valid and not state.room_relic_offers.has(offered)
	check(reservation_valid, "Legacy deferred rerolls respect the room's reserved relics")
	state = fixture()
	state.relics.assign(PackCatalog.RELICS.slice(0, PackCatalog.RELICS.size() - 4))
	state.relic_rewards.assign([1, 5, 10, 15])
	state.relic_offers.clear()
	state.roll_relics()
	state.phase = PackRun.Phase.SELECTOR
	state.door_choices = [{"id": "relic", "kind": "relic"}]
	state.choose_destination("relic")
	for index in range(3):
		state.choose_relic(state.relic_offers[0])
	check(state.relic_rewards.size() == 1 and state.relic_offers.is_empty(), "Room reservation can temporarily exhaust deferred pool")
	state.resolve_room("leave")
	check(state.relic_offers.size() == 1, "Leaving releases reserved relic to a waiting legacy reward")
	print("ROOM ACTIVITIES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
