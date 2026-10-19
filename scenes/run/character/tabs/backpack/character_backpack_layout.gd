extends Control
## Center the fixed pixel grid without changing its local item/drag geometry.

func _ready() -> void:
	resized.connect(_align_content)
	_align_content()

func _align_content() -> void:
	var grid_width: float = BackpackBoard.GRID_RECT.size.x
	var shift: float = floorf((size.x - grid_width) * 0.5) - BackpackBoard.ORIGIN.x
	$Inventory.position.x = shift
	$Player.position.x = shift
	$Statuses.position.x = shift + BackpackBoard.ORIGIN.x
