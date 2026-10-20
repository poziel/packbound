extends VBoxContainer

func _ready() -> void:
	# Inline-image layout settles after text assignment, including hidden rows.
	minimum_size_changed.connect(reset_size)

func set_item(item: Dictionary, adjacency_bonus: int = 0, run = null) -> void:
	var element: String = str(GameplayTypes.element_id(item.get("element", GameplayTypes.Element.NONE)))
	$Header/Icon.texture = PackKeywords.icon(element)
	$Header/Icon.visible = not element.is_empty() and $Header/Icon.texture != null
	$Header/Icon.custom_minimum_size = Vector2(24, 24)
	$Header/Icon.modulate = PackKeywords.color(element)
	$Header/Icon.mouse_filter = Control.MOUSE_FILTER_STOP
	$Header/Icon.tooltip_text = "%s — Element\n%s" % [element.capitalize(), PackKeywordLinks.entry(element).get("body", "")]
	$Header/BoundStatus.visible = item.get("key") == PackCatalog.QUIVER.KEY
	$Header/Name.text = preload("res://systems/items/item_presentation.gd").display_name(item)
	$Header/Name.add_theme_color_override("font_color", PackCatalog.RARITY.color(item))
	$Rarity.text = PackCatalog.RARITY.label(item)
	$Rarity.add_theme_color_override("font_color", PackCatalog.RARITY.color(item))
	var displayed_stats: Array = preload("res://systems/items/item_presentation.gd").item_stats(run, item) if run != null else PackKeywords.item_stats(item, adjacency_bonus)
	$KeywordList.text = PackKeywords.list_markup(displayed_stats, false, $KeywordList.get_theme_color("default_color"))
	$KeywordList.visible = not $KeywordList.text.is_empty()
	$Description.text = PackKeywordLinks.rich(PackKeywords.item_description(item), "", false)
	$Description.visible = not $Description.text.is_empty()
	$Bonus.text = PackKeywordLinks.rich("Bonuses\n• +%d from adjacent items" % adjacency_bonus, "", false)
	$Bonus.visible = adjacency_bonus > 0
	var costs: Array[Dictionary] = PackKeywords.item_resource_costs(item)
	$Cost.text = PackKeywords.item_footer_markup(costs, "" if costs.is_empty() else PackKeywords.item_priority_label(item), false)
	var restriction: String = preload("res://systems/content/content_restrictions.gd").markup(item, false)
	if not restriction.is_empty():
		$Cost.text += ("\n" if not $Cost.text.is_empty() else "") + restriction
	$Cost.visible = not $Cost.text.is_empty()
	move_child($Cost, get_child_count() - 1)
	reset_size()
