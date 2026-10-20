# Enemies

Each of the 56 enemy resources owns a folder named after its resource, using
underscores. Each folder contains a design `README.md`, `monster.tres` and its
supporting behavior/ability/effect resources, plus `art/` for artwork and art records.
Expansion encounter floors are stored as metadata on `monster.tres`.

The original loose enemy PNGs now live in their owning enemy's `art/` folder.
PNG exports retain their original dimensions and pixels. Editable Pixloom sources,
provenance and art metadata stay beside the exports where available. SVGs were
removed. The retained shared legacy sheet is `enemies.png`.

`systems/enemies/enemy_expansion.gd` discovers `monster.tres` resources with
`encounter_floor` metadata and adapts their stats, innate rules and ordered actions
to the existing combat profile contract. It does not read a JSON index. See each
enemy's README for design details. Stable enemy IDs and combat rules are unchanged.
