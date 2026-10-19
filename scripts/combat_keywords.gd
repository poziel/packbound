@tool
@static_unload
class_name PackKeywords
extends RefCounted
## Shared selected registry for combat keyword identities, aliases, colors and white masks.

static var _registry: Dictionary = {}
static var _textures: Dictionary = {}
const ELEMENT_TERMS: Dictionary = {
	"spark": ["Spark", "#E6CA65"], "physical_resistance": ["Physical resistance", "#ABB7C5"], "magical_resistance": ["Magical resistance", "#B59ADE"],
	"fire": ["Fire", "#E8A055"], "frost": ["Frost", "#8DBFDA"], "lightning": ["Lightning", "#E6CA65"], "void": ["Void", "#B59ADE"], "venom": ["Venom", "#A9CD65"]
}

static func registry() -> Dictionary:
	if _registry.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/keyword-icons/registry.json"))
		if parsed is Dictionary:
			_registry = parsed
			for key: String in ELEMENT_TERMS:
				if not _registry["keywords"].has(key):
					_registry["keywords"][key] = {"label": ELEMENT_TERMS[key][0], "aliases": [key.replace("_", " ")], "color_token": "keyword." + key, "icon_id": ""}
				if not _registry["palette"].has("keyword." + key):
					_registry["palette"]["keyword." + key] = {"default": ELEMENT_TERMS[key][1]}
	return _registry

static func resolve(key: String) -> String:
	var normalized: String = key.to_lower()
	# Legacy enemy armor is the same Block pool; shields are equipment.
	if normalized == "armor":
		return "block"
	for term: String in registry().get("keywords", {}):
		if normalized == term:
			return term
		for alias: String in registry()["keywords"][term].get("aliases", []):
			if normalized == alias.to_lower():
				return term
	return normalized

static func aliases() -> Dictionary:
	var result: Dictionary = {}
	for term: String in registry().get("keywords", {}):
		for alias: String in registry()["keywords"][term].get("aliases", []):
			result[alias] = term
	return result

static func color(key: String, context: String = "") -> Color:
	var term: String = resolve(key)
	var token: String = registry().get("keywords", {}).get(term, {}).get("color_token", "keyword." + term)
	var palette: Dictionary = registry().get("palette", {}).get(token, {})
	return Color(palette.get("theme_overrides", {}).get(context, palette.get("default", "#B6CBDC")))

static func icon_path(key: String, inline: bool = false) -> String:
	var term: Dictionary = registry().get("keywords", {}).get(resolve(key), {})
	var data: Dictionary = registry().get("icons", {}).get(term.get("icon_id", ""), {})
	var variant: Dictionary = data.get("variants", {}).get("16", {})
	return variant.get("inline_mask_png", variant.get("mask_png", "")) if inline else variant.get("mask_png", "")

static func has_icon(key: String) -> bool:
	return not icon_path(key).is_empty()

static func icon(key: String, inline: bool = false) -> Texture2D:
	var path: String = icon_path(key, inline)
	if path.is_empty():
		return null
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]

static func image_markup(key: String, context: String = "") -> String:
	var path: String = icon_path(key, true)
	if path.is_empty():
		return ""
	# Keep the accepted native pixels. Explicit image tint is verified in Godot;
	# no assumption that an SVG inherits a Label's font color.
	# Inline masks apply the registry's measured baseline correction inside the
	# same 16px box, without changing font metrics or paragraph line height.
	return "[img width=16 height=16 color=#%s align=center,center]%s[/img]\u2060\u00a0" % [color(key, context).to_html(false), path]

