extends Control
## Full-resolution interactions projected onto the room's physical doors.

signal door_chosen(id: String)
signal activity_chosen(action: String)
signal inspection_target(target: Control, data: Dictionary)

var door_buttons: Array[Button] = []
var door_ids: Array[String] = []
var background: Control
var locked: bool = false
var signature: String = ""
var encounter_open: bool = false
var activity_room: Node3D
@onready var heading: Label = $Heading
@onready var activity_panel: PanelContainer = $Activity
@onready var title: Label = $Activity/Margin/Rows/Title
@onready var body: Label = $Activity/Margin/Rows/Body
@onready var options: VBoxContainer = $Activity/Margin/Rows/Options

func refresh(run: PackRun, scene_background: Control, input_locked: bool) -> void:
	background = scene_background
	locked = input_locked
	visible = run.phase in [PackRun.Phase.SELECTOR, PackRun.Phase.ROOM, PackRun.Phase.ROOM_COMPLETE] and not background.transitioning
	if not visible:
		signature = ""
		_clear_doors()
		return
	var next_signature: String = str([run.phase, run.door_choices, run.room_kind, run.room_event, run.room_relic_offers, run.hp, run.relics])
	if signature == next_signature:
		_set_locked()
		return
	signature = next_signature
	var current_room: Node3D = background.world.active_room
	if activity_room != current_room:
		activity_room = current_room
		encounter_open = false
	_clear_doors()
	activity_panel.visible = false
	if current_room.has_method("configure_activity"):
		current_room.configure_activity(run)
	heading.text = "CHOOSE FLOOR %02d" % (run.display_floor() + 1) if run.phase == PackRun.Phase.SELECTOR else "FLOOR %02d / %s" % [run.display_floor(), run.room_kind.to_upper()]
	if run.phase == PackRun.Phase.SELECTOR:
		for door: Dictionary in run.door_choices:
			var button := Button.new()
			button.accessibility_name = "Enter %s floor" % str(door.kind).capitalize()
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.pressed.connect(func() -> void: door_chosen.emit(door.id))
			button.mouse_entered.connect(_highlight.bind(door.id))
			button.mouse_exited.connect(_highlight.bind(""))
			button.focus_entered.connect(_highlight.bind(door.id))
			button.focus_exited.connect(_highlight.bind(""))
			# Keep native mouse/keyboard semantics; all feedback belongs to the 3D door.
			for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
				button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			add_child(button)
			door_buttons.append(button)
			door_ids.append(door.id)
		_set_locked()
		_process(0)
		return
	if run.phase == PackRun.Phase.ROOM_COMPLETE:
		_set_locked()
		return
	if run.room_reward_pending:
		for key: String in run.room_relic_offers:
			var relic: Dictionary = PackCatalog.relic(key)
			_add_activity("relic:" + key, str(relic.name), false, {"key": "floor_relic_" + key, "title": relic.name, "body": relic.detail, "restriction_content": relic, "keyword_stats": PackKeywords.relic_stats(relic), "rarity": PackCatalog.RARITY.tier(relic)})
		_set_locked()
		_process(0)
		return
	if run.room_kind == "rest":
		var heal: int = mini(run.max_hp - run.hp, ceili(run.max_hp * 0.30))
		_add_activity("rest", "Rest at the campfire", heal == 0, {"key": "floor_rest", "title": "Rest", "body": "Regain %d health." % heal})
		_set_locked()
		_process(0)
		return
	if not encounter_open:
		_add_activity("encounter", "Inspect the altar" if run.room_event == "blood_offering" else "Speak to the keeper", false, {"key": "floor_encounter", "title": "Investigate", "body": "Interact to discover this encounter's choices."})
		_set_locked()
		_process(0)
		return
	activity_panel.visible = true
	for child: Node in options.get_children():
		options.remove_child(child)
		child.queue_free()
	var event: Dictionary = preload("res://systems/runs/room_routes.gd").event(run.room_event)
	title.text = event.title
	body.text = event.body
	if run.room_event == "blood_offering":
		_add_option("Offer %d health / choose a relic" % run.offering_cost(), "offer", run.hp <= run.offering_cost())
		_add_option("Leave the altar", "leave")
	else:
		_add_option("Answer honestly / receive an item choice", "answer")
		_add_option("Refuse / fight the keeper", "refuse")
		_add_option("Turn away / leave", "leave")
	_set_locked()

