'use strict';
const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs/promises'), path = require('node:path'), os = require('node:os');
const sharp = require('sharp');
const { validateCharacter } = require('./validate-character.cjs');

test('validator measures registered body separately from gear/effects and checks portrait dimensions', async t => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'packbound-character-test-'));
  t.after(() => fs.rm(directory, { recursive: true, force: true }));
  const sprite = path.join(directory, 'sprite.png'), body = path.join(directory, 'body.png'), portrait = path.join(directory, 'portrait.png');
  const rgba = Buffer.alloc(384 * 320 * 4);
  for (let y = 32; y < 288; y++) for (let x = 174; x < 210; x++) rgba.set([100, 100, 100, 255], (y * 384 + x) * 4);
  await sharp(rgba, { raw: { width: 384, height: 320, channels: 4 } }).png().toFile(body);
  rgba.set([200, 200, 200, 255], (12 * 384 + 250) * 4); // detached effect outside body bounds
  await sharp(rgba, { raw: { width: 384, height: 320, channels: 4 } }).png().toFile(sprite);
  await sharp({ create: { width: 64, height: 64, channels: 4, background: '#806080' } }).png().toFile(portrait);
  const result = await validateCharacter({ sprite, body, portrait });
  assert.equal(result.bodyBounds.height, 256);
  assert.equal(result.bodyBounds.top, 32);
  assert.deepEqual(result.portrait, [64, 64]);
  await assert.rejects(validateCharacter({ sprite, body: sprite, portrait }), /Expected body/);
  await sharp({ create: { width: 128, height: 128, channels: 4, background: '#806080' } }).png().toFile(portrait);
  await assert.rejects(validateCharacter({ sprite, body, portrait }), /64 x 64/);
});
