@tool
extends Resource
## One shared palette for every decorated menu-button state.

@export var outline: Color = Color("131c31"):
	set(value):
		outline = value
		emit_changed()
@export var border_matches_face: bool = true:
	set(value):
		border_matches_face = value
		emit_changed()
@export var trim: Color = Color("53636e"):
	set(value):
		trim = value
		emit_changed()
@export var face: Color = Color("53636e"):
	set(value):
		face = value
		emit_changed()
@export var hover_face: Color = Color("6b7e89"):
	set(value):
		hover_face = value
		emit_changed()
@export var pressed_face: Color = Color("3b4c56"):
	set(value):
		pressed_face = value
		emit_changed()
@export var disabled_face: Color = Color("647078"):
	set(value):
		disabled_face = value
		emit_changed()
