# Delver assets

Each stable Delver ID owns one folder with `README.md` (design brief), `character.json` (structured profile), `concept/` (supplied visual references) and `art/` (current generated artwork and editable sources).

| ID | Delver | Profile |
| --- | --- | --- |
| warrior | Garran Vale — The Last Watch | [Profile](warrior/README.md) |
| ranger | Rowan Thorne — The Wayfinder | [Profile](ranger/README.md) |
| mage | Mira Vey — The Twin Ember | [Profile](mage/README.md) |
| assassin | Sable Rook — The Dusk Runner | [Profile](assassin/README.md) |
| necromancer | Odran Morrow — The Keeper of Names | [Profile](necromancer/README.md) |

Current sprite and portrait exports live directly in each `art/` folder with stable names, beside native spritex JSON, provenance and a handoff manifest. Godot `.import` sidecars stay beside their images. No artwork was redrawn during consolidation.

The [acceptance registry](../../workspace/docs/art/characters/accepted.json) preserves per-Delver approval and output hashes; the [profile catalog](../../workspace/docs/art/characters/catalog.json) is documentation data, not a runtime loader. Original source/review details are retained in each art provenance record and the verified prior-layout ZIP.

[Character archives](../../workspace/archives/characters/) contain retained ZIP snapshots, excluded from Godot import by `workspace/.gdignore`. Superseded versions, draft sources, legacy shared portraits/sources and the prior root layout are preserved there. Historical paths inside original provenance records describe their original location; consult the ZIP for those files.

The game still defines classes in code. Moving assets does not migrate class gameplay to `character.json`.
