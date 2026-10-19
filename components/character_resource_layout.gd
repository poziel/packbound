@tool
extends Control
## Fixed-size resource points, capped to each half of the available row.
## Beyond that capacity PixelStatBar uses a continuous proportional fill.

func _ready() -> void:
	for bar in [$ManaBar, $StaminaBar, $MomentumBar]:
		bar.changed.connect(_layout_resources)
	$MomentumBar.visibility_changed.connect(_layout_resources)
	resized.connect(_layout_resources)
	_layout_resources()

func _layout_resources() -> void:
	var available: float = $HpBar.size.x
	var bars: Array = [$ManaBar, $StaminaBar]
	if $MomentumBar.visible:
		bars.append($MomentumBar)
	var lane: float = floorf((available - 14.0 * (bars.size() - 1)) / bars.size())
	var next_x: float = $ManaBar.position.x
	for bar in bars:
		bar.size.x = minf(lane, bar.resource_width())
		bar.position.x = next_x
		next_x += bar.size.x + 14.0
		bar.bar_height = $HpBar.bar_height
		bar.size.y = $HpBar.bar_height
