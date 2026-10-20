class_name PackArt
extends RefCounted

const CATEGORIES = preload("res://systems/content/collectible_categories.gd")

const CONTROLS: Texture2D = preload("res://themes/gameplay/controls.svg")
static var ENEMY_TEXTURES: Dictionary:
	get:
		var result: Dictionary = {}
		for value: MonsterDefinition in preload("res://systems/content/runtime_content.gd").content().monsters:
			result[str(value.id)] = value.icon.atlas if value.icon is AtlasTexture else value.icon
		return result
static var ENEMY_KEYS: Array[String]:
	get:
		var result: Array[String] = []
		result.assign(ENEMY_TEXTURES.keys())
		return result

static func character_head(key: String) -> AtlasTexture:
	return _definition_texture(preload("res://systems/content/runtime_content.gd").character(key).icon)

static func item(key: String, _view_edge: int = 0) -> AtlasTexture:
	return _definition_texture(CATEGORIES.definition_for_key(key).icon)

static func relic(key: String) -> AtlasTexture:
	return _definition_texture(CATEGORIES.definition_for_key(key).icon)

static func enemy(key: String) -> AtlasTexture:
	var value: MonsterDefinition = preload("res://systems/content/runtime_content.gd").monster_definition(key)
	return _definition_texture(value.icon) if value != null else null

static func _definition_texture(icon: Texture2D) -> AtlasTexture:
	if icon is AtlasTexture:
		return icon
	var texture := AtlasTexture.new()
	texture.atlas = icon
	texture.region = Rect2(Vector2.ZERO, icon.get_size())
	texture.filter_clip = true
	return texture

static func control(index: int) -> AtlasTexture:
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = CONTROLS
	texture.region = Rect2(index * 32, 0, 32, 32)
	return texture

static func color(key: String) -> Color:
	if key == "blood_gem": return Color("ed8497")
	var item: Dictionary = PackCatalog.item(key)
	if CATEGORIES.matches(item, &"melee_weapons"): return Color("dc9c79")
	if CATEGORIES.matches_any(item, ["shields", "body_armor"]): return Color("7cb8c4")
	if CATEGORIES.matches(item, &"ranged_weapons"): return Color("b8d09b")
	if CATEGORIES.matches_any(item, ["magic_weapons", "focuses"]): return Color("a7bae7")
	if CATEGORIES.matches(item, &"healing_supplies"): return Color("afd39d")
	return Color("d5bf8e")

static func style(bg: Color, border: Color, width: int = 1, radius: int = 6) -> StyleBoxFlat:
	var result: StyleBoxFlat = StyleBoxFlat.new()
	result.bg_color = bg
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(radius)
	return result
