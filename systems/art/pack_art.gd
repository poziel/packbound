class_name PackArt
extends RefCounted

const EXPANSION = preload("res://systems/art/expansion_art.gd")

const ITEMS: Texture2D = preload("res://assets/items/atlases/basic-items.svg")
const EXTRA_ITEMS: Texture2D = preload("res://assets/items/atlases/extra-items.svg")
const ENEMY_TEXTURES: Dictionary = {
	"cellar_tick": preload("res://assets/enemies/cellar_tick/art/cellar_tick.png"),
	"wick_bat": preload("res://assets/enemies/wick_bat/art/wick_bat.png"),
	"copper_scarab": preload("res://assets/enemies/copper_scarab/art/copper_scarab.png"),
	"tallow_slug": preload("res://assets/enemies/tallow_slug/art/tallow_slug.png"),
	"bramble_crab": preload("res://assets/enemies/bramble_crab/art/bramble_crab.png"),
	"shroud_moth": preload("res://assets/enemies/shroud_moth/art/shroud_moth.png"),
	"sewer_asp": preload("res://assets/enemies/sewer_asp/art/sewer_asp.png"),
	"carrion_rook": preload("res://assets/enemies/carrion_rook/art/carrion_rook.png"),
	"chalk_toad": preload("res://assets/enemies/chalk_toad/art/chalk_toad.png"),
	"needle_spider": preload("res://assets/enemies/needle_spider/art/needle_spider.png"),
	"ossuary_hound": preload("res://assets/enemies/ossuary_hound/art/ossuary_hound.png"),
	"chain_snail": preload("res://assets/enemies/chain_snail/art/chain_snail.png"),
	"soot_jelly": preload("res://assets/enemies/soot_jelly/art/soot_jelly.png"),
	"bog_stalker": preload("res://assets/enemies/bog_stalker/art/bog_stalker.png"),
	"tomb_mason": preload("res://assets/enemies/tomb_mason/art/tomb_mason.png"),
	"gutter_duelist": preload("res://assets/enemies/gutter_duelist/art/gutter_duelist.png"),
	"marrow_heron": preload("res://assets/enemies/marrow_heron/art/marrow_heron.png"),
	"cinder_boar": preload("res://assets/enemies/cinder_boar/art/cinder_boar.png"),
	"velvet_widow": preload("res://assets/enemies/velvet_widow/art/velvet_widow.png"),
	"reliquary_fungus": preload("res://assets/enemies/reliquary_fungus/art/reliquary_fungus.png"),
	"brass_mantis": preload("res://assets/enemies/brass_mantis/art/brass_mantis.png"),
	"pallbearer": preload("res://assets/enemies/pallbearer/art/pallbearer.png"),
	"salt_mirror": preload("res://assets/enemies/salt_mirror/art/salt_mirror.png"),
	"crypt_fencer": preload("res://assets/enemies/crypt_fencer/art/crypt_fencer.png"),
	"pitch_eel": preload("res://assets/enemies/pitch_eel/art/pitch_eel.png"),
	"crown_scorpion": preload("res://assets/enemies/crown_scorpion/art/crown_scorpion.png"),
	"bellroot": preload("res://assets/enemies/bellroot/art/bellroot.png"),
	"mourning_gargoyle": preload("res://assets/enemies/mourning_gargoyle/art/mourning_gargoyle.png"),
	"coffin_mimic": preload("res://assets/enemies/coffin_mimic/art/coffin_mimic.png"),
	"shroud_abjurer": preload("res://assets/enemies/shroud_abjurer/art/shroud_abjurer.png"),
	"kiln_tortoise": preload("res://assets/enemies/kiln_tortoise/art/kiln_tortoise.png"),
	"pale_huntsman": preload("res://assets/enemies/pale_huntsman/art/pale_huntsman.png"),
	"blood_orchid": preload("res://assets/enemies/blood_orchid/art/blood_orchid.png"),
	"chain_penitent": preload("res://assets/enemies/chain_penitent/art/chain_penitent.png"),
	"vault_custodian": preload("res://assets/enemies/vault_custodian/art/vault_custodian.png"),
	"last_vesper": preload("res://assets/enemies/last_vesper/art/last_vesper.png"),
	"ash_rat": preload("res://assets/enemies/ash_rat.png"),
	"bone_thief": preload("res://assets/enemies/bone_thief.png"),
	"lantern_wretch": preload("res://assets/enemies/lantern_wretch.png"),
	"iron_mite": preload("res://assets/enemies/iron_mite.png"),
	"pack_leech": preload("res://assets/enemies/pack_leech.png"),
	"mire_viper": preload("res://assets/enemies/mire_viper.png"),
	"bell_sentinel": preload("res://assets/enemies/bell_sentinel.png"),
	"mirror_wisp": preload("res://assets/enemies/mirror_wisp.png"),
	"rust_knight": preload("res://assets/enemies/rust_knight.png"),
	"crypt_butcher": preload("res://assets/enemies/crypt_butcher.png"),
	"hollow_monk": preload("res://assets/enemies/hollow_monk.png"),
	"carrion_swarm": preload("res://assets/enemies/carrion_swarm.png"),
	"glass_duelist": preload("res://assets/enemies/glass_duelist.png"),
	"cinder_oracle": preload("res://assets/enemies/cinder_oracle.png"),
	"grave_keeper": preload("res://assets/enemies/grave_keeper.png"),
	"iron_matron": preload("res://assets/enemies/iron_matron.png"),
	"clockwork_warden": preload("res://assets/enemies/clockwork_warden.png"),
	"blood_collector": preload("res://assets/enemies/blood_collector.png"),
	"oathbreaker": preload("res://assets/enemies/oathbreaker.png"),
	"zippered_maw": preload("res://assets/enemies/zippered_maw.png"),
}
const CONTROLS: Texture2D = preload("res://themes/gameplay/controls.svg")
const ITEM_TEXTURES: Dictionary = {
	"field_blade": preload("res://assets/items/field_blade/icons/art/icon.svg"),
	"riveted_guard": preload("res://assets/items/riveted_guard/icons/art/icon.svg"),
	"tempered_blade": preload("res://assets/items/tempered_blade/icons/art/icon.svg"),
	"iron_guard": preload("res://assets/items/iron_guard/icons/art/icon.svg"),
	"oathsteel_blade": preload("res://assets/items/oathsteel_blade/icons/art/icon.svg"),
	"sentinel_guard": preload("res://assets/items/sentinel_guard/icons/art/icon.svg"),
	"dusksteel_blade": preload("res://assets/items/dusksteel_blade/icons/art/icon.svg"),
	"citadel_guard": preload("res://assets/items/citadel_guard/icons/art/icon.svg"),
	"dawnbringer": preload("res://assets/items/dawnbringer/icons/art/icon.svg"),
	"sovereign_guard": preload("res://assets/items/sovereign_guard/icons/art/icon.svg"),
	"tower_shield": preload("res://assets/items/relics/shield-relic/revisions/catalog-v1/shield-relic-32px.svg"),
	"antidote": preload("res://assets/items/healing/antidote/revisions/catalog-v1/antidote-32px.svg"),
	"mirror_shard": preload("res://assets/items/utility/mirror-shard/revisions/catalog-v2/mirror-shard-64px.svg"),
	"hourglass": preload("res://assets/items/utility/hourglass/revisions/catalog-v1/hourglass-96x64.svg"),
	"healing_herbs": preload("res://assets/items/healing/healing-herbs/revisions/catalog-v2/healing-herbs-64px.svg"),
	"hunting_trap": preload("res://assets/items/traps/hunting-trap/revisions/catalog-v1/hunting-trap-96x64.svg"),
	"warding_sigil": preload("res://assets/items/charms/warding-sigil/revisions/catalog-v1/warding-sigil-96px.svg"),
	"thorn_mail": preload("res://assets/items/armor/thorn-mail/revisions/catalog-v2/thorn-mail-64px.svg"),
	"plate_mail": preload("res://assets/items/armor/plate-mail/revisions/catalog-v2/plate-mail-96x64.svg"),
	"vampire_fang": preload("res://assets/items/weapons/vampire-fang/revisions/catalog-v1/vampire-fang-32x64.svg"),
	"spark_ring": preload("res://assets/items/charms/spark-ring/revisions/catalog-v1/spark-ring-32px.svg"),
	"frost_wand": preload("res://assets/items/spells/frost-wand/revisions/catalog-v2/frost-wand-32x96.svg"),
	"ember_tome": preload("res://assets/items/spells/ember-tome/revisions/catalog-v1/ember-tome-64px.svg"),
	"buckler": preload("res://assets/items/armor/buckler/revisions/catalog-v1/buckler-32px.svg"),
	"quiver": preload("res://assets/items/ammunition/quiver/revisions/catalog-v1/quiver-32x64.svg"),
	"shortbow": preload("res://assets/items/weapons/shortbow/revisions/catalog-v1/shortbow-64px.svg"),
	"battle_axe": preload("res://assets/items/weapons/battle-axe/revisions/catalog-v4/executioners-axe-96x64.svg"),
	"longsword": preload("res://assets/items/weapons/iron-dagger/revisions/catalog-v1/iron-dagger-32px.svg"),
	"rusty_knife": preload("res://assets/items/weapons/rusty-knife/revisions/catalog-v1/rusty-knife-32px.svg"),
	"cracked_shield": preload("res://assets/items/armor/cracked-shield/revisions/catalog-v2/cracked-shield-32px.svg"),
	"blood_gem": preload("res://assets/items/charms/blood-gem/revisions/catalog-v2/blood-gem-32px.svg"),
	"bandage": preload("res://assets/items/healing/bandage/revisions/catalog-v1/grave-bandage-32px.svg"),
	"cursed_idol": preload("res://assets/items/relics/cursed-idol/revisions/catalog-v3/cursed-idol-32px.svg"),
	"iron_charm": preload("res://assets/items/charms/iron-charm/revisions/catalog-v2/iron-charm-32px.svg"),
	"venom_dagger": preload("res://assets/items/weapons/venom-dagger/revisions/catalog-v1/venom-dagger-64px.svg"),
}
const RELIC_TEXTURES: Dictionary = {
	"hearth_token": preload("res://assets/relics/hearth_token/icons/art/icon.svg"),
	"herbalist_knot": preload("res://assets/relics/herbalist_knot/icons/art/icon.svg"),
	"trail_medallion": preload("res://assets/relics/trail_medallion/icons/art/icon.svg"),
	"bastion_seal": preload("res://assets/relics/bastion_seal/icons/art/icon.svg"),
	"starwell_crown": preload("res://assets/relics/starwell_crown/icons/art/icon.svg"),
	"diagonal_thread": preload("res://assets/relics/diagonal-thread/revisions/catalog-v2/diagonal-thread-32px.svg"),
	"returning_guard": preload("res://assets/relics/returning-guard/revisions/catalog-v1/returning-guard-32px.svg"),
	"blood_pact": preload("res://assets/relics/blood-pact/revisions/catalog-v1/blood-pact-32px.svg"),
	"plague_seal": preload("res://assets/relics/plague-seal/revisions/catalog-v2/plague-seal-32px.svg"),
	"echo_clock": preload("res://assets/relics/echo-clock/revisions/catalog-v2/echo-clock-32px.svg"),
	"arcane_barter": preload("res://assets/relics/arcane-barter/revisions/catalog-v1/arcane-barter-32px.svg"),
	"folded_space": preload("res://assets/relics/folded-space/revisions/catalog-v1/folded-space-32px.svg"),
	"mana_furnace": preload("res://assets/relics/mana-furnace/revisions/catalog-v1/mana-furnace-32px.svg"),
	"last_thread": preload("res://assets/relics/last-thread/revisions/catalog-v1/last-thread-32px.svg"),
}
const ITEM_VIEW_TEXTURES: Dictionary = {
}
const ENEMY_KEYS: Array[String] = ["ash_rat", "bone_thief", "lantern_wretch", "iron_mite", "pack_leech", "mire_viper", "bell_sentinel", "mirror_wisp", "rust_knight", "crypt_butcher", "hollow_monk", "carrion_swarm", "glass_duelist", "cinder_oracle", "grave_keeper", "iron_matron", "clockwork_warden", "blood_collector", "oathbreaker", "zippered_maw", "cellar_tick", "wick_bat", "copper_scarab", "tallow_slug", "bramble_crab", "shroud_moth", "sewer_asp", "carrion_rook", "chalk_toad", "needle_spider", "ossuary_hound", "chain_snail", "soot_jelly", "bog_stalker", "tomb_mason", "gutter_duelist", "marrow_heron", "cinder_boar", "velvet_widow", "reliquary_fungus", "brass_mantis", "pallbearer", "salt_mirror", "crypt_fencer", "pitch_eel", "crown_scorpion", "bellroot", "mourning_gargoyle", "coffin_mimic", "shroud_abjurer", "kiln_tortoise", "pale_huntsman", "blood_orchid", "chain_penitent", "vault_custodian", "last_vesper"]

