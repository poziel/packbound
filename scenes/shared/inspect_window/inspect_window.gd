class_name PackInspectWindow
extends PanelContainer

signal keyword_link_entered(key: String)
signal keyword_link_exited
signal keyword_link_pressed(key: String)
signal item_recipe_requested(key: String)
const RECIPE_PREVIEW = preload("res://scenes/shared/inspect_window/recipe_preview.gd")
var recipe_view: VBoxContainer
var recipe_scroll: ScrollContainer

@export var lock_drop: float = 4.0
@export var lock_duration: float = 0.12
var locked: bool = false
var age: float = 0.0
var away_age: float = 0.0
var entered: bool = false
var dismiss_requested: bool = false
var trigger_id: String = ""
var trigger_bounds: Rect2
var key: String = ""
var bonus_definitions: Dictionary = {}
var _placed: bool = false
var _lock_animated: bool = false
var _lock_tween: Tween
var _rich_text: String = ""
var _hovered_keyword: String = ""
var _hover_generation: int = 0
var _updating_hover: bool = false
var _hover_occurrence: String = ""
var _link_keys: Dictionary = {}
var _link_images: Dictionary = {}
var _trigger_controls: Dictionary = {}
var _hover_effect = preload("res://systems/ui/keywords/keyword_hover_effect.gd").new()
@onready var body: RichTextLabel = $Content/Body
@onready var timer: Control = $Content/Header/TimerSlot/Timer
@onready var bound_status: Control = $Content/Header/BoundStatus
@onready var recipe_shortcut: TextureRect = $Content/Header/TimerSlot/RecipeShortcut
var recipe_link: String = ""
var element_icon: TextureRect
var item_element: String = ""

func _ready() -> void:
	element_icon = TextureRect.new()
	element_icon.name = "Element"
	element_icon.custom_minimum_size = Vector2(24, 24)
	element_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	element_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	element_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	element_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	$Content/Header.add_child(element_icon)
	$Content/Header.move_child(element_icon, $Content/Header/Title.get_index())
	element_icon.mouse_entered.connect(func() -> void: _control_link_entered(item_element, element_icon))
	element_icon.mouse_exited.connect(func() -> void: _on_keyword_link_exited(item_element))
	body.install_effect(_hover_effect)
	body.resized.connect(_invalidate_keyword_geometry)
	body.theme_changed.connect(_invalidate_keyword_geometry)
	body.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _invalidate_keyword_geometry())
	focus_mode = Control.FOCUS_NONE
	body.focus_mode = Control.FOCUS_NONE
	$Content/Header/Title.focus_mode = Control.FOCUS_NONE
	recipe_shortcut.mouse_entered.connect(func() -> void: _control_link_entered(recipe_link, recipe_shortcut))
	recipe_shortcut.mouse_exited.connect(func() -> void: _on_keyword_link_exited(recipe_link))
	bound_status.mouse_entered.connect(func() -> void: _control_link_entered("backpack_locked", bound_status))
	bound_status.mouse_exited.connect(func() -> void: _on_keyword_link_exited("backpack_locked"))
	bound_status.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			keyword_link_pressed.emit("backpack_locked")
	)

