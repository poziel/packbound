extends "res://tests/support/test_case.gd"


func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.gd").new()
	var weapon: Dictionary = PackCatalog.item("longsword")
	weapon.merge({"id": 1, "cell": Vector2i.ZERO, "priority": 2}, true)
	game.run.items.assign([weapon])
	var data: Dictionary = game._describe_item(weapon, Rect2())
	check(data["body"] == "" and data.get("priority_label") == "Priority 2", "Priority belongs to the footer rather than a description line")
	check(data.get("resource_costs", []).size() == 2, "Attack inspection exposes a dedicated two-resource cost row")
	for stat: Dictionary in data["keyword_list"]:
		check(stat.get("qualifier", "") != "cost", "Activation costs are absent from ordinary keyword lists")
	weapon["priority"] = 0
	check(game._describe_item(weapon, Rect2()).get("priority_label") == "No priority", "Default footer label stays short")
	game.modal_kind = "reward"
	game.run.offers.assign(["ember_tome"])
	check(game._reward_inspection(0).get("resource_costs", []).size() == 2, "Reward weapon and spell tooltips also include their resource footer")
	var passive_tooltip: Control = load("res://scenes/shared/item_tooltip/item_tooltip.tscn").instantiate()
	root.add_child(passive_tooltip)
	passive_tooltip.set_item(weapon)
	check(passive_tooltip.get_node("Cost").text.contains("[right]No priority") and not passive_tooltip.get_node("Description").text.contains("priority"), "Fallback item tooltips also keep Priority on the right of the cost row")
	passive_tooltip.free()
	var definition: Dictionary = PackKeywordLinks.entry("priority")
	check(definition.get("kind") == "meta", "Priority is a mechanics explanation rather than a combat stat")
	check(PackKeywordLinks.rich("Priority 2").contains("[url"), "Priority label supports nested hover explanation")
	check(definition.get("body", "").contains("increase/decrease priority keybinds") and definition.get("body", "").contains("forward or backward"), "Priority explanation owns configurable forward and backward cycling instructions")
	check(PackKeywords.has_icon("mana") and PackKeywords.has_icon("stamina"), "Both resources have runtime icon bindings")
	check(PackKeywords.item_resource_costs(PackCatalog.item("rusty_knife"))[0]["value"] == 0, "Free attacks explicitly show zero resource cost")
	check(PackKeywords.item_resource_costs(PackCatalog.item("iron_charm")).is_empty(), "Passive maximum bonuses do not get an activation footer")
	var mana_image: Image = PackKeywords.icon("mana").get_image()
	var stamina_image: Image = PackKeywords.icon("stamina").get_image()
	check(mana_image.get_size() == Vector2i(16, 16) and stamina_image.get_size() == Vector2i(16, 16), "Resource icons retain their native 16-pixel grid")
	var same_shape: bool = true
	var binary_alpha: bool = true
	for y in 16:
		for x in 16:
			var ma: float = mana_image.get_pixel(x, y).a
			var sa: float = stamina_image.get_pixel(x, y).a
			same_shape = same_shape and ma == sa
			binary_alpha = binary_alpha and ma in [0.0, 1.0] and sa in [0.0, 1.0]
	check(not same_shape and binary_alpha, "Mana and stamina use distinct simple silhouettes with crisp transparency")
	check(PackKeywords.icon_path("mana") == "res://assets/icons/keywords/mana/mana-16-mask.png", "Mana uses the accepted keyword-owned gem artwork")
	check(PackKeywords.color("stamina").r > 0.8 and PackKeywords.color("stamina").g > 0.65 and PackKeywords.color("stamina").b < 0.6, "Stamina uses a yellow palette")
	check(mana_image.get_used_rect() == Rect2i(1, 1, 14, 14), "Resource glyphs match the shared 14-pixel visible envelope")
	var window: PackInspectWindow = load("res://scenes/shared/inspect_window/inspect_window.tscn").instantiate()
	root.add_child(window)
	window.setup(data)
	check(window.body.get_parsed_text().contains("Priority 2"), "Inspector renders the item priority in its visible footer")
	var text: String = PackKeywords.item_footer_markup(data["resource_costs"], data["priority_label"])
	check(text.contains("[table=2]") and text.find("href=stamina") < text.find("Priority"), "Costs and right-aligned Priority share one footer row")
	check(text.contains("[color=#" + PackKeywords.color("stamina").to_html(false) + "]2"), "Stamina cost is an unsigned colored number")
	check(text.find("]2") < text.rfind("[/img]"), "Resource costs place numbers before icons")
	check(not text.contains("(cost)") and not text.contains("Ctrl-left-click"), "Ordinary item tooltip contains no cost-list labels or control paragraph")
	window._on_keyword_link_entered("priority")
	check(window._hovered_keyword == "priority", "Priority hover follows nested inspection behavior")
	window._on_keyword_link_entered("stamina")
	check(window._hovered_keyword == "stamina" and window._hover_effect.hovered == "stamina", "Colored resource pairs activate the hover appearance effect")
	var inspector: PackInspector = load("res://scenes/shared/inspect_manager/inspect_manager.tscn").instantiate()
	root.add_child(inspector)
	inspector._spawn(data, Rect2(20, 20, 100, 100), -1)
	inspector.windows[0].set_locked(true)
	inspector._open_keyword_link("priority", 0)
	check(inspector.windows.size() == 2 and inspector.windows[1].key == "priority", "Priority opens a nested mechanics definition in the real inspector")
	inspector.free()
	await _render_review(window, data, game)
	window.queue_free()
	game.free()
	await process_frame
	report("ITEM RESOURCE FOOTER")
	quit(1 if failures else 0)

