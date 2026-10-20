# Packbound assets

`assets/` holds production artwork, audio, fonts, shaders and authored game-content Resources. Content definitions and their presentation belong together under the content's owner. Screens, scene controllers and reusable components live in their own project folders; temporary research, concepts, reviews and archives belong in [workspace](../workspace/README.md).

Start with the folder map below to choose an owner. Read [AGENTS.md](AGENTS.md) before editing assets; it covers preservation, creator skills and verification. Local READMEs explain category-specific formats and behavior.

## Folder map

| Folder | What belongs here |
| --- | --- |
| [characters/](characters/README.md) | Delver identities, character/class definitions, starting equipment, sprites and portraits. |
| [enemies/](enemies/README.md) | Monster definitions, behavior, ordered attacks/effects and monster art. |
| [items/](items/README.md) | Backpack equipment: one folder per item, its definition, design notes and art. |
| `relics/` | Separate-slot relic definitions, effects, notes and art. A name containing “relic” does not determine placement: `tower_shield` is a backpack item. |
| `categories/` | Shared category Resources and parent/child classification used by rules, rewards and UI. |
| `recipes/` | Crafting recipe Resources with owned ingredient requirements and result references. |
| [status_effects/](status_effects/README.md) | Authored status policies and their referenced rule effects. |
| [loot/](loot/README.md) | Reward pool candidates, weights, unlock floors and ordered progressions. |
| [icons/](icons/README.md) | Navigation, keyword, action, control and inventory glyphs. Category layout and registry ownership are documented here. |
| [audio/](audio/README.md) | All game audio: `music/`, continuous `ambience/`, categorized `sfx/` and the shared bus layout. |
| [backgrounds/](backgrounds/README.md) | Named background packages, including the animated main-menu packing table. |
| [branding/](branding/README.md) | Game title/logo, satchel identity marks, application icons and their sources/exports. |
| `fonts/` | Bundled font files, licenses and source notes. |
| `shaders/` | Existing shader resources. Inspect consumers before editing; scene/component-specific effects follow their owner's placement conventions. |

UI themes live outside assets in [themes/](../themes/README.md). Historical migration manifests record past moves; they do not define current runtime placement.

## Content packages and artwork

Items, relics, characters and monsters use one folder per content identity. Keep gameplay definitions at that folder's root, with a README describing the design and `art/` holding active artwork. Supporting ability/effect Resources stay with their owner and are referenced rather than copied. Shared categories and recipes have their own folders because they describe relationships across content.

For items, the current flat art contract is `art/item.png`, optional matching `art/item.pixloom.json`, and Godot's image import sidecar. Preserve the image currently consumed by the game. Other content families retain their documented source/export arrangements; do not impose the item naming contract on them.

Accepted editable sources, exports and provenance stay with the active asset. An image-only asset must be described honestly; a missing editable source is not a reason to fabricate one. Creator skills define art dimensions and workflows; this overview does not duplicate those specifications. Superseded material is retained as verified ZIPs under `workspace/archives/<category>/`.

## Authored content Resources

Open [game_content.tres](game_content.tres) in Godot to inspect the content graph. It references [collectibles.tres](collectibles.tres), character/class definitions, monsters, ordered recipes, statuses, loot pools and progressions.

| Content | Canonical definitions |
| --- | --- |
| Items and relics | `item.tres` / `relic.tres`, with `rule_ability.tres` and `rule_effect.tres` where needed. |
| Delvers | `character.tres`, `character_class.tres`, starting equipment and class ability/effect Resources. |
| Monsters | `monster.tres`, `behavior.tres`, ordered actions/effects and innate ability/effect Resources. |
| Categories and recipes | `categories/*.tres`, `recipes/*.tres`; recipe ingredient requirements are owned subresources. |
| Statuses | `status_effects/<id>/status_effect.tres` and referenced `rule_effect.tres`. |
| Loot | `loot/pools/*.tres` and `loot/progressions/*.tres`; progressions reference registered pool IDs. |

Edit authored Resources directly. Character and collectible gameplay values load from these Resources; older JSON/design records are not a parallel numerical authority. Keep identity, lore and provenance records for their documented purpose. Typed owners define ordinary stats/costs; monster base attack damage comes from ordered action effects.

Classification uses the category graph and runtime `category_ids`. Consumers query category ancestors rather than a separate item-role field. Saves retain instance dictionaries; compatibility code ignores legacy role fields and translates old adjacency targets. Inspect the relevant readers and writers before changing these contracts.

`CatalogRuleEffectDefinition` binds authored parameters to existing coded rules; it is not an arbitrary-dictionary executor or generic effect interpreter. Status registration does not replace existing combat handlers. Reward rolling uses [loot_selection.gd](../systems/loot/loot_selection.gd). See the status and loot READMEs for their detailed policies.

## Discovery, refresh and exports

At runtime, [collectible_discovery.gd](../systems/content/collectible_discovery.gd) recursively discovers canonical item/relic filenames and category Resources using `ResourceLoader.list_directory`. Supporting files and artwork are not collectibles. Entries sort by display name then stable ID; type, duplicate-ID, category and graph validation must pass before publication. The runtime registry retains definitions and exposes `definition_for_key`.

In the Inspector, **Refresh From Content Folders** on `game_content.tres` discovers the full graph, validates a candidate graph and updates collections only if valid. Existing recipe priority is preserved; new recipes append in filename order. The external `collectibles.tres` reference is retained. Save affected Resources after refreshing. Definitions use readable `resource_name` values; collectible labels track `display_name`.

`collectibles.tres` is an Inspector/export dependency snapshot, not a hand-maintained runtime registration list. Its **Refresh From Item / Relic Folders** button refreshes the snapshot; save afterward. [rebuild_collectible_catalog.gd](../systems/content/tools/rebuild_collectible_catalog.gd) regenerates and saves it directly. [create_content_resources.gd](../systems/content/tools/create_content_resources.gd) refreshes catalog snapshots; the original JSON conversion is complete, and this tool does not recreate individual definitions or overwrite authored values.

Runtime collectible discovery does not require a current snapshot. For exports restricted to selected scene dependencies, refresh dependency snapshots; alternatively use a preset including all required resources. Verify the actual packaged export before claiming content is available there.

Discovery registers definitions; it does not implement unsupported abilities or offer an item as a reward. Add reward candidates to an authored loot pool and use supported behavior handlers.

## Verification

From the repository root, the focused content-graph check is:

```powershell
./tests/run_tests.ps1 -Suite systems -Test content_resources
```

Follow [test authoring](../tests/AGENTS.md) and the [runner guide](../tests/README.md) for other affected contracts. Resource loading checks, numerical tests, rendered reviews and audio playback verify different things; choose the checks appropriate to the change. Keep diagnostic logs, previews and reports in the task workspace.