## Keyword stats are structured icon/value pairs, separate from keyword links in prose.
static func item_stats(item: Dictionary, adjacency_bonus: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stat: String in PackCatalog.STATS:
		var amount: int = int(item.get(stat, 0))
		if stat == "damage" or stat == "block":
			if amount > 0:
				amount += adjacency_bonus
		if amount == 0:
			continue
		var key: String = "piercing" if stat == "pierce" else stat
		var icon_key: String = key
		if stat == "damage":
			icon_key = "magical_attack" if preload("res://scripts/elemental_combat.gd").damage_type(item) == "magical" else "physical_attack"
		result.append({"key": key, "icon": icon_key, "value": amount, "qualifier": "maximum" if stat in ["mana", "stamina"] else ""})
	return result

static func item_priority_label(item: Dictionary) -> String:
	var priority: int = int(item.get("priority", 0))
	return "No priority" if priority == 0 else "Priority %d" % priority

static func item_footer_markup(costs: Array, priority_label: String = "", links: bool = true) -> String:
	var resources: String = resource_costs_markup(costs, links)
	if resources.is_empty() and priority_label.is_empty():
		return ""
	var priority: String = PackKeywordLinks.rich(priority_label, "", links)
	# Expanding columns keep costs left and Priority right on the same baseline.
	return "[table=2][cell shrink=false expand=1]%s[/cell][cell shrink=false expand=1][right]%s[/right][/cell][/table]" % [resources, priority]

## Activation costs have their own colored footer, separate from keyword lists/stats.
static func item_resource_costs(item: Dictionary) -> Array[Dictionary]:
	if not item.get("role", "") in ["weapon", "ranged", "spell"] and int(item.get("damage", 0)) <= 0 and int(item.get("cost", 0)) <= 0 and int(item.get("stamina_cost", 0)) <= 0:
		return []
	# Show both pools, including zero, so free activations are explicit.
	return [{"key": "stamina", "value": maxi(0, int(item.get("stamina_cost", 0)))}, {"key": "mana", "value": maxi(0, int(item.get("cost", 0)))}]

static func resource_costs_markup(costs: Array, links: bool = true) -> String:
	var pairs: PackedStringArray = []
	for cost: Dictionary in costs:
		var key: String = str(cost["key"])
		var glyph: String = image_markup(key).trim_suffix("\u2060\u00a0")
		var pair: String = "[color=#%s]%d\u2060\u00a0%s[/color]" % [color(key).to_html(false), int(cost["value"]), glyph]
		if links:
			pair = "[url href=%s underline=never]%s[/url]" % [key, pair]
		pairs.append(pair)
	return "    ".join(pairs)

static func relic_stats(relic: Dictionary) -> Array[Dictionary]:
	# Only explicit numeric effects can become stats. Conditional rules stay in prose.
	var result: Array[Dictionary] = []
	for stat: Dictionary in relic.get("keyword_stats", []):
		result.append(stat.duplicate(true))
	return result

## Item keyword lists read value, icon, name, with one attribute per line.
static func item_description(item: Dictionary) -> String:
	# Existing saved items predate tooltip_detail; resolve their current catalog rules.
	var item_key: String = str(item.get("key", ""))
	if item_key == PackCatalog.QUIVER.KEY:
		return PackCatalog.QUIVER.describe(item, 0)
	if item_key in PackCatalog.ROSTER:
		var definition: Dictionary = PackCatalog.item(item_key)
		var detail: String = str(definition.get("tooltip_detail", item.get("detail", "")))
		var element: String = str(item.get("element", definition.get("element", "")))
		return element.capitalize() + ("\n" + detail if not detail.is_empty() else "") if not element.is_empty() else detail
	return str(item.get("tooltip_detail", item.get("detail", "")))

static func list_markup(stats: Array, links: bool = true, default_color: Color = Color.TRANSPARENT) -> String:
	if default_color.a == 0.0:
		default_color = load("res://themes/gameplay/theme.tres").get_color("default_color", "RichTextLabel")
	var rows: PackedStringArray = []
	for stat: Dictionary in stats:
		var key: String = str(stat["key"])
		var glyph: String = image_markup(key)
		var label: String = str(registry().get("keywords", {}).get(key, {}).get("label", key.capitalize()))
		if PackKeywordLinks.ENTRIES.has(key):
			label = PackKeywordLinks.ENTRIES[key][0]
		var value: int = int(stat["value"])
		var qualifier: String = str(stat.get("qualifier", ""))
		if qualifier == "cost":
			value = -absi(value)
		var amount: String = ("+" if value >= 0 else "") + str(value)
		var row: String = amount + "\u00a0[color=#%s]%s%s[/color]" % [color(key).to_html(false), glyph, label]
		if not qualifier.is_empty():
			row += " (" + qualifier + ")"
		if links and PackKeywordLinks.ENTRIES.has(key):
			row = "[url href=%s underline=never]%s[/url]" % [key, row]
		rows.append(row)
	return "\n".join(rows)

static func stats_markup(stats: Array, links: bool = true, default_color: Color = Color.TRANSPARENT) -> String:
	if default_color.a == 0.0:
		default_color = load("res://themes/gameplay/theme.tres").get_color("default_color", "RichTextLabel")
	var pairs: PackedStringArray = []
	for stat: Dictionary in stats:
		var key: String = str(stat["key"])
		var icon_key: String = str(stat.get("icon", key))
		var glyph: String = image_markup(icon_key)
		glyph = glyph.replace("color=#" + color(icon_key).to_html(false), "color=#" + default_color.to_html(false))
		# Missing artwork retains a readable label; it must not produce a bare number.
		if glyph.is_empty():
			glyph = str(registry().get("keywords", {}).get(key, {}).get("label", key.capitalize())) + "\u00a0"
		var pair: String = glyph + str(stat["value"])
		var qualifier: String = str(stat.get("qualifier", ""))
		if not qualifier.is_empty():
			pair += " " + qualifier
		if links and PackKeywordLinks.ENTRIES.has(key):
			pair = "[url href=%s underline=never]%s[/url]" % [key, pair]
		pairs.append(pair)
	return "    ".join(pairs)
