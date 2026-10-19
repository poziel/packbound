extends RefCounted
## Longest connected recipes take priority; all inputs consumed at battle start.
const LARGE_RECIPES: Array[Dictionary] = [
  {
    "id": "assemble_mountain_s_verdict",
    "ingredients": [
      "anchor_cleaver",
      "gallows_halberd",
      "meteor_maul",
      "siegebell_plate",
      "war_council_seal"
    ],
    "result": "mountain_s_verdict"
  },
  {
    "id": "assemble_horizon_harp",
    "ingredients": [
      "glass_reed_bow",
      "gloam_lynx",
      "scorpion_magazine",
      "seamfinder_lens",
      "thunder_yew"
    ],
    "result": "horizon_harp"
  },
  {
    "id": "assemble_the_unwritten_sun",
    "ingredients": [
      "black_rain_theorem",
      "moonwell_pebble",
      "orchid_eclipse",
      "solar_crucible",
      "winter_orrery"
    ],
    "result": "the_unwritten_sun"
  },
  {
    "id": "assemble_cathedral_carapace",
    "ingredients": [
      "amber_heart_pendant",
      "blacksmith_s_apron",
      "pilgrim_crab",
      "salt_lantern"
    ],
    "result": "cathedral_carapace"
  },
  {
    "id": "assemble_seven_league_soles",
    "ingredients": [
      "cobbler_s_boots",
      "gravetread_boots",
      "ironroot_boots",
      "mercy_needlecase"
    ],
    "result": "seven_league_soles"
  },
  {
    "id": "assemble_captive_aurora",
    "ingredients": [
      "amber_heart_pendant",
      "bottle_of_yesterday",
      "moonwell_pebble",
      "pearl_of_brine"
    ],
    "result": "captive_aurora"
  },
  {
    "id": "assemble_choir_eel",
    "ingredients": [
      "gilded_scarab",
      "marrow_sparrow",
      "pocket_basilisk",
      "raincatch_bowl"
    ],
    "result": "choir_eel"
  },
  {
    "id": "assemble_furnace_toad",
    "ingredients": [
      "amber_heart_pendant",
      "blacksmith_s_apron",
      "chalk_poultice",
      "lantern_moth_familiar"
    ],
    "result": "furnace_toad"
  },
  {
    "id": "assemble_porcelain_lung",
    "ingredients": [
      "bottle_of_yesterday",
      "mercy_needlecase",
      "pearl_of_brine",
      "wax_ear_trumpet"
    ],
    "result": "porcelain_lung"
  },
  {
    "id": "assemble_last_legion_aegis",
    "ingredients": [
      "captain_s_baton",
      "redoubt_cuirass",
      "siegebell_plate",
      "warding_sigil"
    ],
    "result": "last_legion_aegis"
  },
  {
    "id": "assemble_endless_flight_spool",
    "ingredients": [
      "cinder_nock_rack",
      "scorpion_magazine",
      "seamfinder_lens",
      "winterflight_rack"
    ],
    "result": "endless_flight_spool"
  },
  {
    "id": "assemble_cathedral_of_sparks",
    "ingredients": [
      "black_rain_theorem",
      "solar_crucible",
      "storm_abacus",
      "winter_orrery"
    ],
    "result": "cathedral_of_sparks"
  },
  {
    "id": "assemble_storm_abacus",
    "ingredients": [
      "copper_cicada",
      "raincatch_bowl",
      "spark_ring"
    ],
    "result": "storm_abacus"
  },
  {
    "id": "assemble_absent_atlas",
    "ingredients": [
      "hollow_bookmark",
      "pearl_of_brine",
      "salt_lantern"
    ],
    "result": "absent_atlas"
  },
  {
    "id": "assemble_viper_s_proposition",
    "ingredients": [
      "antidote",
      "foxglove_formula",
      "thorn_whetstone"
    ],
    "result": "viper_s_proposition"
  },
  {
    "id": "assemble_gravetread_boots",
    "ingredients": [
      "hedgehog_charm",
      "ironroot_boots",
      "salt_lantern"
    ],
    "result": "gravetread_boots"
  },
  {
    "id": "assemble_amber_heart_pendant",
    "ingredients": [
      "acorn_pendant",
      "pearl_of_brine",
      "roseglass_brooch"
    ],
    "result": "amber_heart_pendant"
  },
  {
    "id": "assemble_pocket_basilisk",
    "ingredients": [
      "marrow_sparrow",
      "pearl_of_brine",
      "thorn_whetstone"
    ],
    "result": "pocket_basilisk"
  },
  {
    "id": "assemble_pilgrim_crab",
    "ingredients": [
      "ironroot_boots",
      "pearl_of_brine",
      "tin_beetle"
    ],
    "result": "pilgrim_crab"
  },
  {
    "id": "assemble_bottle_of_yesterday",
    "ingredients": [
      "raincatch_bowl",
      "salt_lantern",
      "wax_ear_trumpet"
    ],
    "result": "bottle_of_yesterday"
  },
  {
    "id": "assemble_blacksmith_s_apron",
    "ingredients": [
      "ironroot_boots",
      "lantern_moth_familiar",
      "patchwork_jack"
    ],
    "result": "blacksmith_s_apron"
  },
  {
    "id": "assemble_mercy_needlecase",
    "ingredients": [
      "antidote",
      "chalk_poultice",
      "roseglass_brooch"
    ],
    "result": "mercy_needlecase"
  },
  {
    "id": "assemble_moonwell_pebble",
    "ingredients": [
      "raincatch_bowl",
      "salt_lantern",
      "spark_ring"
    ],
    "result": "moonwell_pebble"
  },
  {
    "id": "assemble_gilded_scarab",
    "ingredients": [
      "hedgehog_charm",
      "tin_beetle",
      "wax_ear_trumpet"
    ],
    "result": "gilded_scarab"
  },
  {
    "id": "assemble_meteor_maul",
    "ingredients": [
      "amber_heart_pendant",
      "anchor_cleaver",
      "boiler_hammer"
    ],
    "result": "meteor_maul"
  },
  {
    "id": "assemble_gallows_halberd",
    "ingredients": [
      "marching_pike",
      "oathbreaker_flail",
      "thorn_whetstone"
    ],
    "result": "gallows_halberd"
  },
  {
    "id": "assemble_siegebell_plate",
    "ingredients": [
      "hedgehog_charm",
      "ironroot_boots",
      "redoubt_cuirass"
    ],
    "result": "siegebell_plate"
  },
  {
    "id": "assemble_war_council_seal",
    "ingredients": [
      "cadence_spurs",
      "captain_s_baton",
      "roseglass_brooch"
    ],
    "result": "war_council_seal"
  },
  {
    "id": "assemble_thunder_yew",
    "ingredients": [
      "barbed_tip_roll",
      "gilded_scarab",
      "glass_reed_bow"
    ],
    "result": "thunder_yew"
  },
  {
    "id": "assemble_scorpion_magazine",
    "ingredients": [
      "adder_sheath",
      "briar_snare",
      "gilded_scarab"
    ],
    "result": "scorpion_magazine"
  },
  {
    "id": "assemble_seamfinder_lens",
    "ingredients": [
      "glass_reed_bow",
      "hunter_s_compass",
      "pearl_of_brine"
    ],
    "result": "seamfinder_lens"
  },
  {
    "id": "assemble_gloam_lynx",
    "ingredients": [
      "burrow_falcon",
      "gravetread_boots",
      "pocket_basilisk"
    ],
    "result": "gloam_lynx"
  },
  {
    "id": "assemble_solar_crucible",
    "ingredients": [
      "kiln_prayer",
      "moonwell_pebble",
      "salamander_contract"
    ],
    "result": "solar_crucible"
  },
  {
    "id": "assemble_winter_orrery",
    "ingredients": [
      "bottle_of_yesterday",
      "glacier_diagram",
      "icicle_rosary"
    ],
    "result": "winter_orrery"
  },
  {
    "id": "assemble_black_rain_theorem",
    "ingredients": [
      "absent_atlas",
      "amber_heart_pendant",
      "hollow_bookmark"
    ],
    "result": "black_rain_theorem"
  },
  {
    "id": "assemble_orchid_eclipse",
    "ingredients": [
      "foxglove_formula",
      "mercy_needlecase",
      "viper_s_proposition"
    ],
    "result": "orchid_eclipse"
  }
]
const PAIR_RECIPES: Array[Dictionary] = [
  {
    "id": "assemble_hooked_falchion",
    "ingredients": [
      "marching_pike",
      "rusty_knife"
    ],
    "result": "hooked_falchion"
  },
  {
    "id": "assemble_boiler_hammer",
    "ingredients": [
      "drummer_s_mallet",
      "salt_lantern"
    ],
    "result": "boiler_hammer"
  },
  {
    "id": "assemble_standard_spike",
    "ingredients": [
      "drummer_s_mallet",
      "marching_pike"
    ],
    "result": "standard_spike"
  },
  {
    "id": "assemble_vanguard_sabaton",
    "ingredients": [
      "barricade_board",
      "cobbler_s_boots"
    ],
    "result": "vanguard_sabaton"
  },
  {
    "id": "assemble_duelist_s_coin",
    "ingredients": [
      "hedgehog_charm",
      "rivet_knuckle"
    ],
    "result": "duelist_s_coin"
  },
  {
    "id": "assemble_hornback_bow",
    "ingredients": [
      "rusty_knife",
      "willow_slingbow"
    ],
    "result": "hornback_bow"
  },
  {
    "id": "assemble_barbed_tip_roll",
    "ingredients": [
      "rusty_knife",
      "tin_arrow_cup"
    ],
    "result": "barbed_tip_roll"
  },
  {
    "id": "assemble_waxed_fletching",
    "ingredients": [
      "bandage",
      "feather_keeper"
    ],
    "result": "waxed_fletching"
  },
  {
    "id": "assemble_adder_sheath",
    "ingredients": [
      "antidote",
      "briar_snare"
    ],
    "result": "adder_sheath"
  },
  {
    "id": "assemble_pathfinder_gaiters",
    "ingredients": [
      "cobbler_s_boots",
      "feather_keeper"
    ],
    "result": "pathfinder_gaiters"
  },
  {
    "id": "assemble_kiln_prayer",
    "ingredients": [
      "coal_letter",
      "salt_lantern"
    ],
    "result": "kiln_prayer"
  },
  {
    "id": "assemble_icicle_rosary",
    "ingredients": [
      "bandage",
      "rime_thimble"
    ],
    "result": "icicle_rosary"
  },
  {
    "id": "assemble_copper_cicada",
    "ingredients": [
      "static_fork",
      "tin_beetle"
    ],
    "result": "copper_cicada"
  },
  {
    "id": "assemble_hollow_bookmark",
    "ingredients": [
      "salt_lantern",
      "traveler_s_kettle"
    ],
    "result": "hollow_bookmark"
  },
  {
    "id": "assemble_foxglove_formula",
    "ingredients": [
      "antidote",
      "spore_testament"
    ],
    "result": "foxglove_formula"
  },
  {
    "id": "assemble_mothweave_mantle",
    "ingredients": [
      "patchwork_jack",
      "salt_lantern"
    ],
    "result": "mothweave_mantle"
  },
  {
    "id": "assemble_ironroot_boots",
    "ingredients": [
      "cobbler_s_boots",
      "cracked_shield"
    ],
    "result": "ironroot_boots"
  },
  {
    "id": "assemble_pearl_of_brine",
    "ingredients": [
      "acorn_pendant",
      "antidote"
    ],
    "result": "pearl_of_brine"
  },
  {
    "id": "assemble_lantern_moth_familiar",
    "ingredients": [
      "salt_lantern",
      "tin_beetle"
    ],
    "result": "lantern_moth_familiar"
  },
  {
    "id": "assemble_marrow_sparrow",
    "ingredients": [
      "rusty_knife",
      "tin_beetle"
    ],
    "result": "marrow_sparrow"
  },
  {
    "id": "assemble_raincatch_bowl",
    "ingredients": [
      "bandage",
      "traveler_s_kettle"
    ],
    "result": "raincatch_bowl"
  },
  {
    "id": "assemble_roseglass_brooch",
    "ingredients": [
      "acorn_pendant",
      "bandage"
    ],
    "result": "roseglass_brooch"
  },
  {
    "id": "assemble_thorn_whetstone",
    "ingredients": [
      "hedgehog_charm",
      "rusty_knife"
    ],
    "result": "thorn_whetstone"
  },
  {
    "id": "assemble_wax_ear_trumpet",
    "ingredients": [
      "chalk_poultice",
      "salt_lantern"
    ],
    "result": "wax_ear_trumpet"
  },
  {
    "id": "assemble_anchor_cleaver",
    "ingredients": [
      "hooked_falchion",
      "iron_charm"
    ],
    "result": "anchor_cleaver"
  },
  {
    "id": "assemble_oathbreaker_flail",
    "ingredients": [
      "longsword",
      "standard_spike"
    ],
    "result": "oathbreaker_flail"
  },
  {
    "id": "assemble_redoubt_cuirass",
    "ingredients": [
      "barricade_board",
      "ironroot_boots"
    ],
    "result": "redoubt_cuirass"
  },
  {
    "id": "assemble_cadence_spurs",
    "ingredients": [
      "duelist_s_coin",
      "vanguard_sabaton"
    ],
    "result": "cadence_spurs"
  },
  {
    "id": "assemble_captain_s_baton",
    "ingredients": [
      "duelist_s_coin",
      "standard_spike"
    ],
    "result": "captain_s_baton"
  },
  {
    "id": "assemble_glass_reed_bow",
    "ingredients": [
      "hornback_bow",
      "waxed_fletching"
    ],
    "result": "glass_reed_bow"
  },
  {
    "id": "assemble_cinder_nock_rack",
    "ingredients": [
      "barbed_tip_roll",
      "lantern_moth_familiar"
    ],
    "result": "cinder_nock_rack"
  },
  {
    "id": "assemble_winterflight_rack",
    "ingredients": [
      "pearl_of_brine",
      "waxed_fletching"
    ],
    "result": "winterflight_rack"
  },
  {
    "id": "assemble_hunter_s_compass",
    "ingredients": [
      "barbed_tip_roll",
      "raincatch_bowl"
    ],
    "result": "hunter_s_compass"
  },
  {
    "id": "assemble_burrow_falcon",
    "ingredients": [
      "marrow_sparrow",
      "waxed_fletching"
    ],
    "result": "burrow_falcon"
  },
  {
    "id": "assemble_salamander_contract",
    "ingredients": [
      "kiln_prayer",
      "lantern_moth_familiar"
    ],
    "result": "salamander_contract"
  },
  {
    "id": "assemble_glacier_diagram",
    "ingredients": [
      "icicle_rosary",
      "pearl_of_brine"
    ],
    "result": "glacier_diagram"
  }
]
const RECIPES: Array[Dictionary] = LARGE_RECIPES + PAIR_RECIPES
