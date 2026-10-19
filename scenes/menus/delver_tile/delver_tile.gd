extends Button

## Set this to a key in PackCatalog.classes() when adding a tile in the editor.
@export var class_key: String = "warrior"

func _ready() -> void:
	var roster: Dictionary = PackCatalog.classes()
	if not roster.has(class_key):
		disabled = true
		push_warning("Unknown delver class: " + class_key)
		return
	$ClassName.text = roster[class_key]["name"]
	$Portrait.texture = PackArt.character_head(class_key)
	accessibility_name = roster[class_key]["name"] + ", begin a new run"
	mouse_entered.connect(func() -> void: $Portrait.hovered = true; $Portrait.queue_redraw())
	mouse_exited.connect(func() -> void: $Portrait.hovered = false; $Portrait.queue_redraw())
	focus_entered.connect(func() -> void: $Portrait.hovered = true; $Portrait.queue_redraw())
	focus_exited.connect(func() -> void: $Portrait.hovered = false; $Portrait.queue_redraw())
