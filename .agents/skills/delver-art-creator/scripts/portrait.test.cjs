'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const sharp = require('sharp');
const { extractPortrait, parseArguments } = require('./portrait.cjs');

async function fixture(t, width = 12, height = 16) {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'packbound-portrait-test-'));
  t.after(() => fs.rm(directory, { recursive: true, force: true }));
  const rgba = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      rgba.set([x % 256, y % 256, (x + y) % 256, (x * 19 + y * 13) % 256], i);
    }
  }
  const source = path.join(directory, 'source.png');
  await sharp(rgba, { raw: { width, height, channels: 4 } }).png().toFile(source);
  return { directory, source, rgba, width, height };
}

test('portrait keeps source RGBA pixels, preview repeats them, and source remains intact', async (t) => {
  const f = await fixture(t);
  const before = await fs.readFile(f.source);
  const result = await extractPortrait({ source: f.source, rect: [3, 4, 5, 5], out: path.join(f.directory, 'portrait'), stage: 'concept', mode: 'exact' });
  const crop = await sharp(result.outputs.portrait).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const preview = await sharp(result.outputs.preview).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  assert.equal(crop.info.width, 5);
  assert.equal(crop.info.height, 5);
  assert.equal(preview.info.width, 20);
  for (let y = 0; y < 5; y++) {
    for (let x = 0; x < 5; x++) {
      const sourceOffset = ((y + 4) * f.width + x + 3) * 4;
      const expected = f.rgba.subarray(sourceOffset, sourceOffset + 4);
      assert.deepEqual(crop.data.subarray((y * 5 + x) * 4, (y * 5 + x) * 4 + 4), expected);
      for (let dy = 0; dy < 4; dy++) {
        for (let dx = 0; dx < 4; dx++) {
          const offset = ((y * 4 + dy) * 20 + x * 4 + dx) * 4;
          assert.deepEqual(preview.data.subarray(offset, offset + 4), expected);
        }
      }
    }
  }
  assert.deepEqual(await fs.readFile(f.source), before);
  const metadata = JSON.parse(await fs.readFile(result.outputs.metadata, 'utf8'));
  assert.deepEqual(metadata.crop, { x: 3, y: 4, width: 5, height: 5, sourcePixelScale: 1 });
  assert.equal(metadata.validation.bodyHeightAndArtQualityChecked, false);
  assert.equal(metadata.relationship, 'exact-crop');
});

test('default portrait mode produces 64x64 from detailed source and refuses enlargement', async (t) => {
  const f = await fixture(t, 160, 160);
  const before = await fs.readFile(f.source);
  const result = await extractPortrait({ source: f.source, rect: [16, 16, 128, 128], out: path.join(f.directory, 'detail'), stage: 'concept' });
  const image = await sharp(result.outputs.portrait).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const preview = await sharp(result.outputs.preview).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  assert.equal(image.info.width, 64);
  assert.equal(image.info.height, 64);
  assert.equal(preview.info.width, 256);
  for (let y = 0; y < 64; y++) for (let x = 0; x < 64; x++) {
    const sourceOffset = ((16 + y * 2 + 1) * 160 + 16 + x * 2 + 1) * 4;
    assert.deepEqual(image.data.subarray((y * 64 + x) * 4, (y * 64 + x + 1) * 4), f.rgba.subarray(sourceOffset, sourceOffset + 4));
  }
  assert.equal(result.record.relationship, 'concept-derived-matching-portrait');
  assert.equal(result.record.validation.headCenteringAndObstructionsChecked, false);
  assert.deepEqual(await fs.readFile(f.source), before);
  await assert.rejects(extractPortrait({ source: f.source, rect: [0, 0, 40, 40], out: path.join(f.directory, 'tiny'), stage: 'concept' }), /do not enlarge/);
  await assert.rejects(extractPortrait({ source: f.source, rect: [0, 0, 64, 64], out: path.join(f.directory, 'bad-mode'), stage: 'concept', mode: 'unknown' }), /Mode/);
});

test('bad rectangles fail without writing any output', async (t) => {
  const f = await fixture(t);
  for (const rect of [[-1, 0, 4, 4], [0, 0, 0, 0], [0, 0, 4, 5], [10, 0, 4, 4], [0.5, 0, 4, 4]]) {
    await assert.rejects(extractPortrait({ source: f.source, rect, out: path.join(f.directory, 'bad'), stage: 'concept', mode: 'exact' }));
  }
  assert.deepEqual(await fs.readdir(f.directory), ['source.png']);
});

test('production accepts current and preserved legacy canvases, rejects arbitrary dimensions', async (t) => {
  const small = await fixture(t);
  await assert.rejects(extractPortrait({ source: small.source, rect: [0, 0, 4, 4], out: path.join(small.directory, 'bad'), stage: 'production', mode: 'exact' }), /384 x 320/);
  for (const [width, height] of [[384, 320], [192, 160]]) {
    const native = await fixture(t, width, height);
    const result = await extractPortrait({ source: native.source, rect: [80, 12, 32, 32], out: path.join(native.directory, 'head'), stage: 'production', mode: 'exact' });
    assert.equal(result.record.stage, 'production');
    assert.equal(result.record.source.width, width);
    assert.equal(result.record.source.height, height);
    assert.equal((await sharp(result.outputs.portrait).metadata()).width, 32);
  }
});

test('an existing output prevents all writes and is preserved', async (t) => {
  const f = await fixture(t);
  const sentinel = path.join(f.directory, 'head.crop.json');
  await fs.writeFile(sentinel, 'keep this');
  await assert.rejects(extractPortrait({ source: f.source, rect: [0, 0, 4, 4], out: path.join(f.directory, 'head'), stage: 'concept', mode: 'exact' }), /already exists/);
  assert.equal(await fs.readFile(sentinel, 'utf8'), 'keep this');
  assert.deepEqual((await fs.readdir(f.directory)).sort(), ['head.crop.json', 'source.png']);
});

test('argument validation catches missing, duplicate and malformed fields', () => {
  assert.throws(() => parseArguments(['--source', 'a.png']), /required/);
  assert.throws(() => parseArguments(['--source', 'a.png', '--source', 'b.png']), /repeated/);
  assert.throws(() => parseArguments(['--unknown', 'value']), /Unknown/);
  assert.throws(() => parseArguments(['--source', 'a.png', '--rect', '0.5,0,4,4', '--out', 'head', '--stage', 'concept']), /integers/);
  assert.deepEqual(parseArguments(['--source', 'a.png', '--rect', '3,4,5,5', '--out', 'head', '--stage', 'concept']), {
    source: 'a.png', rect: [3, 4, 5, 5], out: 'head', stage: 'concept', previewScale: 4, mode: 'portrait',
  });
});
