class_name PackEnemyCard
extends Control

signal hit_started
signal death_started

@export var hit_rise_seconds: float = 0.07
@export var hit_settle_seconds: float = 0.23
const STRIKE_SECONDS: float = 0.28
const DEATH_SECONDS: float = 0.42
@export var presentation_library: Resource = preload("res://assets/enemies/presentation.tres")
var presentation: Resource

@onready var art: TextureRect = $EnemyArt
@onready var hit_particles: CPUParticles2D = $HitParticles
var hit_tween: Tween
var strike_tween: Tween
var rest_position: Vector2
var world_art: Sprite3D
var world_rest: Vector3
var screen_bounds: Callable
var world_flash: Sprite3D
var flat_flash: TextureRect
var shadow: MeshInstance3D
var death_pixels: Node2D
var defeated: bool = false
var flying: bool = false
var hover_time: float = 0.0
var source_rect := Rect2()
var bounds_texture: Texture2D
var reaction_scale := Vector2.ONE:
	set(value):
		reaction_scale = value
		if is_node_ready():
			_apply_pose()
var approach: float = 0.0:
	set(value):
		approach = value
		if is_node_ready():
			_apply_pose()
var flash_color := Color(1, 1, 1, 0):
	set(value):
		flash_color = value
		if is_instance_valid(world_flash):
			world_flash.modulate = value
		if is_instance_valid(flat_flash):
			flat_flash.modulate = value
var _feedback_paused: bool = false
var _paused_tweens: Array[Tween] = []
var _particle_speed: float = 1.0
const EFFECT_POPUP = preload("res://systems/combat/feedback/combat_effect_popup.gd")
var effect_popups: Array[Dictionary] = []
var _popup_rng := RandomNumberGenerator.new()

