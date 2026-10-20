@static_unload
class_name PackKeywordLinks
extends RefCounted

const ENTRIES: Dictionary = {
	"multi_attack": ["Multi-attack", "Number of separate strikes in each enemy response. The attack stat is damage per strike. Slow and plating reduce every strike; block is one shared pool that each strike spends."],
	"damage": ["Damage", "Weapons, bows, spells and bone thralls contribute to direct damage. Enemy block absorbs damage until depleted; excess damage hits health. Poison, burn and retaliation are resolved separately."],
	"piercing": ["Block piercing", "This much direct damage bypasses the enemy's block; the rest depletes it before reaching health. An enemy's piercing strikes instead bypass part of your block; plating still applies."],
	"block": ["Block", "A protection pool shared by all incoming strikes. Absorbed damage spends block; excess damage hits health. Your plating and slow apply first. Player block comes from the prepared backpack; enemy block comes from its abilities. Spent block stays depleted unless an explicit effect restores it."],
	"health": ["Health", "At zero HP your descent ends, unless Last Thread saves you. Healing cannot exceed maximum health. There is no automatic recovery between rounds or floors."],
	"healing": ["Healing", "Restores HP before attacks resolve, up to maximum health. Blood Pact turns excess regeneration into direct damage."],
	"vampirism": ["Vampirism", "Restores HP from actual direct damage dealt, up to your vampirism value. It works on a killing blow; overkill does not provide extra healing."],
	"plating": ["Plating", "Reduces each enemy strike before block. Unlike block, the same plating value protects against every strike in the turn."],
	"ward": ["Ward", "A shared pool that absorbs curse, poison and reflected damage for this turn. It does not absorb ordinary strikes or the HP cost of Arcane Barter."],
	"poison": ["Poison", "Stacks deal damage after direct attacks and normally decay by 1 each turn. Block does not protect enemies from poison. Cleanse removes your poison before it ticks; ward can absorb its damage."],
	"burn": ["Burn", "Adds burning stacks to the enemy. They deal damage after direct attacks, bypass block and decay by 1 each turn."],
	"mana": ["Mana", "Magical activation resource. Refills to maximum every round; unused mana does not accumulate. Items pay both costs in priority order: 1–9, then unprioritized items. Ties use backpack reading order. Unaffordable items skip without spending either resource."],
	"stamina": ["Stamina", "Physical activation resource. Refills to maximum every round; unused stamina does not accumulate. Packed items can raise maximum stamina. During preparation, use the increase/decrease priority keybinds on an item to cycle none → 1–9 → none. Priorities 1–9 go first, followed by unprioritized items. Ties use backpack reading order."],
	"curse": ["Curse", "HP cost from cursed items each turn. Ward absorbs this cost before it reaches health. Arcane Barter is a separate cost that bypasses ward."],
	"thorns": ["Thorns", "Retaliation damage after each enemy strike, even when the strike is blocked. Bypasses block and can kill the enemy before its remaining strikes."],
	"cleanse": ["Cleanse", "Removes this many poison stacks from you before poison deals damage. It does not remove poison from enemies."],
	"slow": ["Slow", "A persistent condition that reduces each enemy strike before plating and block. Stacks lose 1 per round. Cleansing removes Slow."],
	"adjacency": ["Adjacent items", "Boosters affect touching compatible items. Shared edges count; diagonal contact needs Diagonal Thread. Folded Space connects the backpack's left and right edges."],
	"packed": ["Packed items", "Only items placed inside the backpack activate. Drag to rearrange during preparation between fights. Items start unprioritized, with no corner number. Use the increase/decrease priority keybinds to cycle none → 1–9 → none. Priorities 1–9 allocate first; unprioritized items go last. Ties use backpack reading order. Inventory stays locked while combat runs or is paused. Use your rotation keybinds to rotate the held shape. Empty corners can hold other items."],
	"unpacked": ["Stash", "Your stash holds carried items that do not activate. Open it beside Attack. Toss items into the pile, or grab and fling them around. Pull an item out into free backpack cells to use it. Drop a packed item into the stash or onto its button to store it."],
	"relics": ["Relics", "Permanent rules for this descent. Earn choices on floors 1, 5, 10 and 15, then claim them during preparation or after final victory from the relic reward icon beside the stash. Choices accumulate until claimed. Relics do not occupy backpack cells. Hover a bound relic to inspect its effect."],
	"momentum": ["Momentum", "Warmonger resource. Starts at 0 each fight and gains 1 after each completed exchange with the enemy. Specialized equipment can build Momentum or spend it for stronger strikes, following activation priority. An unaffordable activation spends none of its costs. Accumulates without a cap and resets for the next fight."],
	"volley": ["Volley", "The Bowmaster's Quiver launches a separate attack every 3 rounds, or every 2 with Quick Loader. Arrow type, quiver upgrades and touching equipment determine its effects. Crafted quiver fittings add arrows or flat Volley bonuses while touching the quiver. Bows attack normally; Volley costs no mana or stamina."],
	"backpack_locked": ["Bound equipment", "Cannot be put in the stash or removed from the backpack. You can move and rotate it during preparation. This is separate from preventing crafting."],
	"shadowstep": ["Shadowstep", "The Assassin is invisible on turns 1, 4, 7 and so on. Monsters cannot target them: all strikes and on-hit effects are skipped. Existing poison, reflection and item costs still apply."],
	"spellweaving": ["Elemental Reactions", "The Elementalist has 6 innate mana and no innate stamina. Elemental casts leave traces for 2 rounds. Reactions consume traces and can create new traces, allowing finite chains."],
	"elemental_reactions": ["Elemental Reactions", "Combine elemental traces to trigger reactions. Three-element recipes resolve before pairs. Each reaction consumes more traces than it produces, so chains always run out of fuel."],
	"doom": ["Doom", "Void applies Doom. Stacks detonate for 2 magical damage each on the third round, ignoring block. New stacks increase the burst without resetting its countdown. Cleansing removes Doom."],
	"spark": ["Spark", "Lightning applies Spark. On a later magical hit, existing stacks deal 2 magical damage each, ignoring block, then lose 1 stack. Newly applied stacks wait until a later hit. Cleansing removes Spark."],
	"physical_attack": ["Physical damage", "Ordinary weapons, bows, bone thralls and thorns deal physical damage. Physical resistance reduces it by a percentage before block. Piercing bypasses block, not resistance."],
	"magical_attack": ["Magical damage", "Spells and all elemental weapons deal magical damage. Magical resistance reduces direct damage before block and also reduces poison, burn, Spark and Doom damage. Conditions bypass block."],
	"physical_resistance": ["Physical resistance", "Reduces physical damage by this percentage before block. Values range from 0 to 100 percent; fractional damage rounds down."],
	"magical_resistance": ["Magical resistance", "Reduces magical damage by this percentage before block. Also reduces magical condition damage. Values range from 0 to 100 percent; fractional damage rounds down."],
	"fire": ["Fire", "An element that deals magical damage and applies Burn. The Elementalist's fire casts also leave fire traces for reactions."],
	"frost": ["Frost", "An element that deals magical damage and applies Slow. Slow persists, reduces each enemy strike and loses 1 stack per round."],
	"lightning": ["Lightning", "An element that deals magical damage and applies Spark. The Elementalist's lightning casts also leave lightning traces."],
	"void": ["Void", "An element that deals magical damage and applies Doom. The Elementalist's void casts also leave void traces."],
	"venom": ["Venom", "An element that deals magical damage and applies Poison. Ordinary poisoned weapons can still deal physical direct damage."],
	"thralls": ["Bone thralls", "The Necromancer starts with one thrall and gains another after each defeated monster, up to 3. Each adds 2 direct damage before block. They persist between floors."],
	"attack": ["Attack", "Starts automatic combat. All eligible packed item contributions resolve together in each champion action, followed by the enemy response and ongoing effects. Victory descends automatically; the next room waits for Attack. Pause freezes combat while logs, tabs and inspection stay usable. Prepare items and claim saved rewards between fights."],
	"spells": ["Spells", "Packed spells contribute to the combined champion action when they can pay both resource costs. Allocation follows priority, then backpack reading order."],
}
## UI/game mechanics explanations, separate from combat stats and status effects.
const META_ENTRIES: Dictionary = {
	"shield": ["Shields", "An equipment category. Packed shields grant block and may have additional item effects. Block is the combat protection pool used by both you and enemies."],
	"priority": ["Priority", "Use the increase/decrease priority keybinds while hovering an item to cycle none → 1–9 → none, forward or backward. Numbered priorities activate first: 1 is highest, followed by 2 through 9. No priority is the lowest group. Items sharing a priority, including unprioritized items, use backpack reading order: left to right, then top to bottom. Unaffordable items skip without spending either resource. Change priorities before battle."]
}

