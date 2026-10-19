extends RefCounted
## Shared conditional relic mechanics. Amounts and caps belong to each relic.
const DEFINITIONS: Dictionary = {
	"companions": ["Companion Bond", "Counts your bone thralls and packed companion items. Each grants the relic's stated bonus, up to its stated companion limit."],
	"reactions": ["Reaction Echo", "Activates when an Elemental Reaction occurs this round. Grants the stated bonus per reaction, up to the relic's stated limit."],
	"warrior": ["Momentum Affinity", "For the Warmonger: scales the relic's stated bonus with current momentum, up to its stated limit."],
	"third": ["Third-round Pulse", "Activates every third round of a fight. The relic describes the resource or effect granted."],
	"volley": ["Volley Echo", "Activates on rounds when Volley fires. The relic describes the additional effect."],
	"low_hp": ["Last Stand", "Activates when your current health is at most half your maximum health before activations."],
	"sparse": ["Light Packing", "Activates with at most four packed items."],
	"many_items": ["Full Pack", "Activates with at least eight packed items."]
}

static func description(relic: Dictionary) -> String:
	var condition: String = str(relic.get("rule", {}).get("condition", ""))
	var detail: String = str(relic.get("detail", ""))
	return str(DEFINITIONS[condition][0]) + "\n" + detail if DEFINITIONS.has(condition) else detail

static func entry(key: String) -> Dictionary:
	var condition: String = key.trim_prefix("relic_ability_")
	if not key.begins_with("relic_ability_") or not DEFINITIONS.has(condition): return {}
	return {"key": key, "title": DEFINITIONS[condition][0], "body": DEFINITIONS[condition][1], "kind": "meta"}