static func character_head(key: String) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/characters/%s/art/portrait.png" % key)
	texture.region = Rect2(Vector2.ZERO, texture.atlas.get_size())
	texture.filter_clip = true
	return texture

static func item(key: String, view_edge: int = 0) -> AtlasTexture:
	if PackCatalog.ELEMENTAL_ITEMS.has(key):
		key = PackCatalog.ELEMENTAL_ITEMS[key]["template"]
	if key == PackCatalog.QUIVER.KEY or PackCatalog.QUIVER.OPTIONS.has(key):
		key = "quiver"
	var texture: AtlasTexture = AtlasTexture.new()
	if EXPANSION.ITEM_TEXTURES.has(key):
		texture.atlas = EXPANSION.ITEM_TEXTURES[key]
		texture.region = Rect2(Vector2.ZERO, texture.atlas.get_size())
		return texture
	# Individual native-size exports coexist with the earlier atlas during migration.
	if ITEM_TEXTURES.has(key):
		texture.atlas = ITEM_TEXTURES[key]
		# The requested edge is for the whole item, not each occupied backpack cell.
		# A large base sprite therefore serves smaller views without another asset.
		var views: Dictionary = ITEM_VIEW_TEXTURES.get(key, {})
		for edge: int in [64, 128]:
			if maxf(texture.atlas.get_width(), texture.atlas.get_height()) < view_edge and views.has(edge):
				texture.atlas = views[edge]
		texture.region = Rect2(Vector2.ZERO, texture.atlas.get_size())
		return texture
	var index: int = PackRun.ROSTER.find(key)
	texture.atlas = ITEMS if index < 8 else EXTRA_ITEMS
	texture.region = Rect2((index if index < 8 else index - 8) * 96, 0, 96, 96)
	return texture

