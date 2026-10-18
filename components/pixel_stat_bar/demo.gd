extends Control

const StatBar = preload("pixel_stat_bar.gd")

@onready var amount: HSlider = $Amount
@onready var meters: Array[StatBar] = [$Health, $Shield, $Mana, $Experience]


func _ready() -> void:
	amount.value_changed.connect(_set_fill)
	$Damage.pressed.connect(func() -> void: amount.value -= 10.0)
	$Recover.pressed.connect(func() -> void: amount.value += 10.0)
	$Reset.pressed.connect(func() -> void: amount.value = 75.0)
	$Glow.pressed.connect(_preview_glow)
	_set_fill(amount.value)

func _preview_glow() -> void:
	for meter: StatBar in meters + [$Full, $Low, $Empty, $Compact]:
		meter.flash_glow()


func _set_fill(percent: float) -> void:
	for meter: StatBar in meters:
		meter.value = meter.max_value * percent / 100.0
	$FillValue.text = "%d%%" % roundi(percent)
