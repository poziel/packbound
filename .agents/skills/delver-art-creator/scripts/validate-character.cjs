#!/usr/bin/env node
'use strict';
const fs = require('node:fs/promises');
const crypto = require('node:crypto');
const sharp = require('sharp');

async function readPng(file, width, height) {
  const bytes = await fs.readFile(file);
  const metadata = await sharp(bytes).metadata();
  if (metadata.format !== 'png' || (metadata.pages ?? 1) !== 1 || metadata.width !== width || metadata.height !== height) {
    throw new Error(`${file}: expected a single-frame ${width} x ${height} PNG`);
  }
  return { pixels: await sharp(bytes).ensureAlpha().raw().toBuffer(), sha256: crypto.createHash('sha256').update(bytes).digest('hex') };
}

async function validateCharacter({ sprite, body, portrait }) {
  const full = await readPng(sprite, 384, 320);
  const isolated = await readPng(body, 384, 320);
  const head = await readPng(portrait, 64, 64);
  let left = 384, top = 320, right = -1, bottom = -1;
  for (let p = 0; p < 384 * 320; p++) {
    if (!isolated.pixels[p * 4 + 3]) continue;
    if (!full.pixels[p * 4 + 3]) throw new Error('Body contains pixels outside the visible full sprite');
    const x = p % 384, y = Math.floor(p / 384);
    left = Math.min(left, x); right = Math.max(right, x);
    top = Math.min(top, y); bottom = Math.max(bottom, y);
  }
  if (top !== 32 || bottom !== 287) throw new Error(`Expected body y32..287 (256 px); found y${top}..${bottom}`);
  return {
    canvas: [384, 320], bodyBounds: { left, top, rightInclusive: right, bottomInclusive: bottom, height: bottom - top + 1 },
    portrait: [64, 64], sourceHashes: { sprite: full.sha256, body: isolated.sha256, portrait: head.sha256 },
    visualReviewRequired: ['body mask excludes held equipment and detached effects', 'intentionally resolved detail at native resolution', 'centered unobstructed portrait head', 'proportions and face quality'],
    userApprovalChecked: false,
  };
}

if (require.main === module) {
  const args = process.argv.slice(2), options = {};
  for (let i = 0; i < args.length; i += 2) {
    const name = args[i].slice(2);
    if (!['sprite', 'body', 'portrait'].includes(name) || options[name] || !args[i + 1]) throw new Error('Use --sprite PNG --body PNG --portrait PNG');
    options[name] = args[i + 1];
  }
  if (!options.sprite || !options.body || !options.portrait) throw new Error('Use --sprite PNG --body PNG --portrait PNG');
  validateCharacter(options).then(r => process.stdout.write(JSON.stringify(r, null, 2) + '\n')).catch(e => { process.stderr.write(e.message + '\n'); process.exitCode = 1; });
}
module.exports = { validateCharacter };
