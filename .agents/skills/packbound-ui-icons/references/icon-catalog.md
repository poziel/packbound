# Menu and action catalog

These are stable proposed keys and starting motifs, not a claim that the assets
already exist or are approved. Keep a key stable when refining its drawing.

| Key | Meaning | Suggested motif / distinction | Default source |
| --- | --- | --- | --- |
| `menu.backpack` | Packed inventory | Satchel with flap and a clear strap; avoid the reward coffer silhouette | 24 x 24 |
| `menu.relics` | Owned/equipped relics | One bound rune crystal or talisman with a simple central cutout | 24 x 24 |
| `menu.statistics` | Run/character statistics | Three uneven bars on a shared baseline | 24 x 24 |
| `menu.logs` | Combat/event log | Page or narrow ledger with two readable line cuts | 24 x 24 |
| `menu.pause` | Pause run | Two substantial vertical bars, equal weight and spacing | 24 x 24 |
| `menu.on-use` | Menu for actively usable items | Hand holding a small item, or a small flask with one activation cue; establish actual menu semantics first | 24 x 24 |
| `reward.relic` | Choose/claim a reward relic | Same relic motif held above a shallow cradle/open hand; silhouette differs from owned relics | 32 x 32 |
| `reward.items` | Choose/claim item rewards | Open coffer with readable lid and cavity; distinct from packed satchel | 32 x 32 |
| `action.block` | Manual defensive action | Braced shield with a readable guard edge; use a defensive pose cue if needed | 32 x 32 |
| `action.spell` | Cast spell | Angular casting spark held above a simple palm or an open casting tome; choose one cohesive glyph | 32 x 32 |
| `action.attack` | Attack | One strong diagonal blade or two crossed blades with clean separated tips/hilts | 32 x 32 |

"Choose relic" and "relic reward" refer to the same control unless the current
UI exposes separate operations. Do not create duplicate icons for alternate
phrasing. An on-use menu is not automatically the existing unused-item storage:
storage holds unpacked inventory, and the current game activates packed items
automatically. Preserve that distinction; do not invent new mechanics while
making an icon. If both menus exist, use separate keys and clearly different motifs.

Armor (equipment), shield (protection pool), and block (per-turn defense) also
need distinct meanings. The companion keyword catalog owns those definitions
and their tooltip mapping. This UI catalog owns action/menu affordances only.

## Current implementation evidence

Verified while this skill was authored; recheck before integration:

- `assets/navigation/statistics.svg`, `record.svg`, `relics.svg`, and `storage.svg`
  supply existing navigation art. Several are white 24 px masks.
- `themes/gameplay/theme.tres` sets `TabContainer/constants/icon_max_width`
  to 24, selected/hover/unselected icon tints, and Button icon maximum to 32.
- `scenes/game/character/character_panel.tscn` binds existing tabs; Pause currently
  uses text `II`. Replacing it with art must retain its accessible Pause meaning.
- `scenes/game/battle_area.tscn` requests 32 px reward icons in 56 x 48 controls,
  with a separate availability badge; storage uses a 24 px icon. Read
  `assets/navigation/REWARD_ICONS.md` to preserve existing provenance and behavior.
- `scenes/game/action_frame.tscn` contains Attack, Spell, and Block controls.
  Spell and Block are disabled; `scripts/keyword_links.gd` and `scripts/main.gd`
  explain that packed spells/shields currently act during Attack. Art must not
  imply that generating these glyphs implements those manual actions.
- `scripts/pack_art.gd` has a legacy control atlas with 32 px regions;
  `scripts/pack_ui.gd` may cap icons at 24. Inspect consumers before reuse. A
  texture's atlas region size does not establish its actual visible glyph density.

No UI art should be routed through the inventory footprint/96 px item-atlas
pipeline. Inspect Godot imported raster dimensions as well as SVG viewBox and
display scale; `crispEdges` alone does not guarantee the final screen sampling.

## User references

Read these as visual inspiration for compact motifs, separate button surfaces,
and icon-led navigation. Their dark/low-contrast palette is not the production
contrast target. The adjacent provenance file records original sources.

- [Menu reference](../../../../workspace/docs/art/references/ui-icons/menu-reference.png)
- [Action reference](../../../../workspace/docs/art/references/ui-icons/action-reference.png)
- [Single button reference](../../../../workspace/docs/art/references/ui-icons/button-reference.png)
- [Source provenance](../../../../workspace/docs/art/references/ui-icons/provenance.json)
