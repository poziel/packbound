# Current character reference direction

## Accepted Packbound anchor

The user explicitly accepted **warrior v2** on 2026-10-15. Use its
[native preview](../../../../workspace/docs/art/concepts/characters/warrior-v2/full-body@4x.png)
as the primary shared rendering reference. Its
[source and acceptance record](../../../../workspace/docs/art/concepts/characters/warrior-v2/README.md)
are preserved, and it is installed at `assets/characters/warrior/art/full-body.svg`.
New classes should share its material volume, controlled clusters and coherent anatomy
while retaining distinct head treatments, silhouettes and equipment. The human
face examples below remain relevant to characters with exposed faces.

**Ranger v2** was also accepted on 2026-10-15. Its
[native preview](../../../../workspace/docs/art/concepts/characters/ranger-v2/full-body@4x.png)
provides an accepted cloth/leather and exposed-face reference.
It is installed at `assets/characters/ranger/art/full-body.svg`; preserve its original identity
while creating other classes. Compare new work with both accepted characters.

Warrior v3 is now installed at 256 px body height, with a 64 × 64 portrait,
following the user's 2026-10-16 redraw and direct-import request. See its
[review and sources](../../../../workspace/docs/art/concepts/characters/warrior-v3/README.md).
The v2 warrior originals are archived and retained as historical references;
the current runtime warrior path contains v3. No separate visual approval of
v3 is claimed.

Both accepted v2 originals retain their original 128 px body height. New or explicitly
redrawn characters default to a 256 px body on a 384 x 320 cell; their independent
UI portraits are 64 x 64. Use the accepted original concepts as detailed
identity/material references for portrait preparation. Never interpret these
new defaults as permission to rescale or replace existing accepted artwork.

The user supplied these eight images on 2026-10-15 after rejecting the first
Pixelorama roster. Their feedback: most body/costume elements were workable,
but the overall proportions and faces were unsuccessful, and the warrior's
sword grip was unconvincing. Concealed or helmeted faces are welcome. Exposed
faces, especially close-ups, can use anime-inspired pixel art.

## Which references to use

Inspect the actual relevant files, not only these descriptions. All paths below
are in [user-direction-2026-10-15](user-direction-2026-10-15/).

| Image | Apply to | Read from it |
| --- | --- | --- |
| [01 — armored knight](user-direction-2026-10-15/01-armored-knight-flame.png) | Full-body armored figures | Coherent helmet/torso/leg relationship, articulated steel planes, a hand that supports the sword. |
| [02 — tabard knight](user-direction-2026-10-15/02-tabard-knight.png) | Armored proportions | A closed helmet integrated with substantial shoulders and torso; readable limbs, boots and layered equipment. |
| [03 — faceless hood](user-direction-2026-10-15/03-faceless-flame-hood.png) | Concealed faces and silhouette | Intentional darkness inside the hood can be the face design. The fire and halo are optional subject matter. |
| [04 — wolf-helm swordsman](user-direction-2026-10-15/04-wolf-helm-swordsman.png) | Distinctive headwear and grip | Helmet shape communicates identity; armor and cloak have mass; the hand and weapon share a convincing contact point. |
| [05 — hooded caster](user-direction-2026-10-15/05-anime-hooded-caster.png) | Visible anime face in costume | Clearly designed eyes, simple nose/mouth, strong hair silhouette and a face framed by the hood. |
| [06 — shadowed blue hood](user-direction-2026-10-15/06-shadowed-blue-hood.png) | Masked or shadowed characters | A dark face opening and sparse eye accents can replace exposed anatomy; torso and equipment stay readable. |
| [07 — anime elf portrait](user-direction-2026-10-15/07-anime-elf-portrait.png) | Detailed exposed-face close-ups | Coherent expressive eyes, simplified facial planes, small nose/mouth and organized hair highlights. |
| [08 — anime armored warrior](user-direction-2026-10-15/08-anime-armored-warrior.png) | Anime face with armor | Face and hair remain intentional beside angular armor; use this facial language without adopting the action pose by default. |

For example, a helmeted warrior can use 01/02/04; a concealed assassin can use
03/06; an exposed mage or ranger face can use 05/07/08 plus a relevant full-body
reference. Supply the selected images to image generation, or keep them available
while authoring spritex JSON. The entire set need not accompany every request.

These are style references supplied by the user, not approved Packbound asset
identities. Do not clone their faces, heraldry, equipment or composition. Their
large displayed pixels and differing image resolutions do not establish the
project's native pixel density. Keep AGENTS.md's production dimensions.

## What to carry forward

- Cohesive proportions and a purposeful silhouette; detail serves volume and
  material. Do not mechanically make every head smaller or every leg longer.
- Readable thickness, broad material shading, one or two defining details per
  major part and fewer scattered texture pixels. The additional source pixels
  support clarity, anatomy and expression rather than decorative noise.
- Armor can conceal a face completely. Identity can live in a visor, helm, hood,
  mask or nonhuman head, rather than forcing a realistic human face into each slot.
- Exposed faces use intentional anime-inspired shapes, adapted to available
  source pixels. Close-up references contain more facial information than a tiny
  full-body sprite; do not promise that simply enlarging a crop reproduces it.
- Prepare the 64 x 64 portrait from the original detailed concept, center its
  visible face/head, retain complete hair/headwear and chin, and clean intrusive
  equipment/spell fragments and awkward crop edges. A cleaned or resized
  derivative is a matching portrait, not an exact crop. Preserve identity while
  making the standalone close-up composition clearer.
- Hands actually hold equipment. Check the handle inside the grip, thumb/finger
  overlap, guard placement, wrist direction and forearm connection.
- Keep the chosen relaxed three-quarter roster pose, transparent background and
  distinct character identities. The screenshots' scenery, frames, large effects,
  action poses and oversized weapons are not automatic requirements.

The first roster is preserved at workspace/docs/art/concepts/characters/pixelorama-roster-v1/
as **rejected work**. Its correct dimensions, many editable layers and matching
PNG/SVG files did not meet the user's visual standard. Its 18–22px head heuristic
and 40px crop choice are not new universal requirements. Earlier approved
warrior/ranger concepts remain useful secondary material references where they
agree with this direction.

Original attachment paths and SHA-256 hashes are retained in
[the provenance file](user-direction-2026-10-15/provenance.json). Source authors
were not provided; do not invent credits or assert that these depict a named game.
