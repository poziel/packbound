extends RefCounted
## Compatibility membership lists; authored recipe Resources own all values.
static var LARGE_RECIPES: Array[Dictionary]:
	get:
		return _select(["assemble_mountain_s_verdict", "assemble_horizon_harp", "assemble_the_unwritten_sun", "assemble_cathedral_carapace", "assemble_seven_league_soles", "assemble_captive_aurora", "assemble_choir_eel", "assemble_furnace_toad", "assemble_porcelain_lung", "assemble_last_legion_aegis", "assemble_endless_flight_spool", "assemble_cathedral_of_sparks", "assemble_storm_abacus", "assemble_absent_atlas", "assemble_viper_s_proposition", "assemble_gravetread_boots", "assemble_amber_heart_pendant", "assemble_pocket_basilisk", "assemble_pilgrim_crab", "assemble_bottle_of_yesterday", "assemble_blacksmith_s_apron", "assemble_mercy_needlecase", "assemble_moonwell_pebble", "assemble_gilded_scarab", "assemble_meteor_maul", "assemble_gallows_halberd", "assemble_siegebell_plate", "assemble_war_council_seal", "assemble_thunder_yew", "assemble_scorpion_magazine", "assemble_seamfinder_lens", "assemble_gloam_lynx", "assemble_solar_crucible", "assemble_winter_orrery", "assemble_black_rain_theorem", "assemble_orchid_eclipse"])
static var PAIR_RECIPES: Array[Dictionary]:
	get:
		return _select(["assemble_hooked_falchion", "assemble_boiler_hammer", "assemble_standard_spike", "assemble_vanguard_sabaton", "assemble_duelist_s_coin", "assemble_hornback_bow", "assemble_barbed_tip_roll", "assemble_waxed_fletching", "assemble_adder_sheath", "assemble_pathfinder_gaiters", "assemble_kiln_prayer", "assemble_icicle_rosary", "assemble_copper_cicada", "assemble_hollow_bookmark", "assemble_foxglove_formula", "assemble_mothweave_mantle", "assemble_ironroot_boots", "assemble_pearl_of_brine", "assemble_lantern_moth_familiar", "assemble_marrow_sparrow", "assemble_raincatch_bowl", "assemble_roseglass_brooch", "assemble_thorn_whetstone", "assemble_wax_ear_trumpet", "assemble_anchor_cleaver", "assemble_oathbreaker_flail", "assemble_redoubt_cuirass", "assemble_cadence_spurs", "assemble_captain_s_baton", "assemble_glass_reed_bow", "assemble_cinder_nock_rack", "assemble_winterflight_rack", "assemble_hunter_s_compass", "assemble_burrow_falcon", "assemble_salamander_contract", "assemble_glacier_diagram"])
static var RECIPES: Array[Dictionary]:
	get:
		return LARGE_RECIPES + PAIR_RECIPES

static func _select(ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe: Dictionary in preload("res://systems/content/runtime_content.gd").recipes():
		if ids.has(recipe.id):
			result.append(recipe)
	return result