func setup(data: Dictionary) -> void:
	_trigger_controls.clear()
	_invalidate_keyword_geometry()
	age = 0.0
	away_age = 0.0
	entered = false
	dismiss_requested = false
	_hovered_keyword = ""
	_hover_generation += 1
	key = data.get("key", "")
	item_element = str(GameplayTypes.element_id(data.get("element", GameplayTypes.Element.NONE)))
	if item_element.is_empty() and data.has("recipe_item"):
		item_element = str(GameplayTypes.element_id(PackCatalog.item(data["recipe_item"]).get("element", GameplayTypes.Element.NONE)))
	element_icon.texture = PackKeywords.icon(item_element)
	element_icon.modulate = PackKeywords.color(item_element)
	element_icon.visible = not item_element.is_empty() and element_icon.texture != null
	element_icon.accessibility_name = item_element.capitalize() + " element"
	var title_text: String = data.get("title", "")
	var is_keyword_definition: bool = not PackKeywordLinks.entry(key).is_empty()
	# Only keyword definition headings describe mechanics; item and relic titles keep their identity.
	$Content/Header/Title.text = PackKeywordLinks.rich(title_text, "", false) if is_keyword_definition else title_text
	$Content/Header/Icon.texture = data.get("icon")
	$Content/Header/Icon.visible = data.has("icon") and not is_keyword_definition
	bound_status.visible = bool(data.get("bound", false))
	_rich_text = PackKeywordLinks.rich(data.get("body", ""), key)
	var rarity: Variant = data.get("rarity")
	var has_rarity: bool = rarity is int and GameplayTypes.Rarity.values().has(rarity)
	if has_rarity:
		$Content/Header/Title.add_theme_color_override("default_color", PackCatalog.RARITY.color({"rarity": rarity}))
	else:
		$Content/Header/Title.remove_theme_color_override("default_color")
	var keyword_stats: String = PackKeywords.stats_markup(data.get("keyword_stats", []), true, body.get_theme_color("default_color"))
	if not keyword_stats.is_empty():
		_rich_text = keyword_stats + ("\n\n" + _rich_text if not _rich_text.is_empty() else "")
	var keyword_list: String = PackKeywords.list_markup(data.get("keyword_list", []), true, body.get_theme_color("default_color"))
	if not keyword_list.is_empty():
		_rich_text = keyword_list + ("\n\n" + _rich_text if not _rich_text.is_empty() else "")
	var footer: String = PackKeywords.item_footer_markup(data.get("resource_costs", []), data.get("priority_label", ""))
	bonus_definitions.clear()
	bonus_definitions.merge(data.get("definitions", {}))
	recipe_link = ""
	if data.has("recipe_item"):
		var recipe_data: Dictionary = PackRun.CRAFTING.recipe_inspection(null, PackCatalog.item(data["recipe_item"]))
		if not recipe_data.is_empty():
			recipe_link = recipe_data["key"]
			bonus_definitions[recipe_link] = recipe_data
	if is_instance_valid(recipe_view):
		recipe_scroll.get_parent().remove_child(recipe_scroll)
		recipe_scroll.queue_free()
		recipe_view = null
		recipe_scroll = null
	if not data.get("recipes", []).is_empty():
		recipe_scroll = ScrollContainer.new()
		recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		recipe_scroll.focus_mode = Control.FOCUS_NONE
		$Content.add_child(recipe_scroll)
		$Content.move_child(recipe_scroll, 1)
		recipe_view = RECIPE_PREVIEW.new()
		recipe_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_scroll.add_child(recipe_view)
		recipe_view.setup(data["recipes"])
		recipe_scroll.custom_minimum_size = Vector2(368, 64)
		recipe_view.minimum_size_changed.connect(_resize_recipe_scroll)
		_resize_recipe_scroll.call_deferred()
		recipe_scroll.get_h_scroll_bar().focus_mode = Control.FOCUS_NONE
		recipe_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
		recipe_view.item_entered.connect(func(item_key: String, trigger: Control) -> void: _control_link_entered("recipe_item_" + item_key, trigger))
		recipe_view.item_exited.connect(func() -> void: _on_keyword_link_exited(""))
		recipe_view.item_pressed.connect(func(item_key: String, recipes: bool) -> void:
			if recipes:
				item_recipe_requested.emit(item_key)
			else:
				keyword_link_pressed.emit("recipe_item_" + item_key))
	var bonus_lines: PackedStringArray = []
	for bonus: Dictionary in data.get("bonuses", []):
		var bonus_key: String = str(bonus["key"])
		bonus_definitions.merge(bonus.get("definitions", {}))
		if bool(bonus.get("tooltip", not str(bonus.get("body", "")).is_empty())):
			bonus_definitions[bonus_key] = bonus
			bonus_lines.append("• [url href=%s underline=never][u]%s[/u][/url]" % [bonus_key, PackKeywordLinks.rich(str(bonus["label"]), "", false)])
		else:
			bonus_lines.append("• " + str(bonus.get("markup", PackKeywordLinks.rich(str(bonus["label"])))))
	if not bonus_lines.is_empty():
		_rich_text += ("\n\n" if not _rich_text.is_empty() else "") + str(data.get("bonus_heading", "Bonuses")) + "\n" + "\n".join(bonus_lines)
	var restriction: String = preload("res://systems/content/content_restrictions.gd").markup(data.get("restriction_content", {}))
	if not restriction.is_empty():
		footer += ("\n" if not footer.is_empty() else "") + restriction
	if not footer.is_empty():
		_rich_text += ("\n\n" if not _rich_text.is_empty() else "") + footer
	if has_rarity:
		_rich_text = PackCatalog.RARITY.markup({"rarity": rarity}) + ("\n\n" + _rich_text if not _rich_text.is_empty() else "")
	_link_keys.clear()
	_link_images.clear()
	_hover_occurrence = ""
	_hover_effect.hovered = ""
	var urls := RegEx.new()
	urls.compile("(?s)(\\[url(?:=| href=)([^ \\]]+)[^\\]]*\\])(.*?)(\\[/url\\])")
	var matches: Array[RegExMatch] = urls.search_all(_rich_text)
	matches.reverse()
	for found in matches:
		var occurrence: String = "keyword_%d" % found.get_start()
		_link_keys[occurrence] = found.get_string(2)
		var opening: String = found.get_string(1).replace(found.get_string(2), occurrence)
		var contents: String = found.get_string(3)
		var images := RegEx.new()
		images.compile("\\[img([^\\]]*)\\]")
		var image_matches: Array[RegExMatch] = images.search_all(contents)
		image_matches.reverse()
		for image_tag in image_matches:
			var image_key: String = occurrence + "_image_%d" % image_tag.get_start()
			var tint := RegEx.new()
			tint.compile("color=(#[0-9A-Fa-f]{6,8})")
			var color_match: RegExMatch = tint.search(image_tag.get_string(1))
			_link_images[image_key] = {"occurrence": occurrence, "color": Color(color_match.get_string(1)) if color_match else Color.WHITE}
			contents = contents.left(image_tag.get_start()) + "[img key=%s%s]" % [image_key, image_tag.get_string(1)] + contents.substr(image_tag.get_end())
		var leading_image := RegEx.new()
		leading_image.compile("^(?:\\[color[^\\]]*\\])*\\[img")
		var leading: int = 16 if leading_image.search(contents) else 0
		var markup: String = opening + "[keyword_hover id=%s leading=%d]%s[/keyword_hover]" % [occurrence, leading, contents] + found.get_string(4)
		_rich_text = _rich_text.left(found.get_start()) + markup + _rich_text.substr(found.get_end())
	# BBCode images have no update key in Godot. Insert keyed images through the
	# native API once, so later tint updates cannot invalidate link hit testing.
	body.clear()
	var image_tags := RegEx.new()
	image_tags.compile("\\[img key=([^ ]+)([^\\]]*)\\](.*?)\\[/img\\]")
	var cursor: int = 0
	for image_tag in image_tags.search_all(_rich_text):
		body.append_text(_rich_text.substr(cursor, image_tag.get_start() - cursor))
		var image_key: String = image_tag.get_string(1)
		body.add_image(load(image_tag.get_string(3)), 16, 16, _link_images[image_key]["color"], INLINE_ALIGNMENT_CENTER, Rect2(), image_key)
		cursor = image_tag.get_end()
	body.append_text(_rich_text.substr(cursor))
	body.visible = not _rich_text.is_empty()
	if not body.meta_hover_started.is_connected(_on_keyword_link_entered):
		body.meta_hover_started.connect(_on_keyword_link_entered)
		body.meta_hover_ended.connect(_on_keyword_link_exited)
		body.meta_clicked.connect(_on_keyword_link_pressed)
	set_locked(false)
	_disable_focus()

