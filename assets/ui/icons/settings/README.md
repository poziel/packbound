# Settings tint mask

The 32 x 32 gear preserves the exact alpha silhouette of the gear at x=128 in
`themes/gameplay/controls.svg`, including its even-odd fill rule. The
original gold atlas remains intact. This white mask lets the shared IconButton
theme apply its state color once, avoiding the previous gold-on-gold darkening.

`settings.json` is the spritex schema-1 editable authority: one silhouette layer,
one static frame. `settings.png` and `settings.svg` are spritex 0.2.0 exports.
The glyph is a single editable shape, not a reconstruction of separate parts.

The application frame uses the PNG with nearest-neighbor filtering. The rendered
`tests/integration/ui_polish_test.gd` review verifies exact alpha equality with the original
gear and white RGB for every opaque pixel.
