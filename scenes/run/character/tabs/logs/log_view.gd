extends Control

func _ready() -> void:
	# Both gameplay and the result modal instance this same log scene.
	$History.get_v_scroll_bar().theme_type_variation = &"LogScrollBar"
