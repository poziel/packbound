extends Control

@onready var hold: Button = $Frame/Padding/Columns/Actions/Hold
@onready var status: Label = $Frame/Padding/Columns/Actions/HoldStatus

func _ready() -> void:
	hold.confirmed.connect(func() -> void: status.text = "Confirmed!")
	hold.button_down.connect(func() -> void: status.text = "Keep holding...")
	hold.hold_cancelled.connect(func() -> void: status.text = "Cancelled. Hold to try again.")
