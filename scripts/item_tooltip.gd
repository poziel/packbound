extends VBoxContainer

func _ready() -> void:
	# Inline-image layout settles after text assignment, including hidden rows.
	minimum_size_changed.connect(reset_size)

func set_item(item: Dictionary, adjacency_bonus: int = 0) -> void:
	$Header/Icon.hide()
	$Header/BoundStatus.visible = item.get("key") == PackCatalog.QUIVER.KEY
	$Header/Name.text = preload("res://scripts/item_presentation.gd").display_name(item)
	$Header/Name.add_theme_color_override("font_color", PackCatalog.RARITY.color(item))
	$Rarity.text = PackCatalog.RARITY.label(item)
	$Rarity.add_theme_color_override("font_color", PackCatalog.RARITY.color(item))
	$KeywordList.text = PackKeywords.list_markup(PackKeywords.item_stats(item, adjacency_bonus), false, $KeywordList.get_theme_color("default_color"))
	$KeywordList.visible = not $KeywordList.text.is_empty()
	$Description.text = PackKeywordLinks.rich(PackKeywords.item_description(item), "", false)
	$Description.visible = not $Description.text.is_empty()
	$Bonus.text = PackKeywordLinks.rich("Bonuses\n• +%d from adjacent items" % adjacency_bonus, "", false)
	$Bonus.visible = adjacency_bonus > 0
	var costs: Array[Dictionary] = PackKeywords.item_resource_costs(item)
	$Cost.text = PackKeywords.item_footer_markup(costs, "" if costs.is_empty() else PackKeywords.item_priority_label(item), false)
	$Cost.visible = not $Cost.text.is_empty()
	move_child($Cost, get_child_count() - 1)
	reset_size()