func _add_activity(id: String, label: String, unavailable: bool, data: Dictionary) -> void:
	var button := Button.new()
	button.accessibility_name = label
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("unavailable", unavailable)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(func() -> void:
		if id == "encounter":
			encounter_open = true
			signature = ""
		else:
			activity_chosen.emit(id))
	button.mouse_entered.connect(_highlight_activity.bind(id))
	button.mouse_exited.connect(_highlight_activity.bind(""))
	button.focus_entered.connect(_highlight_activity.bind(id))
	button.focus_exited.connect(_highlight_activity.bind(""))
	add_child(button)
	door_buttons.append(button)
	door_ids.append(id)
	inspection_target.emit(button, data)

func _highlight_activity(id: String) -> void:
	if is_instance_valid(activity_room) and activity_room.has_method("highlight_activity"):
		activity_room.highlight_activity(id)

func _add_option(label: String, action: String, unavailable: bool = false, detail: String = "") -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = detail
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 48
	button.set_meta("unavailable", unavailable)
	button.pressed.connect(func() -> void: activity_chosen.emit(action))
	options.add_child(button)

func _clear_doors() -> void:
	for button: Button in door_buttons:
		remove_child(button)
		button.queue_free()
	door_buttons.clear()
	door_ids.clear()

func _set_locked() -> void:
	for button: Button in door_buttons:
		button.disabled = locked or button.get_meta("unavailable", false)
	for button: Button in options.get_children():
		button.disabled = locked or button.get_meta("unavailable", false)

func focus_first() -> void:
	if locked or not is_visible_in_tree():
		return
	var buttons: Array = door_buttons if not door_buttons.is_empty() else options.get_children()
	for button: Button in buttons:
		if not button.disabled:
			button.grab_focus()
			return

func select_choice(index: int) -> void:
	if locked or not is_visible_in_tree():
		return
	var buttons: Array = options.get_children() if activity_panel.visible else door_buttons
	if index < 0 or index >= buttons.size():
		return
	var button: Button = buttons[index]
	if button.is_visible_in_tree() and not button.disabled:
		button.pressed.emit()

func _highlight(id: String) -> void:
	if background and background.world.active_room.has_method("highlight"):
		background.world.active_room.highlight(id)

func _process(_delta: float) -> void:
	if not visible or not background or door_buttons.is_empty():
		return
	var room: Node3D = background.world.active_room
	var selecting: bool = room.has_method("door_position")
	if not selecting and not room.has_method("activity_position"):
		return
	var camera: Camera3D = background.world.camera
	var scale_factor: Vector2 = background.size / Vector2(camera.get_viewport().size)
	for index in range(door_buttons.size()):
		var point: Vector3 = room.door_position(door_ids[index]) if selecting else room.activity_position(door_ids[index])
		var half: Vector2 = room.door_half_size(door_ids[index]) if selecting else Vector2(0.9, 1.5)
		var top: Vector2 = camera.unproject_position(point + camera.global_basis.y * half.y) * scale_factor
		var bottom: Vector2 = camera.unproject_position(point - camera.global_basis.y * half.y) * scale_factor
		var height: float = maxf(60, bottom.y - top.y)
		var width: float = maxf(64, height * half.x / half.y)
		door_buttons[index].position = Vector2(top.x - width * 0.5, top.y)
		door_buttons[index].size = Vector2(width, height)
