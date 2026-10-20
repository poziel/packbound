extends RefCounted
## Quiver configuration and tuning. No scene or artwork ownership.
const KEY: String = "magnificent_quiver"
const INTERVAL: int = 3
const ARROWS: int = 2
const DAMAGE: int = 3
const INITIAL: Array[String] = ["arrow_broadhead", "arrow_bodkin", "arrow_venom"]
const OPTIONS: Dictionary = {
	"arrow_broadhead": {"name": "Broadhead Arrows", "detail": "Choose your starting arrows: +1 damage per Volley arrow.", "type": "broadhead"},
	"arrow_bodkin": {"name": "Bodkin Arrows", "detail": "Choose your starting arrows: each Volley arrow pierces 2 block.", "type": "bodkin"},
	"arrow_venom": {"name": "Venom Arrows", "detail": "Choose your starting arrows: each Volley arrow applies 1 poison.", "type": "venom"},
	"quiver_capacity": {"name": "Expanded Quiver", "detail": "Quiver upgrade: +1 arrow per Volley. Up to 3 upgrades.", "cap": 3},
	"quiver_mechanism": {"name": "Tension Mechanism", "detail": "Quiver upgrade: +1 damage per Volley arrow. Up to 3 upgrades.", "cap": 3},
	"quiver_fire": {"name": "Ember Tips", "detail": "Quiver upgrade: each Volley arrow applies +1 burn. Up to 2 upgrades.", "cap": 2},
	"quiver_poison": {"name": "Venom Reservoir", "detail": "Quiver upgrade: each Volley arrow applies +1 poison. Up to 2 upgrades.", "cap": 2},
	"quiver_explosive": {"name": "Explosive Mechanism", "detail": "Quiver upgrade: each Volley deals +3 damage and applies +1 burn. Up to 2 upgrades.", "cap": 2},
	"quiver_loader": {"name": "Quick Loader", "detail": "Quiver upgrade: Volley fires every 2 rounds instead of 3. Once per run.", "cap": 1}
}

static func available(item: Dictionary) -> Array[String]:
	return preload("res://systems/loot/loot_selection.gd").available_upgrades(item)

static func stats(item: Dictionary, adjacency: int = 0) -> Dictionary:
	var upgrades: Dictionary = item.get("upgrades", {})
	var arrows: int = ARROWS + int(upgrades.get("quiver_capacity", 0))
	var type: String = item.get("arrow_type", "")
	var explosive: int = int(upgrades.get("quiver_explosive", 0))
	return {"arrows": arrows, "interval": INTERVAL - int(upgrades.get("quiver_loader", 0)),
		GameplayTypes.Stat.DAMAGE: arrows * (DAMAGE + int(upgrades.get("quiver_mechanism", 0)) + (1 if type == "broadhead" else 0)) + adjacency + explosive * 3,
		GameplayTypes.Stat.PIERCE: arrows * 2 if type == "bodkin" else 0,
		GameplayTypes.Stat.POISON: arrows * (int(upgrades.get("quiver_poison", 0)) + (1 if type == "venom" else 0)),
		GameplayTypes.Stat.BURN: arrows * int(upgrades.get("quiver_fire", 0)) + explosive}

static func describe(_item: Dictionary, _remaining: int, _adjacency: int = 0) -> String:
	return "Touching bows gain +2 damage"
