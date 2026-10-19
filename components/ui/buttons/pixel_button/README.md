# Pixel button

Shared appearance comes from the active theme. Inspector appearance values become
explicit per-instance overrides when set. **Reset Appearance to Theme** restores
inheritance. Behavior/content properties remain on the node. See
[theme settings and previews](../../themes/README.md).

Reusable Godot `Button`, inspired by the supplied Megaloot references: stepped
edges, an inset tinted face, a thin highlight, a violet lower rim, and subtle
horizontal texture. The frame is generated from the silhouette; no source art
from Megaloot is included. The gallery reuses existing Packbound item/icon art.

## Files

- `pixel_button.tscn` and `pixel_button.gd`: reusable button and generated skin.
- `pixel_button_tabs.gd`: optional adapter for applying the skin to native tabs.
- `demo.tscn` and `demo.gd`: interactive gallery (run with F6).
- `pixel-button-gallery.png`: saved gallery preview.
- `tests/pixel_button_test.gd`: component behavior and serialization checks.

Script UID sidecars stay beside their scripts. Fonts and example item/icon art
remain in the shared `assets/` folder because other screens also use them.

## In Godot

1. Instance `res://components/ui/buttons/pixel_button/pixel_button.tscn` in your scene.
2. Resize the instance and set **Pixel Style → Face Color** in the Inspector.
3. Choose **Silhouette**: Stepped, Hexagon, Diamond, Mask, or Polygon.
4. Set the normal Button **Text** and/or **Icon**. Connect its `pressed` signal.

Run `res://components/ui/buttons/pixel_button/demo.tscn` with F6 for interactive examples.
The palette buttons recolor the example shapes; Equipped demonstrates toggling.
Tab/Enter and the standard Godot UI input actions work as on a regular Button.

Gameplay uses this scene for combat actions, the HUD pause control, reward choices
and inventory page arrows. Reward art and text live beneath the instance's `Content` slot.
Inventory and relic slots use the quieter, presentational
[item socket component](../item_slot/README.md).
The native character tabs use the flat styles in `themes/gameplay/theme.tres`:
the selected tab joins the panel, and inactive tabs keep a tinted face and bottom border. The optional
`components/ui/buttons/pixel_button/pixel_button_tabs.gd` adapter remains available for button-styled tabs.
Main, options, class-selection, escape and end-of-run menu buttons keep their
original appearance. The escape menu has its own original close button.

## Settings

| Setting | Use |
| --- | --- |
| `face_color` | Main tint; the shared skin derives its highlight, bevel and states. |
| `ink_color` | Text color. Icons retain their original colors. |
| `pixel_size` | Integer size of a source pixel in UI units, default 2. |
| `texture_strength` | Face scanline contrast; use 0 for a flat face. |
| `corner_cut` | Stepped rectangle corner cut in source pixels; 0 is square. |
| `shape_mask` | Equal-width `#`/`.` rows for occupied/empty regions. |
| `shape_polygon` | Simple polygon vertices in normalized 0..1 coordinates. |
| `content_region` | Normalized safe rectangle for content within the silhouette. |
| `content_padding` | Horizontal/vertical inset in UI units. |

Mask cells stretch to fit the button bounds and share one continuous frame.
For an L, use `["#.", "##"]`; for a T, `["###", ".#.", ".#."]`.
Holes are supported, for example `["###", "#.#", "###"]`.
Invalid masks/polygons fall back to a stepped rectangle and show an editor warning.
Use a simple, non-self-intersecting polygon. These are UI masks; they do not use
the inventory artwork's 32 px cell contract.

## Custom content

Enable **Editable Children** on an instance and add a layout beneath `Content`,
such as an HBoxContainer containing an icon and a VBoxContainer of labels. Set
the layout to Full Rect and clear the root Button's Text/Icon when replacing them.
The gallery's `CustomContent` instance is a saved example.

The slot receives the same padding and press offset as native text. Its children
inherit disabled mouse/focus behavior so labels and images do not intercept the
button. Keep the slot presentational: nested interactive controls belong outside
the button. Content isn't clipped to an irregular silhouette; place `content_region`
inside a filled region and keep child minimum sizes within that rectangle.

For an L's lower arm, start with `Rect2(0, 0.5, 1, 0.5)` and padding `(8, 4)`.
For a T's top arm, use `Rect2(0, 0, 1, 0.36)` and padding `(8, 4)`.

## From code

```gdscript
const PIXEL_BUTTON: PackedScene = preload("res://components/ui/buttons/pixel_button/pixel_button.tscn")

func add_attack_button(parent: Control) -> PackPixelButton:
    var button: PackPixelButton = PIXEL_BUTTON.instantiate()
    button.text = "Attack"
    button.face_color = Color("536b47")
    button.size = Vector2(320, 80)
    parent.add_child(button)
    button.pressed.connect(_on_attack_pressed)
    return button
```

Use native `disabled`, `toggle_mode`, `button_pressed`, `ButtonGroup`, tooltips,
font overrides, and focus neighbors as usual. The component owns its local Theme;
edit its exported style settings instead of assigning a Theme or frame overrides.

## Rendering and verification

The `@tool` script previews changes in the editor. Geometry and tint changes
rebuild five small textures per instance; hovering and pressing only switch the
native Button state. Generated skin resources are excluded from scene storage.
Transparent regions are excluded from pointer hit-testing, including enclosed holes.

Use integer positions and dimensions divisible by `pixel_size`, plus integer
display scaling, for consistent pixels. Odd sizes crop the last pixel block;
they do not stretch the source raster. Very thin arms can contain only the border,
so allow at least 10 source pixels across any region that should show a face.

Run `pwsh -NoProfile -File tests/run_tests.ps1 -Suite all -Test pixel_button` for the
42 checks covering input, cutout pass-through, custom content, appearance states,
instance isolation, resize, invalid-shape fallback and scene serialization.
