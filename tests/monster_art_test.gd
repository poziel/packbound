extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var seen: Dictionary = {}
	var card: Control = load("res://scenes/game/enemy_card.tscn").instantiate()
	root.add_child(card)
	await process_frame
	var art: TextureRect = card.get_node("EnemyArt")
	check(art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Monster art explicitly uses nearest filtering")
	check(art.size == Vector2(240, 220), "Authored battle art slot remains 240x220")
	for enemy: Dictionary in PackCatalog.enemies():
		var key: String = enemy["key"]
		var texture: AtlasTexture = PackArt.enemy(key)
		check(texture.atlas != null, key + " has a texture")
		check(texture.region == Rect2(0, 0, 288, 320), key + " retains shared full-canvas registration")
		check(not seen.has(texture.atlas.resource_path), key + " has distinct artwork")
		seen[texture.atlas.resource_path] = true
		var image: Image = texture.atlas.get_image()
		var bounds := image.get_used_rect()
		check(bounds.size.x > 0 and bounds.size.y > 0, key + " has visible pixels")
		check(bounds.position.x > 0 and bounds.end.x < 288 and bounds.position.y > 0 and bounds.end.y < 320, key + " has transparent margins")
		# Verify actual SVG import at native density against the PNG used in battle.
		var svg: Texture2D = load("res://assets/enemies/%s.svg" % key)
		var svg_image := svg.get_image()
		image.convert(Image.FORMAT_RGBA8)
		svg_image.convert(Image.FORMAT_RGBA8)
		check(image.get_size() == svg_image.get_size(), key + " SVG and PNG share native dimensions")
		check(image.get_data() == svg_image.get_data(), key + " SVG and PNG render identical pixels")
		art.texture = texture
		var scale_factor: float = minf(art.size.x / 288.0, art.size.y / 320.0)
		check(is_equal_approx(scale_factor, 0.6875), key + " uses the common roster scale")
		var shown_top := art.position.y + bounds.position.y * scale_factor
		var vitals: Control = card.get_node("Vitals")
		check(shown_top > vitals.position.y + vitals.size.y, key + " clears health bars")
		var expected_rect := Rect2((art.size - Vector2(288, 320) * scale_factor) * 0.5 + Vector2(bounds.position) * scale_factor, Vector2(bounds.size) * scale_factor)
		check(card._visible_art_rect().is_equal_approx(expected_rect), key + " feedback bounds follow visible anatomy")
		card.play_hit(false)
		check(card.get_node("HitParticles").position.is_equal_approx(art.position + expected_rect.get_center()), key + " hit particles appear on the creature")
		check(art.pivot_offset.is_equal_approx(expected_rect.get_center()), key + " hit scale pivots around the creature")
		card.reset_feedback()
	check(seen.size() == 20, "All twenty catalog monsters have individual assets")
	var rat_size := PackArt.enemy("ash_rat").atlas.get_image().get_used_rect().size
	var boss_size := PackArt.enemy("zippered_maw").atlas.get_image().get_used_rect().size
	check(rat_size.x < boss_size.x / 2 and rat_size.y < boss_size.y / 2, "Rat stays visibly smaller than the boss")
	card.free()
	print("MONSTER ART RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
