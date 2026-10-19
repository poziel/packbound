extends "res://tests/support/test_case.gd"


func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("_run")

func _run() -> void:
	var seen: Dictionary = {}
	var card: Control = load("res://scenes/run/enemy_card/enemy_card.tscn").instantiate()
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
		var svg_path: String = "res://assets/enemies/%s.svg" % key if not enemy.has("encounter_floor") else "res://assets/enemies/%s/art/%s.svg" % [key, key]
		var svg: Texture2D = load(svg_path)
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
		check(card.hit_tween != null and card.hit_tween.is_valid(), key + " hit reaction starts for the registered art")
		check(art.pivot_offset.is_equal_approx(expected_rect.get_center()), key + " hit scale pivots around the creature")
		card.reset_feedback()
	check(seen.size() == 56, "All fifty-six catalog monsters have individual assets")
	var rat_size := PackArt.enemy("ash_rat").atlas.get_image().get_used_rect().size
	var boss_size := PackArt.enemy("zippered_maw").atlas.get_image().get_used_rect().size
	check(rat_size.x < boss_size.x / 2 and rat_size.y < boss_size.y / 2, "Rat stays visibly smaller than the boss")
	card.free()
	report("MONSTER ART RESULT")
	quit(1 if failures else 0)
