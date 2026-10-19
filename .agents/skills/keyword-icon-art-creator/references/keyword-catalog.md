# Combat keyword catalog and shared color contract

The original twelve-icon family is accepted; the user-requested v2 redraw and
eleven additions form a 23-icon active revision for review. The
runtime authority is `assets/ui/keyword-icons/registry.json`, resolved through
`PackKeywords` and `PackKeywordLinks.rich()`. Use that registry for current labels,
aliases, colors and mask paths. Icons precede their words with a nonbreaking gap.
The user's latest mapping makes Accuracy the concentric bullseye and Crit chance
a rising diagonal arrow with an upper-right corner guide (effects-v3 sources).
Tables below preserve the original design brief; current Block is a shield,
Mana a blue gem and Slow a snowflake. Damage and Cleanse now have artwork.
The nine future-stat identities have no new mechanics or definitions. Reread current combat
code before changing meanings; the registry does not change game rules.

## Current mechanics and compatibility

`scripts/keyword_links.gd` decorates linked terms with accepted inline icons;
passive consumers use the same formatter with links disabled.
Its `armor` entry has the title **Shield**, and aliases `shield`, `shields` and
`armor` resolve to that entry. `scripts/run_state.gd` stores enemy capacity in
`enemy["armor"]` and spends it as a shield pool. Player shields generate block;
block is a shared pool for incoming strikes and normally expires each turn.
`plating` reduces every strike before block; it is not that shield pool.

Maintain two layers: canonical art IDs express the intended displayed meaning;
a legacy adapter expresses how today's keyword/game fields map to them.

- `glossary:armor` and `enemy.armor` -> `stat.shield` / `keyword.shield`.
- `glossary:block` and the player's block amount -> `stat.block` / `keyword.block`.
- `glossary:plating` -> `stat.plating` / `keyword.plating`.
- `equipment.armor` is a distinct **armor/equipment visual identity requested by
  the user**, not a newly implemented statistic. Use only when content actually
  means worn armor. Do not reinterpret all existing `armor` text automatically.
  If the user later defines a distinct Armor mechanic, bind it explicitly.

Thus a displayed legacy shield concept retains its shield symbol even if its
internal key is `armor`; an actual armor noun can receive the breastplate symbol
through typed context. Ambiguous free text needs its meaning resolved before
icon insertion. Never make one alias silently choose two mechanics.

## Starter catalog

Colors are **proposed resolved text/icon colors**. Most reuse current keyword definitions
hues so the new system can preserve existing visual associations. Distinct
defensive concepts may share the blue family; shape and label carry their exact
meaning. The armor hue is new, not live. Verify contrast per theme before use.

| Stable icon ID | Display label / terms | Color token | Hex proposal | Shape cue |
| --- | --- | --- | --- | --- |
| `equipment.armor` | Armor; context-bound equipment noun | `keyword.armor` | `#C1CAD6` | Breastplate with shoulder openings; no shield outline |
| `stat.health` | Health, HP | `keyword.health` | `#F2868F` | Solid heart with clear center cleft |
| `stat.block` | Block | `keyword.block` | `#85BAF0` | Wide barrier/guard plate with short bracing foot; unlike pointed shield |
| `stat.shield` | Shield, shields; legacy keyword armor | `keyword.shield` | `#85BAF0` | Pointed heraldic shield with one open inset |
| `effect.poison` | Poison | `keyword.poison` | `#A5C976` | Droplet with a compact negative-space poison mark |
| `effect.burn` | Burn | `keyword.burn` | `#EDB172` | Asymmetric flame with one open inner tongue |

Suggested extensions, only author when requested or needed:

| Stable icon ID | Label / supported alias | Token | Hex proposal | Distinct shape |
| --- | --- | --- | --- | --- |
| `stat.plating` | Plating | `keyword.plating` | `#85BAF0` | Two overlapping horizontal plates |
| `stat.damage` | Damage, direct damage | `keyword.damage` | `#F2868F` | Single blade/slash; distinct from action.attack |
| `stat.healing` | Healing, regeneration | `keyword.healing` | `#A5C976` | Plus with paired leaf or heart notch |
| `stat.mana` | Mana | `keyword.mana` | `#8BCFDA` | Angular four-point crystal |
| `stat.ward` | Ward | `keyword.ward` | `#B99ADE` | Open diamond ward, different from shield |
| `effect.curse` | Curse | `keyword.curse` | `#B99ADE` | Broken ring or hooked sigil |

These are proposed motif directions, not copies of the reference screenshots or
approved artwork. At 12 px, retain the outer identity and simplify interior
marks instead of squeezing all details into the cell. Poison must not become
indistinguishable from water/mana; avoid making every effect a diamond or spark.

## Registry handoff

Production authority: `assets/ui/keyword-icons/registry.json`.
Modify it only as part of an asset/integration request, not merely because
this skill exists.
Keep palette, terms and adapters in this single authority; generate Godot/theme
adapters and colored PNGs from it instead of copying independent constants.

Minimum shape (paths and offsets below are illustrative, not existing assets):

```json
{
  "schema_version": 1,
  "status": "proposed",
  "palette": {
    "keyword.health": { "default": "#F2868F" }
  },
  "keywords": {
    "health": {
      "label": "Health",
      "aliases": ["health", "HP"],
      "icon_id": "stat.health",
      "color_token": "keyword.health",
      "placement": "before-keyword",
      "meaning": "Current or maximum hit points, resolved from context"
    }
  },
  "icons": {
    "stat.health": {
      "status": "candidate",
      "variants": {
        "16": {
          "source_json": "health-16.sprite.json",
          "export_svg": "health-16.svg",
          "mask_png": "health-16-mask.png",
          "canvas": [16, 16],
          "baseline_offset_px": 0,
          "gap_px": 2
        }
      },
      "provenance": { "method": "spritex-json", "reference_paths": [] }
    }
  },
  "legacy_adapters": { "glossary:health": "health" }
}
```

Define `baseline_offset_px` as an integer screen-pixel adjustment at 1x relative
to the renderer's normal inline-image alignment; positive moves the icon down.
Record the renderer/alignment used during review. Resolve theme overrides under
the same color token (for example `menu` and `gameplay` values) only when actual
contrast requires them; both text and icon must resolve the same override.

Canonical term IDs and icon IDs stay stable when wording or translated labels
change. Aliases are language-specific and scoped to meanings, not asset filenames.
No new `effect.fire` synonym for Burn, or `armor` alias for Plating, without an
explicit mechanic/terminology decision. Keep FX token references separate from
stat values; a color relationship does not establish identical mechanics.
