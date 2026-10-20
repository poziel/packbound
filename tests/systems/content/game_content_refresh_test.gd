extends "res://tests/support/test_case.gd"
const CONTENT = preload("res://systems/content/game_content_definition.gd")

func _run() -> void:
	var content: Resource = ResourceLoader.load("res://assets/game_content.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(content != null, "Game content loads")
	if content == null:
		report("GAME CONTENT REFRESH")
		quit(1)
		return
	var before_recipes: PackedStringArray = []
	for recipe: RecipeDefinition in content.recipes:
		before_recipes.append(str(recipe.id))
	var original_collectibles: Resource = content.collectibles
	check_equal(content.refresh_from_folders(), PackedStringArray(), "All content folders discover and validate")
	check_equal(content.collectibles, original_collectibles, "Shared external collectible catalog reference survives refresh")
	check_equal(content.collectibles.collectibles.size(), 208, "All collectibles discovered")
	check_equal(content.character_classes.size(), 5, "All classes discovered")
	check_equal(content.characters.size(), 5, "All characters discovered")
	check_equal(content.monsters.size(), 56, "All monsters discovered")
	check_equal(content.recipes.size(), 83, "All recipes discovered")
	check_equal(content.status_effects.size(), 5, "All existing statuses discovered")
	check_equal(content.loot_pools.size(), 10, "All reward pools discovered")
	check_equal(content.loot_progressions.size(), 8, "All reward progressions discovered")
	var after_recipes: PackedStringArray = []
	for recipe: RecipeDefinition in content.recipes:
		after_recipes.append(str(recipe.id))
	check_equal(after_recipes, before_recipes, "Authored recipe priority survives discovery")
	for character: CharacterDefinition in content.characters:
		check(character is CombatantDefinition, "Characters implement the shared combatant contract")
	for monster: MonsterDefinition in content.monsters:
		check(monster is CombatantDefinition, "Monsters implement the shared combatant contract")
	check(content.refresh_content.is_valid(), "Inspector refresh action is callable")
	content.refresh_content.call()
	check_equal(content.validation_errors(), PackedStringArray(), "Inspector button rebuilds valid content")
	var before_statuses: Array = content.status_effects.duplicate()
	var before_pools: Array = content.loot_pools.duplicate()
	var before_progressions: Array = content.loot_progressions.duplicate()
	var before_characters: Array = content.characters.duplicate()
	var before_monsters: Array = content.monsters.duplicate()
	var before_collectibles: Array = content.collectibles.collectibles.duplicate()
	var errors: PackedStringArray = content.refresh_from_folders("res://tests/fixtures/content/discovery/valid")
	check(not errors.is_empty(), "Incomplete game content is rejected")
	check_equal(content.status_effects, before_statuses, "Failure preserves status registrations")
	check_equal(content.loot_pools, before_pools, "Failure preserves loot pools")
	check_equal(content.loot_progressions, before_progressions, "Failure preserves loot progressions")
	check_equal(content.characters, before_characters, "Failure preserves characters")
	check_equal(content.monsters, before_monsters, "Failure preserves monsters")
	check_equal(content.collectibles.collectibles, before_collectibles, "Failure preserves shared collectible entries")
	check_equal(content.collectibles, original_collectibles, "Failure preserves shared catalog identity")
	var path: String = artifact_path("game_content.tres")
	check_equal(ResourceSaver.save(content, path), OK, "Refreshed graph saves")
	var restored: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(restored != null, "Refreshed graph reloads")
	if restored != null:
		check_equal(restored.validation_errors(), PackedStringArray(), "Reloaded graph validates")
		check_equal(restored.collectibles.resource_path, "res://assets/collectibles.tres", "Saved graph keeps external catalog path")
	report("GAME CONTENT REFRESH")
	quit(1 if failures else 0)
