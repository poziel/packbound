# Character preview

Instance `character_preview.tscn` for a compact framed head. The default frame is
104 x 104 with the same recessed pixel edge and corner inlays as inventory slots.
Hover and keyboard focus brighten the frame immediately.

Set `texture` to a head texture or an `AtlasTexture` crop and optionally set
`accent_color`. Artwork is centered with nearest-neighbor filtering and the
largest whole-number scale that fits inside the eight-pixel padding. Small
frames downscale only when necessary. The component does not redraw source art.

`PackArt.character_head(class_key)` supplies crops of the current class artwork:
the accepted warrior/ranger portrait files and the existing SVGs for other
classes. Crop regions stay in that asset helper so replacement artwork can update
its framing independently of this reusable control.

The consumer owns the tooltip. `scenes/main.gd` registers the entire frame with
the inspector to show the class name, special power, description and live status.
No class name or ability label is displayed beside the portrait.

The player scene places this component to the left of health, mana and block.
Its compact header leaves room for the 8 x 8 backpack at the existing cell size.
Open `demo.tscn` with F6 to inspect all five class portraits, including hover and
focus styling. Run `res://tests/scenes/run/character_preview_test.gd` for integrated tooltip,
layout and eighth-row drag/drop checks.
