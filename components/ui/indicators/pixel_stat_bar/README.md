# Pixel stat bar

Combat health bars opt into `animate_damage`: values update immediately while
the fill drops over 0.12 seconds. Lost health stays as a darker segment for one
second, then fades over 0.2 seconds. Repeated hits restart the hold; healing,
capacity changes, hiding and `clear_damage_feedback()` reset the trail.
`set_glow_paused()` pauses both the glow and health feedback.

Shared appearance comes from the active theme. Inspector appearance values become
explicit per-instance overrides when set. **Reset Appearance to Theme** restores
inheritance. Behavior/content properties remain on the node. See
[theme settings and previews](../../themes/README.md).

A reusable Godot 4 Range with stepped corners, a shaded fill and a raised
number badge. The bar draws on integer coordinates. No game state, textures,
autoloads or plugins are required.

## Use in the editor

Drag `pixel_stat_bar.tscn` into any Control scene. Resize it normally, or place it
in a Container. Set **Value**, **Max Value** and **Accent Color** in the Inspector.
The preview updates in the editor. The raised number cuts a stepped, transparent
notch out of the meter. Any background behind the component remains visible;
no matching background color or opaque badge is needed.

The complete bar includes its number label in its bounds. At the default
settings it needs 48 pixels of height; the meter itself is 28 pixels high.
Its minimum width grows to fit the largest number in the configured range.

## Use in code

```gdscript
@onready var health: PixelStatBar = $Health

func refresh_health(current: float, maximum: float) -> void:
    health.set_amount(current, maximum)

# Standard Range properties and signals are available too.
# health.value = 21
# health.max_value = 28
# health.value_changed.connect(on_health_changed)
```

In this game, `PackUI.bar(parent, rect, color)` also returns a PixelStatBar.
Player health, mana, generated block, enemy health and enemy shield are instances of the same
scene. Mana and block show current / battle capacity; their starting amount is
the initial capacity, which only grows if explicit restoration exceeds it.
These displayed capacities do not limit the resources granted by game effects.

## Appearance

| Property | Purpose |
| --- | --- |
| Accent Color | Frame, number color and derived fill shades |
| Badge Color | Legacy serialized property retained for compatibility; no longer drawn |
| Number Mode | Current / maximum, current only, percentage, or hidden |
| Number Font / Size | Custom typeface and text size |
| Decimal Places | 0–3 decimal digits; set Range Step to suit fractional values |
| Pixel Size | Border and corner step; default 2 |
| Bar Height | Meter height, excluding the raised label |
| Glow Enabled | Optional steady bright highlight; off by default |
| Glow Duration | Length of an explicit pulse; default 0.4 seconds |

Use 1-pixel steps, a 14-pixel bar and a 16-pixel font for the compact size.
The default font is crisp at integer multiples of 16. Prefer integer UI scale.
Colors can represent health, shield, mana, experience or any other resource.
Updates are immediate. Animate `value` with your own Tween if appropriate.

Bars rest with dark borders and restrained fill shading. To draw attention to
an event, explicitly request a brief highlight:

```gdscript
health.flash_glow() # Restarts the pulse if another hit arrives before it fades.
health.clear_glow() # Cancels transient feedback without changing Glow Enabled.
```

Changing values, healing or resizing does not trigger glow. The pulse changes
only the palette; it keeps the stepped border, badge and layout in place.
Hidden or removed bars clear transient feedback. Set **Glow Enabled** for a
steady highlight when a particular use needs one.

In combat, health bars pulse on resolved damage, including damage over time,
even when healing or regeneration offsets the loss in the same turn. Fully
blocked attacks do not pulse health. Mana, block and shield stay quiet. The
existing **Combat flash** setting disables these pulses too.

Values clamp to the Range by default. `set_amount()` uses a zero minimum and
normalizes negative capacity to zero. A zero-capacity bar displays `0 / 0`
with no fill. The badge reserves width for changing digits so it stays steady.
Do not edit `ValueLabel.text` directly; the component owns the displayed number.

## Preview and reuse

Open `demo.tscn` and press **F6**. Its slider and buttons adjust four resources;
full, low, empty and compact examples remain available beside them.
Use **Preview glow** to compare their temporary highlight with the resting state.

Copy this whole folder into another Godot project. Its internal references
are relative, so it can live at any path. The only global class it adds is
`PixelStatBar`. The demo is optional; the component needs only the scene,
script, bundled font resource and font license.

`pixel_font.tres` is an unchanged copy of the project's Pixel Operator Regular
resource, which embeds Jayvee Enaguas's original font. Its CC0 notice is
preserved in `PixelOperator-CC0.txt`. The geometry is drawn in code from the
user-supplied visual reference; no pixels from that image are included.

## Verification

```powershell
pwsh -NoProfile -File tests/run_tests.ps1 -Suite all -Test pixel_stat_bar
pwsh -NoProfile -File tests/run_tests.ps1 -Suite all -Test stat_bar_glow
pwsh -NoProfile -File tests/run_tests.ps1 -Suite all -Test stat_bar_cutout -Render
```

The test covers range boundaries, label modes, decimal values, resizing,
independent instances, demo controls and combat integration. Add `-Render` to save actual Godot demo and combat captures in `workspace/tasks/test-runs/<run-id>/<test-id>/`.
The glow test also checks fade/reset behavior, damage versus blocked hits,
healing/regeneration in the same turn, and the Combat flash preference.
The cutout test requires a graphics display. It checks actual rendered alpha,
compositing over different backgrounds, unchanged meter pixels beside the
notch, hidden-number mode and semantic resource-caption layout.

Health bars enable side_boxes: health / maximum is printed at the meter center, with optional protection anchored inside the right end. Both use keyword colors and black outlines; there is no plaque or reserved fill area. The fill spans the full bar and retains its health color with an added brick pattern while protected. Other meters retain their existing layout.

Health overlay borders use the same pale muted red as the health caption; health and shield text each retain a one-pixel black outline. Shield protection never recolors the health fill.
