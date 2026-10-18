# Pixel search field

Shared appearance comes from the active theme. Inspector appearance values become
explicit per-instance overrides when set. **Reset Appearance to Theme** restores
inheritance. Behavior/content properties remain on the node. See
[theme settings and previews](../../themes/README.md).

A reusable Godot 4 `LineEdit` with a recessed pixel frame, magnifier, native clear
button, selection, clipboard support and keyboard focus. Instances keep separate
queries, colors and list bindings. The pixel font is shared with the game.

## Use in the editor

1. Drag `pixel_search_field.tscn` into a Control scene or Container.
2. Set **Placeholder Text** to describe the list, such as `Search statistics...`.
3. Optionally set **List Path** to a separate VBoxContainer or GridContainer.
   Each direct Control child is one searchable row.
4. Optionally set **Empty State Path** to a Label outside that list. The field
   manages this label's visibility and recovery text.

Run `demo.tscn` with **F6** to try separate statistics and item searches.
The demo's sample rows, containers and fields are saved and editable in the scene.
The Statistics page instances this field above its scrollable stat rows.

Search matches partial words without case sensitivity. All query words must occur
somewhere in the row, in any order. Empty or whitespace-only searches restore all
eligible rows. The field searches descendant Label, Button and RichTextLabel text.
Set a row's `search_text` metadata to override that text and add hidden keywords:

```gdscript
$Rows/Dagger.set_meta("search_text", "Venom Dagger weapon poison melee")
```

Initially hidden rows remain hidden. Set `search_excluded` metadata to `true` to
exclude a row later, then call `refresh_filter()`. The bound field owns row
visibility while attached; don't attach two fields to the same container.
Added/removed rows refresh automatically. Call `refresh_filter()` after changing
row text, metadata or translated labels. Unbinding restores original visibility.
Filtering is runtime-only, so it never hides authored rows in the editor.

## Use with a data-backed list

Leave List Path empty and use the native signals with your own renderer:

```gdscript
@onready var search: PixelSearchField = $Search

func _ready() -> void:
    search.text_changed.connect(_filter_items)

func _filter_items(_query: String) -> void:
    for row in $Rows.get_children():
        row.visible = search.matches(row.get_meta("search_text", ""))

# Programmatic changes should notify listeners and refresh any bound list:
# search.set_query("poison")
# search.set_query("")
```

`results_filtered(visible_count, total_count)` supplies counts for a bound list.
`text_submitted` fires on Enter; typing filters immediately without submission.
Directly setting native `text` does not emit `text_changed`; use `set_query()`.
For large or virtualized lists, use signals to filter your data instead of nodes.

## Appearance and input

- **Surface Color**, **Accent Color**, **Ink Color** and **Pixel Size** are
  Inspector properties. Change native font/font-size overrides as needed.
- Default size is 400 x 48; it expands horizontally in Containers.
- Texture filtering is nearest-neighbor. Prefer integer display scaling.
- Click the cross or press **Esc** to clear. Esc again releases focus.
- **Tab / Shift+Tab** moves focus; **Enter** submits and keeps editing.
- The native **Editable** property provides a read-only appearance and behavior.
- It never takes focus on its own. The containing screen may call `grab_focus()`.

## Validation

```powershell
godot --headless --path . --script res://tests/pixel_search_field_test.gd
```

Omit `--headless` to save default, filtered and empty-state screenshots to
`tests/output/`. The test sends actual key and mouse events through the viewport.
