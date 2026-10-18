# Inline icon generation brief

Resolve meanings and colors in [keyword-catalog.md](keyword-catalog.md) first.
Use this for an original concept or a native-grid drawing brief, replacing the
braced fields. For a set, hold the grid, weight and framing constant across icons.

```text
Create one original Packbound inline keyword pixel icon for {label}, ID {icon_id}.
Meaning: {verified mechanic or context}. Shape cue: {silhouette and one cutout}.
Distinguish it clearly from {nearest potentially confused symbols}.

The production target is a {12/16/24} x {12/16/24} native pixel cell. Design for
immediate recognition beside small game text, with open negative space, coherent
1-2 pixel structural thickness and balanced visual weight. Stepped integer-grid
silhouette, transparent background, one opaque white ink mask. No text, border,
button, frame, gradients, antialiasing, glow, decorative scratches or stray pixels.
Use a compact fantasy symbol rather than a detailed illustration of an item.

Leave breathing room around the glyph. Preserve the motif's main silhouette
and its one defining cutout at the target size. The runtime will tint this white
mask using {color_token}; the neighboring {label} keyword uses the same token.
Do not bake a separate colored palette or tooltip lettering into the icon image.
```

For image-generation output, retain the original PNG as the concept and resolve
the design onto the native grid before claiming production dimensions. Review
the actual raster, not only the prompt. If a concept is too complex, simplify its
geometry rather than mechanically reducing a detailed painting to 16 px.

Present a separate review row such as `[heart] Health 20 / 20` using the registry
color, neutral surrounding text and the actual target background. Include 1x and
4x views and a monochrome comparison with related symbols. The colored preview
does not replace the transparent mask source. Do not claim game insertion or
tooltip parsing works until the real consumer has been checked.