static var ALIASES: Dictionary = _build_aliases()

static func entry(key: String) -> Dictionary:
	var ability: Dictionary = preload("res://systems/relics/relic_abilities.gd").entry(key)
	if not ability.is_empty(): return ability
	if key.begins_with("restriction_class_") or key.begins_with("restriction_character_"):
		var is_character: bool = key.begins_with("restriction_character_")
		var id: String = key.trim_prefix("restriction_character_" if is_character else "restriction_class_")
		var record: Dictionary = preload("res://systems/content/content_restrictions.gd").character(id)
		if record.is_empty():
			return {}
		return {"key": key, "title": str(record.get("name", id)) if is_character else id.capitalize(), "body": str(record.get("bio", {}).get("summary", "")) + "\n\n" + str(PackCatalog.classes()[id]["detail"]), "kind": "meta"}
	if key.begins_with("catalog_item_"):
		return preload("res://systems/items/item_presentation.gd").catalog_inspection(key.trim_prefix("catalog_item_"))
	var elements = preload("res://systems/combat/elemental_combat.gd")
	if key.begins_with("reaction_"):
		var recipe: Dictionary = elements.reaction(key.trim_prefix("reaction_"))
		if not recipe.is_empty():
			var effects: Array[Dictionary] = []
			for stat_type: int in [GameplayTypes.Stat.DAMAGE, GameplayTypes.Stat.BURN, GameplayTypes.Stat.SLOW, GameplayTypes.Stat.SPARK, GameplayTypes.Stat.DOOM, GameplayTypes.Stat.POISON, GameplayTypes.Stat.PIERCE]:
				var stat: String = str(GameplayTypes.stat_id(stat_type))
				if int(recipe.get(stat_type, 0)) > 0:
					effects.append({"key": "magical_attack" if stat == "damage" else ("piercing" if stat == "pierce" else stat), "value": int(recipe[stat_type])})
			return {"key": key, "title": recipe["name"], "keyword_list": effects, "body": "Consumes " + " + ".join(recipe["needs"].map(func(value): return str(GameplayTypes.element_id(value)))) + " traces\nProduces " + " + ".join(recipe["produces"].map(func(value): return str(GameplayTypes.element_id(value)))) + " trace"}
	if key == "elemental_reactions":
		var names := PackedStringArray()
		for recipe: Dictionary in elements.REACTIONS:
			names.append(recipe["name"])
		return {"key": key, "title": ENTRIES[key][0], "body": ENTRIES[key][1] + "\n\n" + "\n".join(names)}
	if key == "armor":
		key = "block"
	if META_ENTRIES.has(key):
		return {"key": key, "title": META_ENTRIES[key][0], "body": META_ENTRIES[key][1], "kind": "meta"}
	if not ENTRIES.has(key):
		return {}
	return {"key": key, "title": ENTRIES[key][0], "body": ENTRIES[key][1]}