func _disable_focus() -> void:
	focus_mode = Control.FOCUS_NONE
	# RichTextLabel and ScrollContainer own native scrollbar controls too.
	for child: Control in find_children("*", "Control", true, false):
		child.focus_mode = Control.FOCUS_NONE

func _resize_recipe_scroll() -> void:
	if is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(recipe_view):
		var available: float = maxf(64, get_viewport_rect().size.y - 260)
		var content: Vector2 = recipe_view.get_combined_minimum_size()
		recipe_scroll.custom_minimum_size.x = clampf(content.x, 368, minf(720, maxf(368, get_viewport_rect().size.x - 56)))
		recipe_scroll.custom_minimum_size.y = minf(available, content.y + (18 if content.x > recipe_scroll.custom_minimum_size.x else 0))

func _on_keyword_link_entered(meta: Variant) -> void:
	if _updating_hover:
		return
	_hover_generation += 1
	_hover_occurrence = str(meta)
	var canonical: String = str(_link_keys.get(str(meta), str(meta)))
	if _hovered_keyword != canonical or _hover_effect.hovered != _hover_occurrence:
		_hovered_keyword = canonical
		_refresh_keyword_appearance()
	keyword_link_entered.emit(canonical)

func _invalidate_keyword_geometry() -> void:
	_hover_effect.font_size = body.get_theme_font_size("normal_font_size")
	_hover_effect.invalidate_geometry()
	body.queue_redraw()

func _control_link_entered(key_text: String, trigger: Control) -> void:
	var occurrence: String = "%s@%d" % [key_text, trigger.get_instance_id()]
	_link_keys[occurrence] = key_text
	_trigger_controls[occurrence] = trigger
	_on_keyword_link_entered(occurrence)

