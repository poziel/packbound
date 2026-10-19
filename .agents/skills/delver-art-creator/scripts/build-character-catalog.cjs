#!/usr/bin/env node
'use strict';
// Per-character JSON records are the editable source; catalog/Markdown are derived.
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
const directory = path.join(root, 'assets/characters');
const ids = ['warrior','ranger','mage','assassin','necromancer'];
const bullets = values => values.map(v => '- ' + v).join('\n');
const link = value => value ? '[' + value + '](../../../' + value + ')' : 'Not yet available';
function biography(c) {
 const a = c.physicalAppearance;
 const head = [a.headTreatment,a.headShape,a.face,a.eyes,a.hair,a.headwear].filter(Boolean).join('\n\n');
 return `# ${c.name} — ${c.role}

*${c.title}*

${c.bio.summary}

## Who they are

${c.bio.origin}

${c.bio.motivation}

Personality: ${c.bio.personality.join('; ')}.

${c.bio.mannerisms}

Voice: ${c.bio.voice}

> “${c.bio.quote}”

## Specialty and powers

${c.speciality}

${c.specialPowers.map(p => '### ' + p.name + '\n\n' + (p.kind === 'class-mechanic' ? '**Current class mechanic.** ' : '**Equipment effect.** ') + p.description + '\n\nArt direction: ' + p.visualDirection).join('\n\n')}

Starting health: **${c.gameplay.startingHp} HP**. Starting inventory IDs: ${c.gameplay.startingItemIds.map(id => '`' + id + '`').join(', ')}.

${c.gameplay.itemAliasNotes.join(' ')}

Mechanics reflect ${c.mechanicsSource.map(link).join(' and ')} as inspected on 2026-10-15. These files remain authoritative for combat; the profile does not add new mechanics.

## Physical appearance for character art

### Body, silhouette and bearing

${a.species}. ${a.lifeStage}. ${a.genderPresentation} presentation; approximately ${a.heightCm} cm in-world. This height is a narrative proportion cue, not a pixel-to-centimeter conversion.

${a.build}

${a.silhouette}

${a.expressionAndBearing}

### Head and face

${head}

### Clothing and hands

${a.upperBody}

${a.lowerBody}

${a.cloak}

${a.hands}

### Weapons and equipment

${c.weapons.map(w => '**' + w.name + '** — ' + w.description + '\n\n' + w.relationship + (w.gameItemId ? ' Inventory ID: `' + w.gameItemId + '`.' : '')).join('\n\n')}

### Color and material guide

| Material | Suggested colors |
| --- | --- |
${a.palette.map(p => '| ' + p.material + ' | ' + p.colors.map(color => '`' + color + '`').join(', ') + ' |').join('\n')}

The palette describes material identity; resolve final colors against the original concept and current style references.

### Recognizable identity features

${bullets(a.distinguishingFeatures)}

### Pose and effects

${c.generation.pose}

${a.effects}

### Portrait framing

${a.portraitDirection}

The portrait is **64 × 64 source pixels**, prepared independently from the original detailed concept or a sufficiently detailed matching source. Center the actual head optically, retain its complete silhouette and chin, remove incidental equipment/effects, and repair any hidden head details. Intentional helmets and masks remain part of the identity.

### Avoid

${bullets(a.avoid)}

## Production targets

- Full visible body: **256 source pixels** from head/headwear to soles.
- Full-body cell: **384 × 320**, head top **y32**, baseline **y288**, center near **x192**.
- Held equipment, detached effects and transparent padding do not count toward body height.
- Portrait: separate **64 × 64** native document.
- Rendering: ${c.generation.rendering}
- Save editable spritex authoring JSON with meaningful layers and generate PNG/SVG exports through the CLI. A larger source must contain resolved detail, not doubled legacy pixels.
- Use [delver-art-creator](../../../.agents/skills/delver-art-creator/SKILL.md), the linked spritex skill, this profile and the current visual references. Validate JSON before rendering production art.

${c.generation.review}

## Existing artwork and provenance

${c.assetReferences.appearanceBasis}

- Runtime artwork: ${link(c.assetReferences.runtime)}
- Detailed concept: ${link(c.assetReferences.concept)}
- Native source: ${link(c.assetReferences.nativeSource)}
- Artwork status: ${c.assetReferences.artStatus}.
- Profile status: ${c.identityStatus}

Accepted legacy sprites retain their existing source resolution and approval. This profile defines future art direction without replacing those files.

---

Programmatic source: [character.json](character.json). This Markdown profile is derived from that record; edit the JSON and run <code>node .agents/skills/delver-art-creator/scripts/build-character-catalog.cjs</code> from the project root to rebuild it and the full catalog.
`;
}
(async()=>{
 const characters = [];
 for (const id of ids) {
  const c = JSON.parse(await fs.readFile(path.join(directory,id,'character.json'),'utf8'));
  assert.equal(c.id,id);
  for (const key of ['name','role','speciality','specialPowers','weapons','bio','physicalAppearance','generation','assetReferences']) assert.ok(c[key],id + ' missing ' + key);
  assert.ok(c.specialPowers.length && c.weapons.length);
  assert.equal(c.generation.body.visibleHeightPx,256);
  assert.deepEqual(c.generation.body.canvasPx,[384,320]);
  assert.deepEqual(c.generation.portrait.canvasPx,[64,64]);
  for (const file of Object.values(c.assetReferences).filter(v => typeof v === 'string' && /^(assets|docs)\//.test(v))) await fs.access(path.join(root,file));
  characters.push(c);
 }
 assert.equal(new Set(characters.map(c=>c.name)).size,ids.length,'Names must be distinct');
 const catalog = {
  schemaVersion:1,
  title:'Packbound character roster',
  authoredAt:'2026-10-15',
  sourceOfTruth:'Each assets/characters/<class-id>/character.json supplies catalog data; design READMEs are independently authored.',
  profileStatus:'Newly authored names and lore; existing art approvals remain separate.',
  mechanicsAuthority:['scripts/pack_catalog.gd','scripts/run_state.gd'],
  scope:'Character identity, current class mechanics, art direction and biographies. The game currently retains its role-based labels; this catalog is not yet a runtime name loader.',
  characterOrder:ids,
  generatedFrom:characters.map(c=>c.profilePath),
  characters
 };
 await fs.mkdir(path.join(root,'workspace/docs/art/characters'),{recursive:true});
 await fs.writeFile(path.join(root,'workspace/docs/art/characters/catalog.json'),JSON.stringify(catalog,null,2)+'\n');
 // Design READMEs are independently authored; do not overwrite them from JSON.
 console.log(JSON.stringify({characters:characters.map(c=>({id:c.id,name:c.name,role:c.role})),catalog:'workspace/docs/art/characters/catalog.json',profiles:characters.length,biographies:0,bodyHeightPx:256,portraitPx:[64,64]},null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});

