extends "res://tests/support/test_case.gd"

var inspector: PackInspector
var view: SubViewport

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func fresh() -> void:
	if is_instance_valid(inspector):
		view.remove_child(inspector)
		inspector.queue_free()
	inspector = PackInspector.new()
	view.add_child(inspector)
	inspector.set_process(false)
	inspector.source = inspector
	inspector.source_rect = Rect2(10, 10, 20, 20)
	inspector.show_delay = 0.15
	inspector.lock_delay = 1.2
	inspector.grace_delay = 0.7
	inspector.closing_delay = 0.7

func spawn(key: String, locked: bool = true) -> PackInspectWindow:
	var index: int = inspector.windows.size()
	inspector.active_trigger_id = "trigger_%d" % index
	inspector._spawn({"key": key, "title": key, "body": "Details"}, Rect2(), index - 1)
	var window: PackInspectWindow = inspector.windows.back()
	window._placed = true
	window.lock_drop = 0
	window.position = Vector2(100 + index * 450, 100)
	window.size = Vector2(400, 200)
	window.modulate.a = 1
	window.set_locked(locked)
	return window

func enter(index: int, delta: float = 0.01) -> void:
	inspector.active_keyword_link = ""
	inspector.active_parent = -1
	inspector.pointer = inspector.windows[index].position + Vector2(20, 15)
	inspector._process(delta)

func trigger(index: int, delta: float) -> void:
	inspector.pointer = Vector2(20, 20) if index == 0 else inspector.windows[index - 1].position + Vector2(20, 15)
	inspector.active_parent = index - 1
	inspector.active_keyword_link = "" if index == 0 else inspector.windows[index].key
	inspector.active_trigger_id = inspector.windows[index].trigger_id
	inspector._process(delta)

func outside(delta: float) -> void:
	inspector.pointer = Vector2(20, 1000)
	inspector.active_keyword_link = ""
	inspector._process(delta)

func _run() -> void:
	view = SubViewport.new()
	view.size = Vector2i(2400, 1200)
	root.add_child(view)
	fresh()
	var root_window: PackInspectWindow = spawn("root", false)
	trigger(0, 1.19)
	check(not root_window.locked, "Lock delay starts after appearance and requires continuous trigger hover")
	outside(0.001)
	check(inspector.windows.is_empty(), "Leaving unlocked trigger closes immediately")
	fresh()
	spawn("root", false)
	enter(0, 0.001)
	check(inspector.windows.is_empty(), "Entering unlocked tooltip cannot complete its lock")
	fresh()
	root_window = spawn("root", false)
	trigger(0, 1.2)
	check(root_window.locked, "Trigger hover locks at configured delay")
	outside(0.69)
	check(inspector.windows.size() == 1, "Locked root gets full travel grace")
	enter(0)
	check(root_window.entered and root_window.away_age == 0, "Entering resets travel timer")
	outside(0.69)
	check(inspector.windows.size() == 1, "Entered root gets closing delay")
	enter(0)
	outside(0.69)
	check(inspector.windows.size() == 1, "Returning resets closing timer")
	outside(0.02)
	check(inspector.windows.is_empty(), "Closing delay expiry removes root")
	fresh()
	spawn("root")
	outside(0.71)
	check(inspector.windows.is_empty(), "Travel grace can expire before first entry")
	fresh()
	spawn("root")
	enter(0)
	var descendant: PackInspectWindow = spawn("damage")
	enter(0, 0.69)
	check(inspector.windows.size() == 2, "Unvisited descendant survives travel across ancestor")
	enter(1)
	check(descendant.entered, "Entering descendant records its own first entry")
	enter(0, 0.69)
	check(inspector.windows.size() == 2, "Returning upward uses closing delay rather than instant trim")
	enter(1)
	enter(0, 0.69)
	check(inspector.windows.size() == 2, "Re-entering descendant resets its closing timer")
	enter(0, 0.02)
	check(inspector.windows.size() == 1, "Returning upward closes descendant after delay")
	fresh()
	for key: String in ["root", "damage", "poison", "cleanse"]:
		spawn(key)
		enter(inspector.windows.size() - 1)
	enter(1, 0.69)
	check(inspector.windows.size() == 4, "Ancestor and descendants survive until shared deadline")
	enter(1, 0.02)
	check(inspector.windows.size() == 2, "Multiple descendants close together without cascading")
	spawn("poison")
	spawn("cleanse")
	trigger(0, 0.69)
	check(inspector.windows.size() == 4, "Original trigger return grants closing delay even to unvisited descendants")
	trigger(0, 0.02)
	check(inspector.windows.size() == 1, "Original trigger keeps root and dismisses every descendant")
	fresh()
	spawn("root")
	enter(0)
	spawn("damage")
	enter(0, 0.6)
	trigger(0, 0.1)
	check(inspector.windows.size() == 2, "Returning to trigger starts a fresh closing delay, independent of elapsed grace")
	trigger(0, 0.59)
	check(inspector.windows.size() == 2, "Fresh closing delay remains available after trigger return")
	trigger(0, 0.02)
	check(inspector.windows.size() == 1, "Trigger-return closing expires at its own deadline")
	fresh()
	for key: String in ["root", "damage", "poison", "cleanse"]:
		spawn(key)
		enter(inspector.windows.size() - 1)
	trigger(2, 0.69)
	check(inspector.windows.size() == 4, "Returning to a middle tooltip trigger waits for closing delay")
	enter(3)
	trigger(2, 0.69)
	check(inspector.windows.size() == 4, "Re-entering a branch cancels trigger-return dismissal")
	trigger(2, 0.02)
	check(inspector.windows.size() == 3, "Middle trigger keeps its tooltip and ancestors, closing only descendants")
	fresh()
	inspector.grace_delay = 0.2
	inspector.closing_delay = 1.3
	spawn("root")
	outside(0.21)
	check(inspector.windows.is_empty(), "Unvisited tooltip uses independently configured grace delay")
	fresh()
	inspector.grace_delay = 0.2
	inspector.closing_delay = 1.3
	spawn("root")
	enter(0)
	outside(0.21)
	check(inspector.windows.size() == 1, "Entered tooltip uses closing delay rather than shorter grace")
	outside(1.1)
	check(inspector.windows.is_empty(), "Independent closing delay expires at its own duration")
	fresh()
	for key: String in ["root", "damage", "poison", "cleanse"]:
		spawn(key)
		enter(inspector.windows.size() - 1)
	outside(0.69)
	check(inspector.windows.size() == 4, "Leaving whole chain waits one closing delay")
	outside(0.02)
	check(inspector.windows.is_empty(), "Whole chain closes simultaneously")
	fresh()
	spawn("root")
	enter(0)
	descendant = spawn("damage", false)
	trigger(1, 0.6)
	check(not descendant.locked, "Descendant uses same lock duration")
	enter(1, 0.001)
	check(inspector.windows.size() == 1, "Unlocked descendant closes immediately on trigger exit")
	fresh()
	inspector.lock_delay = 0
	root_window = spawn("root")
	check(root_window.locked, "Zero lock delay is immediately enterable")
	inspector.grace_delay = 0
	outside(0)
	check(inspector.windows.is_empty(), "Zero grace delay closes immediately")
	fresh()
	spawn("root")
	enter(0)
	inspector.closing_delay = 0
	outside(0)
	check(inspector.windows.is_empty(), "Zero closing delay closes immediately")
	view.queue_free()
	await process_frame
	report("TOOLTIP RULES")
	quit(1 if failures else 0)
