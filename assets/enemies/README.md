# Enemies

The runtime roster contains 56 enemies: 20 original opponents and [36 additional enemies](EXPANSION.md). Runs remain 20 floors, with two new encounter alternatives alongside the original opponent on each of floors 2–19. The opening Ash Rat and final Zippered Maw remain fixed.

Each new enemy folder contains an independent design README, an `enemy.json` starting-stat profile, and an `art/` folder with layered Pixloom JSON, a native `.pixloom` project, transparent PNG/SVG exports, and provenance. `expansion.json` lists the profiles consumed by the runtime loader. Profiles use the existing combat rules; legacy `armor` stores starting block, not plating.

Original individual sprites and `roster.json` retain their bytes and provenance. `enemies.svg` is a retained legacy atlas. `presentation.tres` provides editable per-enemy shadows and airborne behavior. The new art is integrated at user request and awaits artistic acceptance.

When configuring a release export, include `assets/enemies/expansion.json` and `assets/enemies/*/enemy.json` as non-resource files. Editable art sources need not be shipped in the game package.
