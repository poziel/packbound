extends Control
## Environment-neutral viewport wrapper and cancellable room transitions.

signal reveal_changed(amount: float)
signal transition_changed

@export var encounter_room: PackedScene = preload("res://scenes/gameplay/rooms/dungeon/dungeon_room.tscn")
@export var deeper_encounter_room: PackedScene = preload("res://scenes/gameplay/rooms/cursed/cursed_room.tscn")
@export var entrance_room: PackedScene = preload("res://scenes/gameplay/rooms/basement/basement_entrance.tscn")
var encounter_floor: int = 1
@onready var world: Node3D = $Render/Viewport/GameplayWorld
@onready var fade: ColorRect = $Fade
@onready var enemy: Sprite3D = $Render/Viewport/GameplayWorld/Actors/Enemy
var enemy_hover: Control
var transitioning: bool = false:
	set(value):
		transitioning = value
		transition_changed.emit()
var active_tween: Tween
var generation: int = 0
@export_range(1.5, 4.0, 0.1) var arrival_seconds: float = 2.2

func _ready() -> void:
	# Project hover bounds after the actor's idle/reaction pose has updated.
	process_priority = 10
	world.room_changed.connect(_sync_pixel_downscale)
	_sync_pixel_downscale()

func _sync_pixel_downscale() -> void:
	$Render.stretch_shrink = world.active_room.pixel_downscale

func is_at_entrance() -> bool:
	return world.active_room.scene_file_path == entrance_room.resource_path

func _process(_delta: float) -> void:
	if not is_instance_valid(enemy_hover):
		return
	enemy_hover.visible = enemy.is_visible_in_tree() and not transitioning
	if enemy_hover.visible and enemy.texture:
		var bounds: Rect2 = enemy_screen_bounds()
		enemy_hover.position = bounds.position
		enemy_hover.size = bounds.size

func enemy_screen_bounds() -> Rect2:
	return enemy.projected_bounds(world.camera, size)

func room_for_floor(floor_number: int) -> PackedScene:
	return deeper_encounter_room if floor_number >= 11 else encounter_room

func select_floor(floor_number: int) -> void:
	# Select the destination without replacing scenery during the departure walk.
	encounter_floor = floor_number

func reset(floor_number: int = 1) -> void:
	generation += 1
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	transitioning = false
	fade.hide()
	fade.modulate.a = 0.0
	select_floor(floor_number)
	world.set_room(room_for_floor(encounter_floor))
	reveal_changed.emit(1.0)

func prepare_entrance() -> void:
	world.set_room(entrance_room)
	fade.hide()
	fade.modulate.a = 0.0

func descend(covered: Callable, speed: float = 1.0) -> void:
	await travel_to(room_for_floor(encounter_floor), covered, speed)

func scene_for_state(run: PackRun) -> PackedScene:
	if run.phase == PackRun.Phase.SELECTOR:
		var biome: String = "cursed" if run.display_floor() + 1 >= 11 else "dungeon"
		return load("res://scenes/gameplay/rooms/%s/floor_selector.tscn" % biome)
	if run.room_kind == "combat":
		return room_for_floor(run.display_floor())
	if run.display_floor() <= 10 and run.room_kind in ["encounter", "relic", "rest"]:
		return load("res://scenes/gameplay/rooms/dungeon/%s_room.tscn" % run.room_kind)
	return load("res://scenes/gameplay/rooms/%s/%s_room.tscn" % [run.room_kind, run.room_kind])

func travel_to(destination: PackedScene, covered: Callable, speed: float = 1.0) -> void:
	if transitioning:
		return
	if destination == null:
		return
	transitioning = true
	var current: int = generation
	var from_entrance: bool = is_at_entrance()
	fade.show()
	active_tween = create_tween().set_speed_scale(speed)
	if from_entrance:
		active_tween.tween_interval(0.45)
	active_tween.tween_method(_advance_passage, 0.0, 1.0, world.active_room.departure_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await active_tween.finished
	if current != generation:
		return
	if not world.set_room(destination):
		fade.hide()
		transitioning = false
		return
	reveal_changed.emit(0.0)
	covered.call()
	# Reveal the room early, then visibly walk down the approach to the encounter.
	_reveal_room(0.0)
	active_tween = create_tween().set_speed_scale(speed)
	active_tween.tween_method(_reveal_room, 0.0, 1.0, arrival_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await active_tween.finished
	if current != generation:
		return
	world.reset_camera()
	fade.hide()
	transitioning = false

func _advance_passage(progress: float) -> void:
	world.advance_camera(progress)
	# Preserve the original exit into darkness. The visible stair descent is
	# now the arrival from the upper floor, on the room's separate entry stairs.
	fade.modulate.a = smoothstep(0.68 if is_at_entrance() else 0.48, 0.96 if is_at_entrance() else 0.94, progress)

func _reveal_room(amount: float) -> void:
	# Enemy and masonry share visibility; the rest of the approach stays visible.
	var visibility: float = smoothstep(0.0, 0.22, amount)
	fade.modulate.a = 1.0 - visibility
	world.arrive_camera(amount)
	reveal_changed.emit(visibility)