static func _build_aliases() -> Dictionary:
	# The registry owns illustrated aliases. Artwork-only additions are formatted
	# without links until they have an actual keyword definition.
	var result: Dictionary = PackKeywords.aliases()
	for condition: String in preload("res://systems/relics/relic_abilities.gd").DEFINITIONS:
		result[preload("res://systems/relics/relic_abilities.gd").DEFINITIONS[condition][0]] = "relic_ability_" + condition
	for key: String in ["elemental_reactions", "physical_attack", "magical_attack"]:
		result[{"elemental_reactions": "elemental reactions", "physical_attack": "physical damage", "magical_attack": "magical damage"}[key]] = key
	for recipe: Dictionary in preload("res://systems/combat/elemental_combat.gd").REACTIONS:
		result[recipe["name"]] = "reaction_" + str(recipe["id"])
	result["stash"] = "unpacked"
	result["unused items"] = "unpacked"
	for key: String in META_ENTRIES:
		result[key] = key
	result.merge({"packed": "packed", "direct damage": "damage", "damage": "damage", "armor piercing": "piercing", "piercing": "piercing", "armor": "block", "shield piercing": "piercing", "shield": "shield", "shields": "shield", "cleanse": "cleanse", "touching": "adjacency", "adjacent": "adjacency", "backpack": "packed", "unpacked": "unpacked", "relics": "relics", "Riposte": "riposte", "Volley": "volley", "Shadowstep": "shadowstep", "bone thralls": "thralls", "spells": "spells"})
	result.erase("Riposte")
	result["Momentum"] = "momentum"
	result["momentum"] = "momentum"
	return result

