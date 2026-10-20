# Inventory items

Each item owns a folder directly under `assets/items/`, named with underscores.
Each item uses its current individual image; obsolete shared atlas fallbacks are no longer required.

- `README.md`: the item description and existing design notes.
- `item.tres` and supporting `.tres` files: authored gameplay definitions.
- `status_ability.tres` and `apply_<status>.tres`, where present: concrete status
  grants used by activation calculations. These amounts have one owner in the
  effect Resource and are not repeated in `base_stats`.
- `item.json` or `metadata.json`: structured identity, design and art records.
- `art/item.png`: the current in-game image, unchanged in size and pixels.
- `art/item.pixloom.json`: the matching editable JSON source, when one exists.

The former category folders were flattened. Category membership and stable gameplay
IDs remain defined by content records. The former `icons/art/` folders are now
`art/`. Active art folders are flat. Superseded versions and other native projects
are retained in verified ZIPs under `workspace/archives/items/`, outside runtime
assets. Image-only items have no fabricated source. Godot's `item.png.import`
sidecar preserves import settings and resource identity.

`PackArt.item()` loads PNGs with the existing footprint dimensions and view-size
selection. No sprites were resized or redrawn. Native sources remain editable.
`manifest.json` indexes metadata; collectible discovery recursively loads
`item.tres`. See [content resources](../README.md#authored-content-resources) for the content graph.

File moves and artwork hashes from the prior cleanup are recorded in
`workspace/tasks/asset_cleanup/migration.json` at the project root.

Bonus abilities and effects now live beside each item: `adjacency_*`, `primary_*`,
`quiver_*`, `momentum_*`, `mechanic_*` and `volley_*` records where applicable.
Edit target conditions, enum-keyed stats and amounts there; compatibility dictionaries
no longer own these bonus values. Volley arrow choices and upgrades also use their
own concrete records. Runtime views are rebuilt from the definitions on save resume.