static func relic(key: String) -> AtlasTexture:
	var texture := AtlasTexture.new()
	if EXPANSION.RELIC_TEXTURES.has(key):
		texture.atlas = EXPANSION.RELIC_TEXTURES[key]
		texture.region = Rect2(Vector2.ZERO, texture.atlas.get_size())
		return texture
	texture.atlas = RELIC_TEXTURES[key]
	texture.region = Rect2(Vector2.ZERO, texture.atlas.get_size())
	return texture

static func enemy(key: String) -> AtlasTexture:
	var texture: AtlasTexture = AtlasTexture.new()
	# Every species keeps its native size inside the same registered canvas.
	texture.atlas = ENEMY_TEXTURES.get(key, ENEMY_TEXTURES["bone_thief"])
	texture.region = Rect2(Vector2.ZERO, texture.atlas.get_size())
	texture.filter_clip = true
	return texture

static func control(index: int) -> AtlasTexture:
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = CONTROLS
	texture.region = Rect2(index * 32, 0, 32, 32)
	return texture

static func color(key: String) -> Color:
	if key == "blood_gem": return Color("ed8497")
	match PackCatalog.item(key)["role"]:
		"weapon": return Color("dc9c79")
		"shield", "armor": return Color("7cb8c4")
		"ranged": return Color("b8d09b")
		"spell", "focus": return Color("a7bae7")
		"healer": return Color("afd39d")
		_: return Color("d5bf8e")

static func style(bg: Color, border: Color, width: int = 1, radius: int = 6) -> StyleBoxFlat:
	var result: StyleBoxFlat = StyleBoxFlat.new()
	result.bg_color = bg
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(radius)
	return result
