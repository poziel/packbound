@tool
extends Resource

@export var monsters: Array[Resource] = []

func profile_for(key: String) -> Resource:
	for monster: Resource in monsters:
		if monster.monster_id == key:
			return monster
	return null
