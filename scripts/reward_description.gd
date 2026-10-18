extends RichTextLabel
## Keep the card concise; its registered inspector supplies the full description.

const MAX_LINES: int = 3
var full_description: String = ""

func _ready() -> void:
	resized.connect(_refresh_description)

func set_description(value: String) -> void:
	full_description = value
	_refresh_description()

func _refresh_description() -> void:
	if not is_node_ready() or size.x <= 0:
		return
	text = PackKeywordLinks.rich(full_description, "", false)
	if get_line_count() <= MAX_LINES:
		return
	# Measure the actual rich text, including keyword icons, at the current width.
	# Reformat raw prefixes so truncation never leaves a broken BBCode tag.
	var low: int = 0
	var high: int = full_description.length()
	while low < high:
		var middle: int = (low + high + 1) / 2
		text = PackKeywordLinks.rich(full_description.left(middle).strip_edges() + "…", "", false)
		if get_line_count() <= MAX_LINES:
			low = middle
		else:
			high = middle - 1
	var prefix: String = full_description.left(low).strip_edges()
	var boundary: int = prefix.rfind(" ")
	if boundary > 0 and low < full_description.length() and full_description[low] != " ":
		prefix = prefix.left(boundary)
	text = PackKeywordLinks.rich(prefix.trim_suffix(".").trim_suffix(",") + "…", "", false)
