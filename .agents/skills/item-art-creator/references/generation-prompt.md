# Item generation prompt

Fill the subject and geometry fields from the actual brief. Keep the style block
stable. The source canvas is a production target, not a claim about the image
generator's output resolution. Supply the approved visual references as well as
this text; do not rely on a game name alone to reproduce the style.

```text
Create ONE original Packbound fantasy inventory item as an isolated transparent
PNG concept. Use the supplied approved warrior/ranger and item images as STYLE
references for deliberate pixel clusters, silhouette and material planes.
Override any orange/cyan lighting in those references with the neutral
material-based shading specified below.
Any supplied cell-mask guide is a GEOMETRY reference only, not a color reference.

SUBJECT
Name and tier: [name; ordinary starter item / rare / cursed, etc.]
Function: [what it does; communicate through form, not text]
Required defining features: [one or two features that must read at native size]
Materials and base colors: [main material, color and restrained accent]
Presentation: [orientation/view suited to the occupied shape]
Thickness cue: [rim / side plane / bevel / overlap appropriate to the object]
Intended display: [inventory cell and/or reward image area, if known]

SOURCE GEOMETRY
One cell = 32 x 32 source pixels, zero gap.
Footprint rows, top to bottom (# occupied, . empty):
[literal mask rows]
Bounding canvas: [32 * columns] px wide by [32 * rows] px high.
Occupied cells: [count and their zero-based x,y coordinates].
Forbidden cells: [coordinates, or none].
[Describe how the item's physical parts follow the occupied cells.]
Compose for this exact aspect ratio and small native resolution. Keep all object
parts inside the occupied shape. Empty cells and openings are fully transparent;
no aura, chain, highlight or shadow may span a forbidden cell. The object can
cross directly between neighboring occupied cells without gaps or seams. Do not
draw a square tile or disconnected miniature object inside every occupied cell.
Keep the entire item visible; do not crop the tip, handle, loop or other extremity.

FIXED STYLE
Clear recognizable stepped silhouette, deliberate crisp square pixel clusters,
readable physical thickness, broad angular shading planes and restrained value
ramps within each material's own colors. Iron uses neutral gray planes;
leather has quiet contrast; gems have a
few clear facets; cloth has a few readable folds. Use connected shading clusters
to describe form. Give the rim, edge or side plane enough connected pixels to
read as thickness. Separate materials by value and shape. Keep large surfaces
calm; concentrate contrast around structural edges and the one or two identity
details instead of spreading tiny high-contrast marks everywhere.
No colored light reflections, cyan/blue rim pixels, orange edge lighting,
bright specular streaks or isolated glitter pixels. Blue materials or
magical effects belong only when specified in the subject brief. For a one-cell
item, favor 12-20 colors and one or two defining features. Simplify the design
for 32 px instead of preserving high-resolution texture. Retain the dark fantasy
atmosphere through the object itself. Design for recognition at [canvas dimensions]
native pixels.

Avoid thick uniform outlines, smooth airbrushing, blur, scattered texture pixels,
speckled metal, decorative noise, oversized glow, random scratches, excessive
ornament and microscopic details.
No text, labels, grid lines, cell borders, UI frame, checkerboard, background,
floor, cast ground shadow, hand holding the item or extra objects.
```

## Shape-specific subject examples

- **Starter knife, `#`, 32 x 32:** compact iron blade, simple crossguard and
  brown leather grip, presented diagonally; distinguish blade from handle with
  value and material contrast. No runes or magical aura.
- **Cracked shield, `#`, 32 x 32:** strong shield silhouette, a substantial neutral
  iron rim and one deliberate fracture; broad, calm inner material planes. Make
  the rim's thickness readable. Omit random scratches and decorative studs that
  would compete with the fracture at native size.
- **Tall staff, `#/#/#/#`, 32 x 128:** continuous wooden shaft and a modest
  crystal head; each cell contains a meaningful segment of the same object.
- **L-shaped wrench relic, `#./##`, 64 x 64:** upper vertical arm and bottom
  horizontal grip visibly join at the lower-left corner; upper-right is empty.
- **U-shaped trap, `#.#/###`, 96 x 64:** two raised metal jaws joined by a
  bottom crossbar; top-center opening remains clear. No chain across the opening.

If a requested object cannot plausibly fit its requested footprint, propose a
concrete orientation or form adjustment before changing the gameplay mask.

For an optional authored larger variant, replace the SOURCE GEOMETRY numbers
with the helper's computed variant dimensions and uniform per-cell density.
Keep the same mask, orientation and identity. Generate extra detail only where
it improves form at the intended UI size; a variant should not simply add texture.
Do not change the base inventory's 32 px per-cell contract.