static func rich(text: String, exclude: String = "", links: bool = true) -> String:
	# Tokenize markup first. Never decorate tag attributes, resource paths, image
	# bodies, existing links or already colored spans (including our own output).
	var protected := RegEx.new()
	protected.compile("(?is)\\[(img|url|color|code|font)(?:[ =][^\\]]*)?\\].*?\\[/\\1\\]|\\[[^\\]]*\\]")
	var output: String = ""
	var cursor: int = 0
	for tag in protected.search_all(text):
		output += _rich_plain(text.substr(cursor, tag.get_start() - cursor), exclude, links)
		output += tag.get_string()
		cursor = tag.get_end()
	return output + _rich_plain(text.substr(cursor), exclude, links)

static func _rich_plain(text: String, exclude: String, links: bool) -> String:
	var aliases: Array = ALIASES.keys()
	aliases.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var regex := RegEx.new()
	var amount: String = "[+-]?\\d+(?:\\.\\d+)?(?:[ \\t]*/[ \\t]*\\d+(?:\\.\\d+)?)?%?"
	regex.compile("(?i)(?<![\\w/])(?:(" + amount + "[ \\t]+))?(" + "|".join(aliases) + ")(?![\\w/])([ \\t]+" + amount + ")?")
	var output: String = ""
	var cursor: int = 0
	for found in regex.search_all(text):
		var word: String = found.get_string(2)
		var key: String = keyword_key(word)
		var prefix: String = found.get_string(1)
		var suffix: String = found.get_string(3)
		var tint: String = PackKeywords.color(key).to_html(false)
		var pair: String = "[color=#%s]%s%s%s%s[/color]" % [tint, prefix, PackKeywords.image_markup(key), word, suffix]
		if META_ENTRIES.has(key) or key.begins_with("relic_ability_"):
			pair = prefix + word + suffix
		if links and key != exclude and (ENTRIES.has(key) or META_ENTRIES.has(key) or key.begins_with("reaction_") or key.begins_with("relic_ability_")):
			pair = "[url=%s]%s[/url]" % [key, pair]
		output += text.substr(cursor, found.get_start() - cursor) + pair
		cursor = found.get_end()
	return output + text.substr(cursor)

static func keyword_key(word: String) -> String:
	for alias: String in ALIASES:
		if alias.to_lower() == word.to_lower():
			return ALIASES[alias]
	return ""

## Darken an entire keyword pair, including inline images, without changing layout.
static func hover_markup(text: String, hovered: String, default_color: Color) -> String:
	if hovered.is_empty():
		return text
	var urls := RegEx.new()
	urls.compile("(?s)(\\[url(?:=| href=)([^ \\]]+)[^\\]]*\\])(.*?)(\\[/url\\])")
	var colors := RegEx.new()
	colors.compile("color=(#[0-9A-Fa-f]{6,8})")
	var output: String = ""
	var cursor: int = 0
	for found in urls.search_all(text):
		output += text.substr(cursor, found.get_start() - cursor)
		if found.get_string(2) != hovered:
			output += found.get_string()
		else:
			var contents: String = found.get_string(3)
			var matches: Array[RegExMatch] = colors.search_all(contents)
			matches.reverse()
			for tint in matches:
				var darker: String = Color(tint.get_string(1)).darkened(0.28).to_html(false)
				contents = contents.left(tint.get_start(1)) + "#" + darker + contents.substr(tint.get_end(1))
			output += found.get_string(1) + "[color=#%s]%s[/color]" % [default_color.darkened(0.28).to_html(false), contents] + found.get_string(4)
		cursor = found.get_end()
	return output + text.substr(cursor)
