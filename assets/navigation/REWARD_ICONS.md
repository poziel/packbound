# Reward controls

Original editable pixel SVG artwork authored for these controls on 2026-10-15:

- `reward-item.svg`: open coffer, 32 × 32 source pixels, blue steel with a brass clasp.
- `reward-relic.svg`: bound rune crystal, 32 × 32 source pixels, pale lilac and plum with a brass retaining band.
- `reward-alert.svg`: custom exclamation glyph inside a gold stepped pennant, 12 × 20 source pixels. No font or text element is used.

All geometry uses integer source-pixel coordinates with `crispEdges`. Godot uses nearest texture filtering. Icons display at their native 32 px size, while the marker displays at its native 12 × 20 px size over the top center of each icon. These are navigation assets, independent of inventory item footprints.

Reward buttons are 56 × 48 UI units with a 6-unit gap; unused items sits 38 units after the reward pair. Item controls use blue `#384F7A`; relic controls use plum `#66406B`. Availability is shown by the custom marker and accessible descriptive labels. No pending-choice count is displayed.
