extends VBoxContainer
## Each recipe reads left to right; pairs of short ingredients share a column.
signal item_entered(key: String, trigger: Control)
signal item_exited
signal item_pressed(key: String, recipes: bool)
const ITEM = preload("res://scenes/shared/inspect_window/recipe_item.gd")
const ART = preload("res://systems/items/item_art_renderer.gd")
const CARET = preload("res://assets/ui/icons/adjacency-carets-v3/edge-inward.png")
var items: Array[Control] = []

func setup(recipes: Array) -> void:
	add_theme_constant_override("separation", 20)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for recipe: Dictionary in recipes:
		var group := HBoxContainer.new()
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_theme_constant_override("separation", 12)
		add_child(group)
		var ingredients: Array = recipe["ingredients"]
		var index: int = 0
		while index < ingredients.size():
			if index + 1 < ingredients.size() and ingredients[index]["shape"].y == 1 and ingredients[index + 1]["shape"].y == 1:
				var stack := VBoxContainer.new()
				stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
				stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				stack.add_theme_constant_override("separation", 8)
				group.add_child(stack)
				_add_item(stack, ingredients[index])
				_add_item(stack, ingredients[index + 1])
				index += 2
			else:
				_add_item(group, ingredients[index])
				index += 1
		var caret := TextureRect.new()
		caret.texture = CARET
		caret.custom_minimum_size = Vector2(14, 14)
		caret.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		caret.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		caret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		caret.modulate = get_theme_color("icon_normal_color", "IconButton")
		caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(caret)
		_add_item(group, recipe["output"])
	set_interactive(false)

func _add_item(parent: Control, item: Dictionary) -> void:
	var art: Control = ITEM.new()
	art.setup(item)
	art.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(art)
	items.append(art)
	art.mouse_entered.connect(func() -> void: item_entered.emit(str(item["key"]), art))
	art.mouse_exited.connect(func() -> void: item_exited.emit())
	art.inspected.connect(func(key: String, recipes: bool) -> void: item_pressed.emit(key, recipes))

func set_interactive(value: bool) -> void:
	for art in items:
		art.set_interactive(value)
