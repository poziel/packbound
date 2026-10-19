# Item Art Creator handoff

Item Creator supplies a design README, item ID/kind, output folder `<definition>/icons/art/`, reference images with provenance, inventory mask/orientation or actual relic control slot, visual brief and generate/revise/reuse scope. Do not derive a relic's slot size from inventory rules. Standalone art requests retain their requested output location.

Item Art Creator returns `art-manifest.json` with this shape (null paths mean missing/deferred; arrays may contain additional variants):

```json
{
  "schemaVersion": 1,
  "id": "example_item",
  "approval": "unreviewed",
  "base": {"source": null, "png": null, "svg": null, "footprint": null},
  "variants": [],
  "provenance": null,
  "reused": [],
  "checks": []
}
```

All non-null paths are project-relative and must exist. The completed base requires layered spritex JSON, transparent PNG and integer-grid SVG; backpack items also require footprint JSON matching the gameplay mask. Provenance records references, generation or direct-authoring method and edits. A variant entry has purpose, source, png and svg paths; create variants only when the display needs them. Preserve source/export provenance honestly when reusing legacy art; do not label a flattened import as reconstructed semantic layers.

Use approval `unreviewed`, `accepted` or `rejected` only with corresponding evidence. Checks are objects with name, result (`passed`, `failed`, `not-run`) and evidence. Include source validation, export dimensions/transparency, footprint where applicable and actual UI-size visual review; do not claim checks merely because a file exists.

Item Creator maps base.png to visual.assets.icon, base.svg to visual.assets.svg, base.source to visual.assets.source, base.footprint to visual.assets.footprint, and includes manifest/provenance paths. Copy returned variants. Verify the ID and paths before updating item.json; preserve untouched exports on partial revisions. New art does not authorize acceptance or registration in runtime texture tables.
