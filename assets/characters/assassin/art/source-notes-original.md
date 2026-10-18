# Sable Rook — spritex production sources

Converted losslessly from the original layered v2 Pixelorama documents for installation on 2026-10-16. `body.json` and `portrait.json` are now the editable production authority. Original concepts, Pixelorama files and review history remain in `../v2/`.

- Body: 384 × 320, 256 px visible height, 18 visible layers plus hidden transfer.
- Portrait: 64 × 64, five visible layers plus hidden transfer.
- Both retain one explicit static frame and the original duration; no new animation or editing links were invented.
- PNG/SVG exports are generated through spritex 0.2.0 after validation.
- Layers preserve the visible surfaces of the original pose. Significant pose changes may require painting newly exposed regions.

Runtime copies: `assets/characters/assassin.svg`, `assets/characters/assassin.png` and `assets/characters/portraits/assassin.png`.
