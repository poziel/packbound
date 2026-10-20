extends "res://tests/support/test_case.gd"
const DISCOVERY = preload("res://systems/content/collectible_discovery.gd")
const CATALOG = preload("res://systems/content/collectible_catalog_definition.gd")
const FIXTURES = "res://tests/fixtures/content/discovery/"

func _run() -> void:
	var catalog: Resource = CATALOG.new()
	var errors: PackedStringArray = catalog.refresh_from_folders()
	check_equal(errors, PackedStringArray(), "Production content discovers and validates")
	var count: int = DISCOVERY.paths("res://assets/items", "item.tres").size() + DISCOVERY.paths("res://assets/relics", "relic.tres").size()
	check_equal(catalog.collectibles.size(), count, "Every canonical primary resource registered")
	check_equal(count, 208, "Complete current roster including special quiver entries")
	var ability_filename := RegEx.new()
	ability_filename.compile("^[a-z][a-z0-9_]*_ability\\.tres$")
	var effect_filename := RegEx.new()
	effect_filename.compile("^[a-z][a-z0-9_]*_effect\\.tres$")
	var ids: PackedStringArray = []
	for value: CollectibleDefinition in catalog.collectibles:
		ids.append(str(value.id))
		check_equal(value.resource_name, value.display_name, "Inspector label is the actual collectible name")
		check(value.resource_path.get_file() in ["item.tres", "relic.tres"], "Canonical primary filename")
		for ability: AbilityDefinition in value.abilities:
			check(ability_filename.search(ability.resource_path.get_file()) != null, "Descriptive ability filename: " + ability.resource_path)
			check(not ability.resource_name.is_empty(), "Ability has a readable label")
			for effect: EffectDefinition in ability.effects:
				var filename: String = effect.resource_path.get_file()
				var descriptive: bool = effect_filename.search(filename) != null
				if effect is ApplyStatusEffectDefinition and effect.status != null:
					descriptive = descriptive or filename == "apply_%s.tres" % effect.status.id
				if effect is GrantCombatStatEffectDefinition:
					descriptive = descriptive or filename == "grant_stat.tres"
				check(descriptive, "Descriptive effect filename: " + effect.resource_path)
				check(not effect.resource_name.is_empty(), "Effect has a readable label")
	check_equal(catalog.refresh_from_folders(), PackedStringArray(), "Refresh is repeatable")
	var repeated: PackedStringArray = []
	for value: CollectibleDefinition in catalog.collectibles:
		repeated.append(str(value.id))
	check_equal(repeated, ids, "Ordering is deterministic")
	var item := ItemDefinition.new()
	item.display_name = "Renamed Sword"
	check_equal(item.resource_name, "Renamed Sword", "Inspector label follows authored name")
	check_equal(DISCOVERY.paths(FIXTURES + "valid/items", "item.tres").size(), 1, "Nested canonical file found; unrelated Resources ignored")
	errors = catalog.refresh_from_folders(FIXTURES + "valid/items", FIXTURES + "valid/relics", FIXTURES + "valid/categories")
	check_equal(errors, PackedStringArray(), "New folder content discovers without a maintained list")
	check_equal(catalog.collectibles.size(), 2, "Only fixture collectibles registered")
	var before: Array = catalog.collectibles.duplicate()
	errors = catalog.refresh_from_folders(FIXTURES + "duplicates", FIXTURES + "valid/relics", FIXTURES + "valid/categories")
	check(not errors.is_empty() and "; ".join(errors).contains("duplicates"), "Duplicate IDs rejected")
	check_equal(catalog.collectibles, before, "Duplicate discovery leaves previous valid catalog intact")
	errors = catalog.refresh_from_folders(FIXTURES + "wrong_type", FIXTURES + "valid/relics", FIXTURES + "valid/categories")
	check(not errors.is_empty() and "; ".join(errors).contains("wrong Resource type"), "Wrong canonical Resource type rejected")
	check_equal(catalog.collectibles, before, "Wrong-type discovery leaves previous valid catalog intact")
	var snapshot: Resource = load("res://assets/collectibles.tres")
	check_equal(snapshot.validation_errors(), PackedStringArray(), "Generated Inspector snapshot remains valid")
	check_equal(snapshot.collectibles.size(), count, "Snapshot matches discovery")
	check_equal(preload("res://systems/content/collectible_categories.gd").definition_for_key("boiler_hammer").display_name, "Boiler Hammer", "Runtime registry exposes discovered definitions")
	report("COLLECTIBLE DISCOVERY")
	quit(1 if failures else 0)
