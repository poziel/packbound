extends PanelContainer

var class_key: String = ""
@onready var title: Label = $Margin/Content/CharacterName
@onready var stats: RichTextLabel = $Margin/Content/Stats
@onready var ability: RichTextLabel = $Margin/Content/Ability
@onready var description: RichTextLabel = $Margin/Content/Description
@onready var items: VBoxContainer = $Margin/Content/Items

func _ready() -> void:
	# Keep the native panel compact when wrapping changes, including while hidden.
	minimum_size_changed.connect(reset_size)

func show_character(key: String) -> void:
	class_key = key
	var character: Dictionary = PackCatalog.classes()[key]
	# A separate seeded run reports actual starting values without affecting play.
	var starting: PackRun = PackRun.new()
	starting.reset(0, key)
	title.text = character["name"]
	var stats_text: String = "%d HP  /  %d mana" % [starting.max_hp, starting.starting_resources()["mana"]]
	if starting.undead_companions > 0:
		stats_text += "  /  %d thrall" % starting.undead_companions
	stats.text = PackKeywordLinks.rich(stats_text, "", false)
	ability.text = PackKeywordLinks.rich(character["mechanic"], "", false)
	description.text = PackKeywordLinks.rich(character["detail"], "", false)
	for index in range(items.get_child_count()):
		var row: HBoxContainer = items.get_child(index)
		row.visible = index < character["starters"].size()
		if row.visible:
			var item_key: String = character["starters"][index]
			row.get_node("Icon").texture = PackArt.item(item_key)
			row.get_node("Name").text = PackCatalog.item(item_key)["name"]
	reset_size()
	show()
