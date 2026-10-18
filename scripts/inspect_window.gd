class_name PackInspectWindow
extends PanelContainer

signal keyword_link_entered(key: String)
signal keyword_link_exited
signal keyword_link_pressed(key: String)

@export var lock_drop: float = 4.0
@export var lock_duration: float = 0.12
var locked: bool = false
var age: float = 0.0
var away_age: float = 0.0
var key: String = ""
var _placed: bool = false
var _lock_animated: bool = false
var _rich_text: String = ""
var _keyword_links: Array[String] = []
var _keyboard_keyword_link: int = -1
var _hovered_keyword: String = ""
var _hover_generation: int = 0
var _updating_hover: bool = false
@onready var body: RichTextLabel = $Content/Body
@onready var timer: Control = $Content/Header/TimerSlot/Timer

func setup(data: Dictionary) -> void:
	_hovered_keyword = ""
	_hover_generation += 1
	key = data.get("key", "")
	var title_text: String = data.get("title", "")
	var is_keyword_definition: bool = not PackKeywordLinks.entry(key).is_empty()
	# Only keyword definition headings describe mechanics; item and relic titles keep their identity.
	$Content/Header/Title.text = PackKeywordLinks.rich(title_text, "", false) if is_keyword_definition else title_text
	$Content/Header/Icon.texture = data.get("icon")
	$Content/Header/Icon.visible = data.has("icon") and not is_keyword_definition
	_rich_text = PackKeywordLinks.rich(data.get("body", ""), key)
	var keyword_stats: String = PackKeywords.stats_markup(data.get("keyword_stats", []), true, body.get_theme_color("default_color"))
	if not keyword_stats.is_empty():
		_rich_text = keyword_stats + "\n\n" + _rich_text
	var keyword_list: String = PackKeywords.list_markup(data.get("keyword_list", []), true, body.get_theme_color("default_color"))
	if not keyword_list.is_empty():
		_rich_text = keyword_list + ("\n\n" + _rich_text if not _rich_text.is_empty() else "")
	var footer: String = PackKeywords.item_footer_markup(data.get("resource_costs", []), data.get("priority_label", ""))
	if not footer.is_empty():
		_rich_text += ("\n\n" if not _rich_text.is_empty() else "") + footer
	body.text = _rich_text
	if not body.meta_hover_started.is_connected(_on_keyword_link_entered):
		body.meta_hover_started.connect(_on_keyword_link_entered)
		body.meta_hover_ended.connect(_on_keyword_link_exited)
		body.meta_clicked.connect(_on_keyword_link_pressed)
	_keyword_links.clear()
	_keyboard_keyword_link = -1
	var regex := RegEx.new()
	regex.compile("\\[url(?:=| href=)([^ \\]]+)")
	for found in regex.search_all(_rich_text):
		var keyword_link: String = found.get_string(1)
		if not _keyword_links.has(keyword_link):
			_keyword_links.append(keyword_link)
	set_locked(false)

func _on_keyword_link_entered(meta: Variant) -> void:
	if _updating_hover:
		return
	_hover_generation += 1
	if _hovered_keyword != str(meta):
		_hovered_keyword = str(meta)
		_refresh_keyword_appearance()
	keyword_link_entered.emit(str(meta))

func _on_keyword_link_exited(_meta: Variant) -> void:
	if not _updating_hover:
		_finish_keyword_hover.call_deferred(_hover_generation)

func _finish_keyword_hover(generation: int) -> void:
	if generation != _hover_generation:
		return
	_hovered_keyword = ""
	_refresh_keyword_appearance()
	keyword_link_exited.emit()

func _refresh_keyword_appearance() -> void:
	# Reentrant meta-exit events from recoloring must not dismiss nested inspection.
	_updating_hover = true
	var appearance: String = PackKeywordLinks.hover_markup(_rich_text, _hovered_keyword, body.get_theme_color("default_color"))
	if body.has_focus() and _keyboard_keyword_link >= 0:
		var selected: String = _keyword_links[_keyboard_keyword_link]
		var start: int = appearance.find("[url=" + selected + "]")
		if start < 0:
			start = appearance.find("[url href=" + selected + " ")
		if start >= 0:
			var end: int = appearance.find("[/url]", start) + "[/url]".length()
			appearance = appearance.left(start) + "[bgcolor=#3b3327]" + appearance.substr(start, end - start) + "[/bgcolor]" + appearance.substr(end)
	body.text = appearance
	_updating_hover = false

func _on_keyword_link_pressed(meta: Variant) -> void:
	keyword_link_pressed.emit(str(meta))

func set_locked(value: bool) -> void:
	locked = value
	mouse_filter = Control.MOUSE_FILTER_STOP if locked else Control.MOUSE_FILTER_IGNORE
	body.mouse_filter = mouse_filter
	body.focus_mode = Control.FOCUS_ALL if locked else Control.FOCUS_NONE
	# The slot stays in the header, so hiding the ring never reflows the title.
	timer.visible = not locked
	if locked:
		_animate_lock()
	else:
		timer.progress = 0.0

func place_at(at: Vector2) -> void:
	position = at
	_placed = true
	if locked:
		_animate_lock()

func _animate_lock() -> void:
	if not _placed or _lock_animated:
		return
	_lock_animated = true
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(self, "position:y", position.y + lock_drop, lock_duration)

func progress(ratio: float) -> void:
	timer.progress = ratio
	if ratio >= 1.0:
		set_locked(true)

func focus_body() -> void:
	body.grab_focus()
	if not _keyword_links.is_empty():
		_select_keyword_link(0)

func _select_keyword_link(index: int) -> void:
	_keyboard_keyword_link = posmod(index, _keyword_links.size())
	_refresh_keyword_appearance()

func _input(event: InputEvent) -> void:
	if not locked or not body.has_focus() or _keyword_links.is_empty() or not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_TAB, KEY_RIGHT, KEY_DOWN:
			_select_keyword_link(_keyboard_keyword_link + (-1 if event.shift_pressed else 1))
		KEY_LEFT, KEY_UP:
			_select_keyword_link(_keyboard_keyword_link - 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			keyword_link_pressed.emit(_keyword_links[maxi(0, _keyboard_keyword_link)])
		_:
			return
	get_viewport().set_input_as_handled()
