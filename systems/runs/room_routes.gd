class_name PackRoomRoutes
extends RefCounted
## Public doors carry room types only. Contents are rolled after commitment.

static func choices(depth: int, hp: int, max_hp: int, relic_available: bool, noncombat_streak: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"id": "combat", "kind": "combat"}]
	if depth >= 20 or noncombat_streak >= 2:
		return result
	var pool: Array[String] = ["encounter"]
	if hp < max_hp:
		pool.append("rest")
	if relic_available:
		pool.append("relic")
	var roll: int = rng.randi_range(0, 99)
	var count: int = 2 if roll < 25 else (3 if roll < 85 else 4)
	while result.size() < count and not pool.is_empty():
		var kind: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		result.append({"id": kind, "kind": kind})
	return result

static func event(id: String) -> Dictionary:
	if id == "blood_offering":
		return {"title": "The blood altar", "body": "A voice beneath the stone offers power in exchange for your blood."}
	return {"title": "The interrogation", "body": "A hooded keeper blocks your path. ‘Tell me what brought you here, and I will let you take something from my stores.’"}
