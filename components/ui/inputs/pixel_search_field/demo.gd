extends Control
## All layout and rows are saved in the scene; only counts are wired here.

func _ready() -> void:
	for list_name: String in ["Statistics", "Items"]:
		var content: Control = get_node("Margin/Layout/Lists/" + list_name + "/Inset/Content")
		var search: PixelSearchField = content.get_node("Search")
		var count: Label = content.get_node("Heading/Count")
		search.results_filtered.connect(func(visible_count: int, total: int) -> void:
			count.text = "%d / %d" % [visible_count, total])
		search.refresh_filter()
	$Margin/Layout/Lists/Statistics/Inset/Content/Search.grab_focus()
