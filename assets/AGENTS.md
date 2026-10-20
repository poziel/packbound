# Production asset ownership

- Group `assets/` by purpose and content identity: characters, enemies, items, relics, backgrounds, icons, branding, fonts, shaders and audio/music.
- Keep accepted editable sources, exports, definition records and provenance in the owning active asset folder. Preserve stable IDs and existing formats during folder-only changes.
- All audio uses `assets/audio/`: `music/`, `ambience/`, `sfx/` and the shared bus layout. Inspect local READMEs before adding material.
- Concepts, review candidates, screenshots, backups and superseded revisions belong in `workspace/`. Exploring art does not accept it as a runtime replacement.
- Do not redraw, rescale or replace accepted artwork during organization work. Detailed art contracts and creator-skill guidance will be revised separately.
- Item art folders are flat: `item.png` plus optional matching `item.pixloom.json` and Godot's image import sidecar. Keep the image currently used by the game; archive superseded art and other source formats in a verified ZIP under `workspace/archives/items/`. Do not infer the active artwork from revision numbering or fabricate a missing editable source.

Read the owning content README and applicable creator skill before changing content or art. This guide defines placement; check artwork dimensions and visual contracts against current task instructions and creator skills.