static func monster_effect_entries(result: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var damage: int = int(result.get("direct_damage_actual", result.get("dealt", 0)))
	if damage > 0:
		var magical: int = int(result.get("direct_magical_actual", 0))
		var physical: int = int(result.get("direct_physical_actual", damage - magical))
		if physical > 0:
			entries.append({"key": "physical_attack", "amount": physical})
		if magical > 0:
			entries.append({"key": "magical_attack", "amount": magical})
	for key: String in ["poison", "burn", "doom", "spark"]:
		var applied: int = 0
		for effect: Dictionary in result.get("item_effects", []):
			if effect["key"] == key:
				applied += int(effect["amount"])
		if applied > 0:
			entries.append({"key": key, "amount": applied})
		elif int(result.get(key + "_damage_actual", 0)) > 0:
			entries.append({"key": key, "amount": result[key + "_damage_actual"]})
	return entries

func show_combat_effects(result: Dictionary, speed: float = 1.0) -> void:
	var bounds: Rect2 = screen_bounds.call() if world_art else Rect2(art.global_position + _visible_art_rect().position, _visible_art_rect().size)
	bounds.position -= global_position
	var center: Vector2 = bounds.get_center()
	var sample: Callable = func() -> Vector2:
		return center + Vector2(_popup_rng.randf() + _popup_rng.randf() - 1, _popup_rng.randf() + _popup_rng.randf() - 1) * bounds.size.max(Vector2(64, 64)) * 0.4
	var lane: int = 0
	for entry: Dictionary in monster_effect_entries(result):
		EFFECT_POPUP.append(effect_popups, entry["key"], int(entry["amount"]), sample, Rect2(center - bounds.size.max(Vector2(64, 64)) * 0.5, bounds.size.max(Vector2(64, 64))), _popup_rng, speed, lane)
		lane += 1
	queue_redraw()

func _draw() -> void:
	EFFECT_POPUP.draw(self, effect_popups)

func _ready() -> void:
	rest_position = art.position
	flat_flash = TextureRect.new()
	flat_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flat_flash.expand_mode = art.expand_mode
	flat_flash.stretch_mode = art.stretch_mode
	flat_flash.texture_filter = art.texture_filter
	art.add_child(flat_flash)
	death_pixels = Node2D.new()
	death_pixels.set_script(preload("res://scenes/run/enemy_card/monster_death_pixels.gd"))
	add_child(death_pixels)

func bind_world_art(sprite: Sprite3D, bounds_provider: Callable) -> void:
	world_art = sprite
	world_rest = sprite.position
	sprite.spawn_changed.connect(_world_anchor_changed)
	screen_bounds = bounds_provider
	world_flash = Sprite3D.new()
	world_flash.pixel_size = sprite.pixel_size
	world_flash.offset = sprite.offset
	world_flash.billboard = sprite.billboard
	world_flash.texture_filter = sprite.texture_filter
	world_flash.layers = sprite.layers
	world_flash.no_depth_test = false
	world_flash.render_priority = 1
	sprite.add_child(world_flash)
	_create_shadow()
	art.hide()
	visibility_changed.connect(_sync_world_visibility)
	_sync_world_visibility()

func _world_anchor_changed() -> void:
	world_rest = world_art.position
	_apply_pose()
	_sync_world_visibility()

func _create_shadow() -> void:
	shadow = MeshInstance3D.new()
	shadow.name = "MonsterShadow"
	shadow.layers = world_art.layers
	var plane := PlaneMesh.new()
	shadow.mesh = plane
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var distance: float = (Vector2(x, y) - Vector2(31.5, 31.5)).length() / 31.5
			image.set_pixel(x, y, Color(0.025, 0.03, 0.045, 1.0 - smoothstep(0.35, 1.0, distance)))
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.albedo_color.a = 0.6
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shadow.material_override = material
	world_art.get_parent().add_child(shadow)

func _exit_tree() -> void:
	if is_instance_valid(shadow):
		shadow.queue_free()

func set_monster(key: String) -> void:
	presentation = presentation_library.profile_for(key)
	if presentation == null:
		presentation = preload("res://systems/enemies/monster_presentation.gd").new()
		var width: float = art.texture.get_image().get_used_rect().size.x
		presentation.shadow_size = Vector2(width * 0.7, maxf(16, width * 0.3))
	flying = presentation.flying
	if flat_flash.texture == null or flat_flash.get_meta("source", null) != art.texture:
		reset_feedback()
		var image: Image = art.texture.get_image()
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				image.set_pixel(x, y, Color(1, 1, 1, image.get_pixel(x, y).a))
		var mask := ImageTexture.create_from_image(image)
		flat_flash.texture = mask
		flat_flash.set_meta("source", art.texture)
		if world_flash:
			world_flash.texture = mask
	_apply_pose()
	_sync_world_visibility()

func _sync_world_visibility() -> void:
	if world_art:
		world_art.visible = world_art.has_spawn and is_visible_in_tree() and not defeated
		shadow.visible = world_art.visible and (presentation == null or presentation.shadow_enabled)

func _process(delta: float) -> void:
	if not _feedback_paused and not effect_popups.is_empty():
		EFFECT_POPUP.advance(effect_popups, delta)
		queue_redraw()
	if not _feedback_paused and not defeated and is_visible_in_tree():
		hover_time += delta
	_apply_pose()

func _apply_pose() -> void:
	# Separate idle and reaction channels avoid competing position tweens.
	var hover: float = sin(hover_time * TAU / 1.8) * 0.075 if flying else 0.0
	art.pivot_offset = _visible_art_rect().get_center()
	art.scale = reaction_scale * (1.0 + approach * 0.12)
	art.position = rest_position + Vector2(0, -hover * 60 + approach * 18)
	flat_flash.size = art.size
	if world_art:
		world_art.scale = Vector3(reaction_scale.x, reaction_scale.y, 1) * (1.0 + approach * 0.12)
		world_art.position = world_rest + Vector3(0, hover - approach * 0.16, approach * 0.4)
		# Squash around the visible body's center rather than its padded canvas.
		var center_y: float = (288.0 - world_art.source_bounds.get_center().y) * world_art.pixel_size
		world_art.position.y += center_y * (1.0 - world_art.scale.y)
		if shadow:
			if presentation:
				shadow.mesh.size = presentation.shadow_size * world_art.pixel_size
				var offset: Vector2 = presentation.shadow_offset * world_art.pixel_size
				var ground_offset := Vector3(offset.x, -0.005, offset.y + approach * 0.4)
				shadow.position = world_rest + world_art.basis.orthonormalized() * ground_offset
				shadow.material_override.albedo_color.a = presentation.shadow_opacity
			shadow.scale = Vector3.ONE * (1.0 - hover * 0.45)

func reset_feedback() -> void:
	effect_popups.clear()
	queue_redraw()
	_feedback_paused = false
	_paused_tweens.clear()
	for tween: Tween in [hit_tween, strike_tween]:
		if tween and tween.is_valid():
			tween.kill()
	reaction_scale = Vector2.ONE
	approach = 0.0
	flash_color = Color(1, 1, 1, 0)
	defeated = false
	hover_time = 0.0
	art.modulate = Color.WHITE
	art.visible = world_art == null
	hit_particles.emitting = false
	hit_particles.speed_scale = 1.0
	death_pixels.clear()
	death_pixels.paused = false
	if world_art:
		world_art.modulate = Color.WHITE
	_sync_world_visibility()
	_apply_pose()

func play_strike(speed: float = 1.0) -> Tween:
	if strike_tween and strike_tween.is_valid():
		strike_tween.kill()
	strike_tween = create_tween().set_speed_scale(speed)
	strike_tween.tween_property(self, "approach", 1.0, 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	strike_tween.tween_property(self, "approach", 0.0, STRIKE_SECONDS - 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return strike_tween

func play_hit(flash_enabled: bool, speed: float = 1.0, lethal: bool = false) -> Tween:
	hit_started.emit()
	if hit_tween and hit_tween.is_valid():
		hit_tween.kill()
	reaction_scale = Vector2.ONE
	flash_color = Color(1, 1, 1, 0)
	hit_tween = create_tween().set_speed_scale(speed)
	hit_tween.tween_property(self, "reaction_scale", Vector2(1.14, 0.88), hit_rise_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if flash_enabled:
		hit_tween.parallel().tween_property(self, "flash_color", Color.WHITE, hit_rise_seconds * 0.65)
	hit_tween.tween_property(self, "reaction_scale", Vector2(0.9, 1.12), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if flash_enabled:
		hit_tween.parallel().tween_property(self, "flash_color", Color(0.95, 0.12, 0.14, 0.85), 0.09)
	hit_tween.tween_property(self, "reaction_scale", Vector2.ONE, hit_settle_seconds - 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if flash_enabled:
		hit_tween.parallel().tween_property(self, "flash_color", Color(0.95, 0.12, 0.14, 0), hit_settle_seconds - 0.09)
	if lethal:
		hit_tween.tween_callback(_disintegrate.bind(speed))
		hit_tween.tween_interval(DEATH_SECONDS)
	return hit_tween

func _disintegrate(speed: float) -> void:
	_apply_pose()
	var bounds: Rect2 = screen_bounds.call() if world_art else Rect2(art.global_position + _visible_art_rect().position, _visible_art_rect().size)
	# Pixel positions are in viewport space; keep this effect independent of card placement.
	death_pixels.global_position = Vector2.ZERO
	death_pixels.burst(art.texture, bounds, speed)
	death_started.emit()
	defeated = true
	if world_art:
		world_art.hide()
		shadow.hide()
	else:
		art.hide()

func _visible_art_rect() -> Rect2:
	if art.texture == null:
		return Rect2(Vector2.ZERO, art.size)
	var texture_size: Vector2 = art.texture.get_size()
	var fit_scale: float = minf(art.size.x / texture_size.x, art.size.y / texture_size.y)
	var inset: Vector2 = (art.size - texture_size * fit_scale) * 0.5
	if bounds_texture != art.texture:
		bounds_texture = art.texture
		source_rect = Rect2(art.texture.get_image().get_used_rect())
	return Rect2(inset + source_rect.position * fit_scale, source_rect.size * fit_scale)

func set_feedback_paused(value: bool) -> void:
	if _feedback_paused == value:
		return
	_feedback_paused = value
	death_pixels.paused = value
	if value:
		for tween: Tween in [hit_tween, strike_tween]:
			if tween and tween.is_valid() and tween.is_running():
				tween.pause()
				_paused_tweens.append(tween)
	else:
		for tween: Tween in _paused_tweens:
			if tween and tween.is_valid():
				tween.play()
		_paused_tweens.clear()
	if value:
		_particle_speed = hit_particles.speed_scale
		hit_particles.speed_scale = 0.0
	else:
		hit_particles.speed_scale = _particle_speed
