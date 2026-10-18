@tool
extends Control
## Fixed-size resource points, capped to each half of the available row.
## Beyond that capacity PixelStatBar uses a continuous proportional fill.

func _ready() -> void:
	for bar in [$ManaBar, $StaminaBar]:
		bar.changed.connect(_layout_resources)
	resized.connect(_layout_resources)
	_layout_resources()

func _layout_resources() -> void:
	var available: float = $HpBar.size.x
	var lane: float = floorf((available - 14.0) / 2.0)
	$ManaBar.size.x = minf(lane, $ManaBar.resource_width())
	$StaminaBar.size.x = minf(lane, $StaminaBar.resource_width())
	$StaminaBar.position.x = $ManaBar.position.x + $ManaBar.size.x + 14.0
	for bar in [$ManaBar, $StaminaBar]:
		bar.bar_height = $HpBar.bar_height
		bar.size.y = $HpBar.bar_height
