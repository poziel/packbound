@tool
extends "res://scripts/gameplay/rooms/activity_room.gd"
## The keeper is revealed only when an encounter turns into a fight.

var combat_active: bool = false

func enemy_slots() -> Array[Marker3D]:
	if combat_active:
		return super.enemy_slots()
	var empty: Array[Marker3D] = []
	return empty
