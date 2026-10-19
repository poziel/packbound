@tool
extends Control
## Fixed-size resource points, capped to each half of the available row.
## Beyond that capacity PixelStatBar uses a continuous proportional fill.
var _widths: Dictionary = {}
var _targets: Dictionary = {}
var _starts: Dictionary = {}
var _ages: Dictionary = {}

func _process(delta: float) -> void:
	var changed: bool = false
	for bar in _targets:
		if _widths[bar] == _targets[bar]: continue
		_ages[bar] = minf(0.4, float(_ages[bar]) + delta)
		_widths[bar] = lerpf(_starts[bar], _targets[bar], smoothstep(0.0, 0.4, _ages[bar]))
		changed = true
	if changed: _layout_resources()

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
		var target: float = minf(lane, bar.resource_width())
		if not _widths.has(bar) or Engine.is_editor_hint() or not is_visible_in_tree():
			_widths[bar] = target
			_targets[bar] = target
		elif _targets[bar] != target:
			_starts[bar] = _widths[bar]
			_targets[bar] = target
			_ages[bar] = 0.0
		bar.size.x = _widths[bar]
		bar.position.x = next_x
		next_x += bar.size.x + 14.0
		bar.bar_height = $HpBar.bar_height
		bar.size.y = $HpBar.bar_height
