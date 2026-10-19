# Frosted panel backdrop

Instance `frosted_backdrop.tscn` as the first child of a panel, before its labels,
icons, slots, and buttons. Give the parent an empty panel StyleBox: the backdrop
draws the surface and its stepped outline. Keep foreground controls as siblings
of the backdrop so they remain sharp and opaque.

The root exposes independent `opacity`, `blur_radius`, `tint`, `corner_radius`,
and `border_width` settings in the Inspector. Materials are local to each scene
instance. A `BackBufferCopy` captures the current screen before each backdrop,
so overlapping panels see the correct background. The nine-tap blur works in
the project's OpenGL Compatibility renderer without requiring screen mipmaps.

Current surface choices:

| Surface | Opacity | Blur |
| --- | --- | --- |
| Character sheet and selected tab | 0.86 | None |
| Unused-item storage | 0.82 | 4 pixels |
| Reward and result dialog | 0.82 | 4 pixels |
| Inspection tooltip | 0.94 | None |

Character translucency is authored in `character_panel.tscn` under
`sheet_surface` and `compact_tab_selected`. Inactive tabs use
`components/ui/layout/tabs/pixel_tab_style.gd`: an opaque gray fill with eight-pixel corners
drawn in two-pixel steps. The divider in `game.tscn` is five pixels wide and
meets the left edge of the character panel.

Storage and dialog backdrops are individually editable in
`storage_inventory.tscn` and `dialogs.tscn`. Tooltip opacity lives in
`inspect_window.tscn`. The shared gameplay theme's existing general panel
translucency remains in effect for other panel surfaces.

Run `components/ui/layout/frosted_panel/tests/frosted_backdrop_test.gd` with graphics enabled to check real blur,
sharp foreground controls, independent materials, and overlapping capture.
`tests/scenes/shared/translucent_panels_test.gd` checks the application integration and saves
screenshots under `workspace/tasks/test-runs/<run-id>/<test-id>/translucent-panels/` when graphics are enabled.
