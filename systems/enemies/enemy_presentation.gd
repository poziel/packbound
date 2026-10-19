extends RefCounted
## Enemy inspection describes attack stats and reusable skills, not live conditions.

static func inspection(run: PackRun) -> Dictionary:
	var enemy: Dictionary = run.enemy
	var stats: Array[Dictionary] = [{"key": "magical_attack" if enemy.get("damage_type", "physical") == "magical" else "physical_attack", "value": run.attack()}]
	var abilities: Array[Dictionary] = []
	if int(enemy.get("hits", 1)) > 1:
		stats.append({"key": "multi_attack", "value": int(enemy["hits"])})
	for resistance: String in ["physical_resistance", "magical_resistance"]:
		if int(enemy.get(resistance, 0)) > 0:
			stats.append({"key": resistance, "value": "%d%%" % enemy[resistance]})
	for skill: Dictionary in skills(enemy):
		abilities.append({"key": skill["key"], "label": skill["title"], "title": skill["title"], "body": skill["body"]})
	return {"key": "enemy_" + str(enemy["key"]), "title": enemy["name"], "body": "", "keyword_stats": stats, "bonuses": abilities, "bonus_heading": "Abilities"}

static func skills(enemy: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rules: Array = [
		["regen", "regeneration", "Regeneration", "Restores up to %d health each round if it survives. Cannot exceed maximum health."],
		["drain", "life_drain", "Life Drain", "Restores up to %d health after its response, if at least one strike damages your health. Triggers once per response."],
		["reflect", "reflection", "Reflection", "Reflects %d magical damage when the combined direct attack damages it. Ward can absorb reflection."],
		["poison", "venomous_strikes", "Venomous Strikes", "Applies %d poison once per response if a strike damages your health."],
		["pierce", "piercing_strikes", "Piercing Strikes", "Up to %d damage from each strike bypasses block. Slow and plating still reduce the strike first."],
		["sunder", "sunder", "Sunder", "Destroys up to %d of your block before striking."],
		["enrage", "rising_fury", "Rising Fury", "Gains %d attack damage for each elapsed round. The attack stat includes this increase."],
		["armor", "armored", "Armored", "Starts combat with %d block. Absorbed damage spends this protection; it does not refill each round."],
		["opening_armor", "opening_guard", "Opening Guard", "Starts combat with %d block. Any remaining opening block expires after the second round."],
		["cycle_armor", "alternating_guard", "Alternating Guard", "Restores up to %d block for odd rounds. Unused temporary block expires before even rounds."],
		["parry", "parry", "Parry", "Restores up to %d block for every third round. Unused temporary block expires after that round."],
		["cleanse", "purification", "Purification", "Removes existing conditions and elemental traces every %d rounds, before fresh applications. New casts can still create new traces and conditions."]
	]
	for rule: Array in rules:
		var amount: int = int(enemy.get(rule[0], 0))
		if amount > 0:
			result.append({"key": "enemy_skill_" + str(rule[1]), "title": rule[2], "body": str(rule[3]) % amount})
	if enemy.get("attacks", []).size() > 1:
		var cycle: PackedStringArray = []
		for amount: int in enemy["attacks"]:
			cycle.append(str(amount))
		result.append({"key": "enemy_skill_attack_cycle", "title": "Attack Cycle", "body": "Base attack damage cycles through " + " → ".join(cycle) + " each round, then repeats. The attack stat shows the current round before your defenses."})
	return result
