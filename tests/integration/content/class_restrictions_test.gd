extends "res://tests/support/test_case.gd"


func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func _run() -> void:
	var warrior := PackRun.new()
	warrior.reset(42, "warrior")
	var mage := PackRun.new()
	mage.reset(42, "mage")
	check(warrior.item_enabled({"characters": ["warrior"]}), "Character restriction accepts selected character")
	check(not mage.item_enabled({"characters": ["warrior"]}), "Character restriction rejects other characters")
	check(not mage.item_enabled(PackCatalog.item("boiler_hammer")), "Boiler Hammer rejects mage")
	var saves := PackRunSaves.new()
	mage.item_rewards.assign([{"floor": 1, "offers": ["boiler_hammer", "bandage"]}])
	mage.offers.assign(["boiler_hammer", "bandage"])
	mage.relic_offers.assign(["ram_flywheel", "tin_cricket"])
	mage.room_relic_offers.assign(["siege_heart"])
	var resumed := PackRun.new()
	saves.restore(resumed, saves.capture(mage, 0))
	check(not resumed.offers.has("boiler_hammer") and resumed.offers.has("bandage"), "Resume replaces only ineligible deferred items")
	check(not resumed.relic_offers.has("ram_flywheel") and resumed.relic_offers.has("tin_cricket"), "Resume replaces only ineligible deferred relics")
	check(not resumed.room_relic_offers.has("siege_heart"), "Resume replaces ineligible room relics")
	check(mage.add_item("boiler_hammer").is_empty(), "Ineligible item cannot be granted")
	check(not PackKeywords.item_description(PackCatalog.item("boiler_hammer")).contains("can equip"), "Restriction removed from descriptive prose")
	check(not mage.available_room_relics().has("ram_flywheel"), "Room relic pool respects classes")
	mage.relic_rewards.assign([1])
	for i in range(100):
		mage.relic_offers.clear()
		mage.roll_relics()
		check(not mage.relic_offers.has("ram_flywheel"), "Deferred relic pool respects classes")
	var window = load("res://scenes/shared/inspect_window/inspect_window.tscn").instantiate()
	root.add_child(window)
	var data: Dictionary = preload("res://systems/items/item_presentation.gd").catalog_inspection("boiler_hammer")
	window.setup(data)
	var markup: String = window._rich_text
	check(markup.contains("Only ") and markup.contains("Warrior"), "Inspector displays short class restriction")
	check(window._link_keys.values().has("restriction_class_warrior"), "Class restriction opens keyword")
	check(markup.find("Only ") > markup.find("stamina"), "Restriction appears beneath resource cost")
	var restrictions = preload("res://systems/content/content_restrictions.gd")
	check(restrictions.markup({"characters": ["warrior"]}, false) == "Only Garran Vale", "Character restriction uses authored display name")
	check(restrictions.markup({}).is_empty(), "Unrestricted content has no footer")
	check(not mage.item_enabled({"classes": ["mage"], "characters": ["warrior"]}), "Both declared restrictions must match")
	window.setup({"key": "character_test", "title": "Character item", "restriction_content": {"characters": ["warrior"]}})
	check(window._link_keys.values().has("restriction_character_warrior"), "Character footer opens character tooltip")
	check(window._rich_text.contains("Garran Vale"), "Character footer displays character name")
	for class_id: String in PackCatalog.classes():
		var run := PackRun.new()
		run.reset(42, class_id)
		run.fight = 19
		for i in range(20):
			run.roll_loot()
			for offered: String in run.item_rewards.back()["offers"]:
				check(run.item_enabled(PackCatalog.item(offered)), "All rolled items match run identity")
		for offered: String in run.available_room_relics():
			check(run.item_enabled(PackCatalog.relic(offered)), "All room relics match run identity")
	check(not PackKeywordLinks.entry("restriction_class_warrior").is_empty(), "Class keyword has explanation")
	var character: Dictionary = PackKeywordLinks.entry("restriction_character_warrior")
	check(character.get("title", "") == "Garran Vale" and not str(character.get("body", "")).is_empty(), "Character keyword uses authored name and biography")
	window.queue_free()
	report("CLASS RESTRICTIONS")
	quit(1 if failures else 0)