func trigger_rect(global_point: Vector2, occurrence: String = "") -> Rect2:
	var id: String = _hover_occurrence if occurrence.is_empty() else occurrence
	var control: Control = _trigger_controls.get(id)
	if is_instance_valid(control):
		var rect: Rect2 = control.get_global_rect()
		if is_instance_valid(recipe_view) and recipe_view.is_ancestor_of(control):
			rect = rect.intersection(recipe_scroll.get_global_rect())
		return rect
	var nearest: Rect2
	var distance: float = INF
	for local_rect: Rect2 in _hover_effect.trigger_fragments(id):
		var rect: Rect2 = body.get_global_transform_with_canvas() * local_rect
		var next_distance: float = absf(rect.get_center().y - global_point.y)
		if next_distance < distance:
			nearest = rect
			distance = next_distance
	return nearest

func fit_within(maximum: Vector2) -> void:
	# Preserve the header; scroll large text/recipe contents inside the available
	# region rather than clamping the tooltip over its trigger.
	custom_minimum_size.x = minf(400, maximum.x)
	body.custom_minimum_size.x = minf(368, maxf(1, maximum.x - 32))
	if is_instance_valid(recipe_scroll):
		recipe_scroll.custom_minimum_size.x = minf(recipe_scroll.custom_minimum_size.x, maxf(1, maximum.x - 32))
		var excess: float = get_combined_minimum_size().y - maximum.y
		if excess > 0:
			recipe_scroll.custom_minimum_size.y = maxf(32, recipe_scroll.custom_minimum_size.y - excess)
	if body.visible and get_combined_minimum_size().y > maximum.y:
		var overhead: float = get_combined_minimum_size().y - body.get_combined_minimum_size().y
		body.fit_content = false
		body.scroll_active = true
		body.custom_minimum_size.y = maxf(24, maximum.y - overhead)
	size = Vector2(minf(maximum.x, get_combined_minimum_size().x), minf(maximum.y, get_combined_minimum_size().y))

func _on_keyword_link_exited(_meta: Variant) -> void:
	if not _updating_hover:
		_finish_keyword_hover.call_deferred(_hover_generation)

func _finish_keyword_hover(generation: int) -> void:
	if generation != _hover_generation:
		return
	_hovered_keyword = ""
	_hover_occurrence = ""
	_refresh_keyword_appearance()
	keyword_link_exited.emit()

func _refresh_keyword_appearance() -> void:
	# Reentrant meta-exit events from recoloring must not dismiss nested inspection.
	_updating_hover = true
	var bound_selected: bool = _hovered_keyword == "backpack_locked"
	bound_status.modulate = Color(0.72, 0.72, 0.72) if bound_selected else Color.WHITE
	element_icon.modulate = PackKeywords.color(item_element).darkened(0.28) if _hovered_keyword == item_element else PackKeywords.color(item_element)
	recipe_shortcut.modulate = get_theme_color("icon_normal_color", "IconButton") * (Color(0.72, 0.72, 0.72) if _hovered_keyword == recipe_link else Color.WHITE)
	_hover_effect.hovered = _hover_occurrence
	for image_key: String in _link_images:
		var image: Dictionary = _link_images[image_key]
		var tint: Color = image["color"]
		body.update_image(image_key, RichTextLabel.UPDATE_COLOR, null, 0, 0, tint.darkened(0.28) if image["occurrence"] == _hover_occurrence else tint)
	body.queue_redraw()
	_updating_hover = false

func _on_keyword_link_pressed(meta: Variant) -> void:
	keyword_link_pressed.emit(str(_link_keys.get(str(meta), str(meta))))

func set_locked(value: bool) -> void:
	locked = value
	mouse_filter = Control.MOUSE_FILTER_STOP if locked else Control.MOUSE_FILTER_IGNORE
	body.mouse_filter = mouse_filter
	body.focus_mode = Control.FOCUS_NONE
	bound_status.mouse_filter = mouse_filter
	if is_instance_valid(recipe_view):
		recipe_view.set_interactive(value)
		recipe_scroll.mouse_filter = mouse_filter
	# The slot stays in the header, so hiding the ring never reflows the title.
	timer.visible = not locked
	recipe_shortcut.visible = locked and not recipe_link.is_empty()
	recipe_shortcut.mouse_filter = Control.MOUSE_FILTER_STOP if recipe_shortcut.visible else Control.MOUSE_FILTER_IGNORE
	recipe_shortcut.modulate = get_theme_color("icon_normal_color", "IconButton")
	if locked:
		_animate_lock()
	else:
		timer.progress = 0.0

func place_at(at: Vector2) -> void:
	if is_instance_valid(_lock_tween) and _lock_tween.is_running():
		_lock_tween.kill()
	position = at
	_placed = true
	if locked:
		_animate_lock()

func _animate_lock() -> void:
	if not _placed or _lock_animated:
		return
	_lock_animated = true
	_lock_tween = create_tween()
	_lock_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(self, "position:y", position.y + lock_drop, lock_duration)

func progress(ratio: float) -> void:
	timer.progress = ratio
	if ratio >= 1.0:
		set_locked(true)
