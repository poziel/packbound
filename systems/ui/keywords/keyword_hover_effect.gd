extends RichTextEffect
## Tint glyphs without rebuilding the label's link hit-test layout.
var bbcode: String = "keyword_hover"
var hovered: String = ""
var font_size: int = 24
var fragments: Dictionary = {}
var _capture_frame: int = -1

static func annotate_links(text: String) -> String:
	var urls := RegEx.new()
	urls.compile("(?s)(\\[url(?:=| href=)([^ \\]]+)[^\\]]*\\])(.*?)(\\[/url\\])")
	var matches: Array[RegExMatch] = urls.search_all(text)
	matches.reverse()
	for found in matches:
		var contents: String = found.get_string(3)
		var leading_image := RegEx.new()
		leading_image.compile("^(?:\\[color[^\\]]*\\])*\\[img")
		var leading: int = 16 if leading_image.search(contents) else 0
		var annotated: String = "%s[keyword_hover id=%s#%d leading=%d]%s[/keyword_hover]%s" % [found.get_string(1), found.get_string(2), found.get_start(), leading, contents, found.get_string(4)]
		text = text.left(found.get_start()) + annotated + text.substr(found.get_end())
	return text

func invalidate_geometry() -> void:
	fragments.clear()
	_capture_frame = -1

func trigger_fragments(id: String) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for rect: Rect2 in fragments.get(id, {}).values():
		result.append(rect)
	return result

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var id: String = str(char_fx.env.get("id", ""))
	# Capture native shaped positions once per layout, without reparsing BBCode
	# or doing font-metric work every frame for long inspection chains.
	if not char_fx.outline and char_fx.font.is_valid():
		var frame: int = Engine.get_frames_drawn()
		if _capture_frame < 0:
			_capture_frame = frame
		if _capture_frame == frame:
			var server: TextServer = TextServerManager.get_primary_interface()
			var baseline: Vector2 = char_fx.transform.origin + char_fx.offset
			var ascent: float = server.font_get_ascent(char_fx.font, font_size)
			var height: float = ascent + server.font_get_descent(char_fx.font, font_size)
			var width: float = server.font_get_glyph_advance(char_fx.font, font_size, char_fx.glyph_index).x
			var rect := Rect2(baseline - Vector2(0, ascent), Vector2(maxf(1, width), height))
			if char_fx.relative_index <= 2:
				var leading: float = float(char_fx.env.get("leading", 0))
				rect.position.x -= leading
				rect.size.x += leading
			if not fragments.has(id): fragments[id] = {}
			var line: int = roundi(baseline.y)
			fragments[id][line] = fragments[id][line].merge(rect) if fragments[id].has(line) else rect
	if id == hovered:
		char_fx.color = char_fx.color.darkened(0.28)
	return true
