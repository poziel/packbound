# Character navigation icons

Four original 32 x 32 white masks: backpack, framed gemstone relic, ascending
statistics bars, and a bound combat ledger. Each has 32 pixels of visible height.
The character tabs use the PNGs at native scale with nearest-neighbor filtering
and their existing selected, hover and unselected colors and tooltips.

Each adjacent JSON is an editable spritex schema-1 document with two meaningful
layers and one explicit static frame. JSON is the drawing authority; PNG and SVG
are spritex 0.2.0 exports. Both exports render identically in Godot.

Original authoring helper, review script, logs and actual game captures:
`workspace/docs/art/concepts/ui-icons/navigation-v4/`. The source and export files there
match this runtime set. `registry.json` records bounds and provenance.

Integrated at the user's request, pending their visual review. Earlier v3 art
and its editable sources remain intact. Reward, storage and main-menu icons
keep their existing bindings.

The graphics-enabled Godot review passed with zero failures: four tab states,
native size/visible height, SVG/PNG equality, tooltips, filtering, and the approved
attack glyph after runtime refresh. The sandbox emitted a certificate-store
warning; local rendering and asset checks completed successfully.
