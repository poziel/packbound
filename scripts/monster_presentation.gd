@tool
extends Resource
## Source-pixel measurements; these never change the monster's body scale.

@export var monster_id: String = ""
## Ellipse width and depth in source pixels, converted with Sprite3D.pixel_size.
@export var shadow_size := Vector2(80, 36)
## Ground-plane offset from the sprite's registered foot anchor, in source
## pixels: x = right, y = toward camera. Ignore tails and held equipment.
@export var shadow_offset := Vector2.ZERO
@export_range(0.0, 1.0, 0.01) var shadow_opacity: float = 0.6
@export var shadow_enabled: bool = true
@export var flying: bool = false
