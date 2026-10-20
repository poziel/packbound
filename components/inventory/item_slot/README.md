# Item sockets

Shared appearance comes from the active theme. Inspector appearance values become
explicit per-instance overrides when set. **Reset Appearance to Theme** restores
inheritance. Behavior/content properties remain on the node. See
[theme settings and previews](../../themes/README.md).

Shared framing for the backpack, stash, relics and character portraits.
A two-pixel segmented outline follows the occupied mask, with stepped rounded
outer and inward corners and a genuinely transparent one-pixel gap before the plain face. Shared
cell edges disappear; empty cells and enclosed holes remain open. There are no
shadows or interior ornaments. Hover and focus brighten the same outline.

## Numbered tile variant

Instance `numbered_item_slot.tscn` and set its Inspector `corner_number` (1–9).
Set it to 0 for the plain tile: both the compartment and number disappear.
The same optional property is available on `item_slot.tscn`; empty sockets
always hide it. Run `numbered_tile_demo.tscn` (F6) to compare none, 1 and 9.

The 18 × 20 px compartment shares the tile's accent, hover rim, face and font,
with stepped rounded top-left and bottom-right corners. Its foreground draws
after the `Art` child, so item artwork cannot cover the number. Backpack masked
items call the same `FRAME.draw_priority_corner` renderer at their topmost,
leftmost occupied cell, including after rotation. The component is presentational;
backpack Ctrl-left/right-click cycling and combat priority belong to the consumer.

## Replaceable border segments

Set `border_segments` on an item slot or character preview. For backpack items,
call `board.set_item_border_segments(item_id, segments)`. These are presentation
settings, not new gameplay mechanics or automatically persisted item state.
Call the setter again (or `queue_redraw`) after changing a dictionary in place.

```gdscript
slot.border_segments = [{
    "cell": Vector2i.ZERO,
    "side": "bottom",
    "kind": "caret_up",
    "color": Color("c0df79"),
    "length": 9,
}]
```

`FRAME.segments(points, cell_size, gap)` lists available sockets. Each identifies
an exposed `cell` and `side` (`top`, `right`, `bottom`, `left`), including edges
facing enclosed holes. IDs refer to the **displayed, rotated mask**; callers
update them when rotation changes. Internal edges are never valid sockets.
Consecutive exposed edges merge into one straight segment; there are no breaks
at cell joins. Any member cell can address that segment. Use at most one
replacement per merged segment. Each replacement clears a centered
length of the normal outline (default 9 pixels, clamped to the straight segment).
The small breaks at the segment ends remain transparent.

Instead of `kind`, supply `texture: Texture2D` for a native-size centered symbol,
or `draw: Callable` with `(canvas, rect, color, socket)` to draw custom content.
The callback runs during `_draw`; `rect` is the cleared two-pixel border region,
and `socket` includes the cell, side, member `cells` and full straight segment rectangle. Custom
art may extend beyond `rect`; keep it compact to avoid covering item art or
neighboring slots. The built-in upward caret occupies seven by five pixels.
No replacement is assigned to real items until a gameplay meaning is defined.
Cached masks depend on shape and cleared regions, not hover colors or callbacks.

## Integration

- Instance `item_slot.tscn` for a square socket. Set `occupied`, `accent`, and
  `Art.texture`. The icon stays centered with nearest-neighbor filtering.
- `scenes/run/inventory/storage_slot/storage_slot.tscn` inherits the socket and adds the small footprint
  preview. Its parent handles dragging and paging.
- Backpack empty cells attach `item_slot.gd` directly to their saved panels.
  Occupied shapes use `item_frame.gd` from `backpack_board.gd`, so their entire
  silhouette shares the same perimeter treatment, without internal cell rims.
- Relics use the scene with a warm metal accent. Empty slots stay blank and do
  not enter keyboard focus or show placeholder tooltips. Filled slots retain
  inspection, and consumed relics retain their dimmed icon.

The `Panel` is presentational: connect `gui_input` or register it with the
inspector in the consuming screen. Hover and keyboard focus brighten occupied
frames immediately; geometry and positions stay fixed.

## Relic layout

`scenes/run/character/tabs/relics/relic_grid.gd` keeps six columns, six-pixel spacing and even integer
slot sizes. It shows as many complete rows as the page fits. The standard page
uses 84 x 84 slots in seven rows; larger or smaller pages recompute the layout.
The 42 standard slots are saved in `character_panel.tscn`. Extra capacity is
created only when a larger page requires it, and hidden again when it shrinks.
The number of relic rewards per run is unchanged.

## Preview and verification

`border_color` overrides only the frame and numbered-corner rim. Transparent
inherits the normal accent/rarity rim. Set `Color.TRANSPARENT` to clear an
override; the tile fill and artwork keep their original colors. Backpack
synergy hover uses the shared frame renderer's `SYNERGY_COLOR` (the yellow-beige
caret color), then restores the rarity rim when the related trigger is left.

Occupied item and relic hover brightens the rarity accent by 18% through the
shared renderer, including numbered corners and gravity-stash footprints.
The backpack also draws board-space stars around a hovered bonus supplier:
muted gray outlines at 45% opacity for potential contacts, solid yellow when the
occupant receives its bonus.
Stars follow snapped placement and rotation, honor adjacency relics, and disappear
outside valid board previews. `backpack/synergy_preview.gd` reads copied placement
records and the run's adjacency/bonus rules without committing moves.

Run `components/inventory/item_slot/segmented_frame_demo.tscn` (F6) for 32 px irregular
masks, a hollow mask, a bottom caret and a custom side marker at 64 px.
The larger donut shows carets on both outer sides and the bottom edge of its
hole; the stair shape shows a caret and a custom right-side marker. A rendered
example sheet is saved at `workspace/tasks/test-organization/previous-output/segmented-frame-examples.png`.
`pwsh -NoProfile -File tests/run_tests.ps1 -Suite all -Test segmented_frame` checks
transparent spacing, holes, joined cells, replacement cuts and callback execution.
It writes `workspace/tasks/test-runs/<run-id>/<test-id>/segmented-frame-review.png`, a native-size mask sheet.


Run `pwsh -NoProfile -File tests/run_tests.ps1 -Suite all -Test item_grid_style -Render` to render
the three integrated surfaces and check layout resizing, empty/filled states,
hover inspection, consumed relics and centered artwork. Screenshots are saved as
`workspace/tasks/test-runs/<run-id>/<test-id>/item-grid-backpack.png`, `item-grid-storage.png` and
`item-grid-relics.png`. The existing backpack geometry, swaps and storage-input
tests cover the corresponding interaction paths.
