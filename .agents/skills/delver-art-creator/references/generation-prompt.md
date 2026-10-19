# Character art brief and generation prompt

Read [visual-direction.md](visual-direction.md) and inspect the selected images.
Fill the brief below, omitting fields irrelevant to the chosen head treatment.
Use the same brief when authoring spritex pixel grids. For an image-generation request,
submit it to the built-in tool with the selected references and transparency.
Supply references for their stated roles; never use the rejected roster as a
positive style anchor. Do not send unresolved bracketed placeholders.

~~~text
Create ONE original Packbound fantasy character, fully visible from head to toe,
on a genuinely transparent background. Its head must also read in a portrait UI.

REFERENCES
[List supplied image filenames and each role: full-body proportion/silhouette,
armor/material rendering, concealed head design, or anime-inspired visible face.]
Follow the user's current references for coherent proportions and head design.
Use their visual language, not their character identity or composition. Keep
backgrounds, frames, halos and spell effects out unless requested in this brief.

CHARACTER IDENTITY
Key and role: [key/class]
Life stage, presentation and build: [specific traits]
Head treatment: [exposed anime-inspired face / partial mask / closed helmet /
shadowed hood / appropriate nonhuman head]
Visible face, when applicable: [skin tone, head/jaw shape, deliberate eyes and
brows, simplified nose and mouth, hair silhouette, expression]
Concealed head, when applicable: [helmet/visor/crest/hood/mask silhouette and any
intentional eye accents; specify that an exposed human face is not required]
Clothing, equipment and materials: [defining features and colors]
Distinct from the other roster members through: [visible head/identity differences]
Equipment contact: [which hand holds what, handle location and angle, thumb and
finger overlap, guard position, wrist alignment; shield support where applicable]

PROPORTIONS AND POSE
Default upright relaxed stance, subtle weight shift, grounded feet, slight
three-quarter turn to the right. Integrate the head or helmet with neck, shoulders,
torso, hips and legs as one believable stylized figure. Use natural elbows and
hands appropriate to the equipment. Preserve body mass and joint connections.
Do not independently shrink the head, stretch legs, lengthen the neck or inflate
hands/boots to fit a template. Avoid both chibi and excessively lanky proportions.
The hand must wrap around the weapon handle; the weapon must not float beside an
open palm. A sword guard separates the gripping hand from the blade.

FACE AND PIXEL TREATMENT
For an exposed face, use intentional anime-inspired pixel design: clear eye and
lid shapes, coherent gaze/perspective, a simplified nose/mouth and organized hair
clusters. Adapt detail to the source resolution. Avoid muddled semi-realistic
facial shading, strange mouth/nose blobs or arbitrary misaligned eye pixels.
For a closed helmet or dark hood, preserve that concealment rather than forcing
human features into it. Distinctive headwear can carry the portrait identity.
Use stepped silhouettes and deliberate connected pixel clusters, sculpted
material planes and readable value contrast. Give armor weight, cloth volume and
leather quieter highlights. Keep detail purposeful rather than noisy or flat.
Describe readable thickness and broad shading with clean clusters; use one or
two defining details per major part rather than scattered texture pixels.
Selective colored light is optional; do not add a uniform orange/cyan outline.

PRODUCTION TARGET
384 x 320 logical cell. Visible body/headwear-to-sole height 256 px, top y32,
foot baseline y288, main body around x192. Weapons, detached effects and padding do
not count toward body height. Sword length including hilt/pommel: 128 px longsword,
85 px short sword, 64 px dagger, measured along its axis. These are source targets;
an enlarged generated concept must be separately adapted and verified on the
native grid. They are not a guarantee of anatomical or artistic quality.

OUTPUT
One complete original character, transparent surroundings, no scenery, UI frame,
text or duplicate head. Preserve the original detailed concept as the source for
a separately prepared 64 x 64 matching portrait. Keep equipment out of the
face/portrait area. Review the whole silhouette,
proportions and actual grip as well as the face at its intended display size.
~~~

## Default detailed UI portrait

First establish the character design. Prepare a 64 x 64 head-and-shoulders
derivative from its original high-detail concept, not the reduced full-body
sprite. Preserve the concept file and record the crop, resize and cleanup.
An exact, unmodified crop remains available when specifically requested. Use the
following brief for cleanup/editing of the concept crop; supply the full-body
concept as an identity reference as well:

~~~text
Prepare a clean 64 x 64 pixel-art UI portrait of THIS established character
from the supplied original concept. Center the visible face/head in the square
with balanced margins and complete hair/headwear, chin and modest neck/shoulder
context. Preserve identity, head angle, expression, costume and material colors.
Keep the eye/lid shapes, simple nose/mouth and organized hair clusters readable.
Closed helmets and intentionally concealed faces stay concealed. Remove stray
weapon tips, spell fragments, awkward cloak slivers and disconnected details
inherited from the full-body composition; repair edges and resampling artifacts.
If equipment overlaps the head, remove it and reconstruct the hidden hair, face
or headwear so the head remains complete and unobstructed. Center the head itself,
not the combined bounds of the head and nearby equipment. Intentional helmets,
masks and concealed faces remain part of the character identity.
Retain intentional identifying features. Transparent surroundings, no frame or
text. This is a cleaned concept-derived matching portrait, not an exact crop.
~~~

If the original source cannot support the framing, create a separately drawn
matching close-up using the following prompt, and record that distinction:

~~~text
Create an anime-inspired pixel-art head-and-shoulders portrait of THIS character,
using the supplied full-body design as the identity reference. Native portrait
target: 64 x 64. Center the visible face/head with balanced margins, complete
hair/headwear and chin, and modest shoulder context. Match head treatment, face shape, skin tone,
hair, eyes, headwear and costume exactly in identity; refine their depiction for
the additional source pixels. Keep a coherent slight three-quarter angle and
readable expression. Use deliberate eye/lid and hair clusters, a simple nose and
mouth, and matching materials/lighting. Keep helmeted or deliberately concealed
faces concealed. Transparent background; no UI box or extra equipment near the
face. This is a separately drawn matching portrait, not an exact crop or a new
person. Do not alter the full-body proportions to create this close-up.
~~~

## Focused correction

~~~text
Correct [specific proportion, grip or face problem] in this full-body character.
Preserve the accepted identity, costume, material colors, other body parts and
pose. Use the relevant current reference for the correction. Return the complete
character. Check the 64 x 64 portrait after an edit to the head and update its
identity and cleaned framing as needed, preserving its derivative provenance.
If an exact crop was explicitly requested, refresh that crop too. Do not call a technical
grid pass or matching export an approval of the visual result.
~~~