func _render_review(window: PackInspectWindow, data: Dictionary, game: Control) -> void:
	if DisplayServer.get_name() == "headless":
		return
	root.size = Vector2i(1280, 720)
	var review_viewport := SubViewport.new()
	review_viewport.size = Vector2i(1280, 720)
	review_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(review_viewport)
	review_viewport.notify_mouse_entered()
	window.reparent(review_viewport)
	window.setup(data)
	window.position = Vector2(12, 24)
	window.set_locked(true)
	var spell: Dictionary = PackCatalog.item("ember_tome")
	spell.merge({"id": 2, "cell": Vector2i(2, 0), "priority": 0}, true)
	var spell_window: PackInspectWindow = load("res://scenes/shared/inspect_window/inspect_window.tscn").instantiate()
	review_viewport.add_child(spell_window)
	spell_window.setup(game._describe_item(spell, Rect2()))
	spell_window.position = Vector2(436, 24)
	spell_window.set_locked(true)
	var help_window: PackInspectWindow = load("res://scenes/shared/inspect_window/inspect_window.tscn").instantiate()
	review_viewport.add_child(help_window)
	help_window.setup(PackKeywordLinks.entry("priority"))
	help_window.position = Vector2(860, 24)
	help_window.set_locked(true)
	await process_frame
	await process_frame
	window.reset_size()
	spell_window.reset_size()
	help_window.reset_size()
	await process_frame
	await process_frame
	var priority_motion := InputEventMouseMotion.new()
	priority_motion.position = window.body.get_global_rect().position + Vector2(12, 12)
	priority_motion.global_position = priority_motion.position
	review_viewport.push_input(priority_motion, true)
	await process_frame
	await process_frame
	priority_motion.position = window.body.get_global_rect().end - Vector2(38, 16)
	priority_motion.global_position = priority_motion.position
	review_viewport.push_input(priority_motion, true)
	await process_frame
	await process_frame
	priority_motion.position.x += 1
	priority_motion.global_position = priority_motion.position
	review_viewport.push_input(priority_motion, true)
	await process_frame
	await process_frame
	check(window._hovered_keyword == "priority", "Real pointer hover reaches Priority at the right edge of the footer")
	priority_motion.position = Vector2(4, 4)
	priority_motion.global_position = priority_motion.position
	review_viewport.push_input(priority_motion, true)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var review: Image = review_viewport.get_texture().get_image()
	review.save_png(preload("res://tests/support/artifact_paths.gd").path("legacy_godot/item-resource-footer.png"))
	review.save_png("res://workspace/docs/art/concepts/semantic-icons/resources-v6/resource-tooltip-review.png")
	var background: Color = review.get_pixel(20, 35)
	for key: String in ["mana", "stamina"]:
		var idle: float = _contrast(PackKeywords.color(key), background)
		var hover: float = _contrast(PackKeywords.color(key).darkened(0.28), background)
		print("RESOURCE CONTRAST %s on #%s: idle %.2f, hover %.2f" % [key, background.to_html(false), idle, hover])
		check(idle >= 4.5 and hover >= 4.5, "Resource numbers pass contrast on the rendered tooltip background: " + key)
	spell_window.queue_free()
	help_window.queue_free()
	window.reparent(root)
	review_viewport.queue_free()

func _luminance(color: Color) -> float:
	var channels: Array[float] = [color.r, color.g, color.b]
	for index in range(3):
		channels[index] = channels[index] / 12.92 if channels[index] <= 0.04045 else pow((channels[index] + 0.055) / 1.055, 2.4)
	return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722

func _contrast(color: Color, background: Color) -> float:
	return (_luminance(color) + 0.05) / (_luminance(background) + 0.05)
