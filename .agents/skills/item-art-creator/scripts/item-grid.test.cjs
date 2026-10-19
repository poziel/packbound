const { test } = require('node:test');
const assert = require('node:assert/strict');
const { parseShape, planView, validatePixels, maskSvg, pixelsSvg, canonicalPixels } = require('./item-grid.cjs');

const cases = [
  ['#', 32, 32, 1], ['#/#', 32, 64, 2], ['##', 64, 32, 2],
  ['##/##', 64, 64, 4], ['#./##', 64, 64, 3], ['#/#/#', 32, 96, 3],
  ['#/#/#/#', 32, 128, 4], ['#.#/###', 96, 64, 5], ['#.#/#.#/###', 96, 96, 7],
];

test('view planning reuses larger footprints instead of creating redundant art', () => {
  const l = planView('#./##', 64);
  assert.equal(l.reuseBase, true);
  assert.deepEqual(l.canvas, { width: 64, height: 64 });
  const square = planView('####/####/####/####', 128);
  assert.equal(square.reuseBase, true);
  assert.deepEqual(square.canvas, { width: 128, height: 128 });
  assert.equal(planView('####/####/####/####', 64).reuseBase, true);
  const one = planView('#', 128);
  assert.equal(one.reuseBase, false);
  assert.deepEqual(one.canvas, { width: 128, height: 128 });
  const lDetail = planView('#./##', 128);
  assert.equal(lDetail.cellPixels, 64);
  assert.deepEqual(lDetail.canvas, { width: 128, height: 128 });
});

test('higher-detail L keeps its empty cell transparent', async () => {
  const sharp = require('sharp');
  const spec = planView('#./##', 128);
  const { data, info } = await sharp(Buffer.from(maskSvg(spec))).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const result = validatePixels(data, info.width, info.height, spec, 1);
  assert.ok(result.cellPixelCounts.every(cell => cell.pixels === 64 * 64));
  const forbidden = (16 * info.width + 80) * 4;
  assert.equal(data[forbidden + 3], 0);
  data[forbidden + 3] = 255;
  assert.throws(() => validatePixels(data, info.width, info.height, spec), /spills into empty cell/);
});
for (const [shape, width, height, count] of cases) test(`canvas and occupancy: ${shape}`, () => {
  const spec = parseShape(shape);
  assert.deepEqual(spec.canvas, { width, height });
  assert.equal(spec.occupiedCellCount, count);
  assert.equal(spec.connectedComponents, 1);
});

function fixture(shape) {
  const spec = parseShape(shape), { width, height } = spec.canvas;
  const data = Buffer.alloc(width * height * 4);
  for (const cell of spec.cells) {
    const p = ((cell.y * 32 + 8) * width + cell.x * 32 + 8) * 4;
    Buffer.from([80, 130, 150, 255]).copy(data, p);
  }
  return { spec, data, width, height };
}
const check = ({ spec, data, width, height }, limit) => validatePixels(data, width, height, spec, limit);

test('reject malformed, empty and externally padded masks', () => {
  for (const shape of ['', '..', '#/##', '#x', '../##', '.#/.#', '#./#.']) {
    assert.throws(() => parseShape(shape));
  }
});
test('L and U openings are forbidden even though inside their canvas', () => {
  for (const shape of ['#./##', '#.#/###']) {
    const f = fixture(shape);
    assert.equal(check(f).pixelsOutsideFootprint, 0);
    const cell = f.spec.emptyCells[0], p = (cell.y * 32 * f.width + cell.x * 32) * 4;
    f.data[p + 3] = 255;
    assert.throws(() => check(f), /spills into empty cell/);
  }
});
test('reject partial alpha, blank occupied cells and wrong source dimensions', () => {
  const f = fixture('#');
  f.data[3] = 128;
  assert.throws(() => check(f), /Partial alpha/);
  f.data.fill(0);
  assert.throws(() => check(f), /contains no artwork/);
  f.width = 96;
  assert.throws(() => check(f), /Expected 32x32/);
});
test('palette counts opaque colors only and rejects overflow', () => {
  const f = fixture('#');
  f.data[0] = 42; // Hidden RGB must not consume a palette color.
  assert.equal(check(f, 1).opaqueColors, 1);
  f.data[3] = 255;
  assert.throws(() => check(f, 1), /exceed palette/);
});
test('disconnected mask is reported without inventing occupied bridge cells', () => {
  const f = fixture('#.#');
  assert.equal(f.spec.connectedComponents, 2);
  assert.equal(check(f).warnings.length, 1);
  assert.deepEqual(f.spec.emptyCells, [{ x: 1, y: 0 }]);
});
test('native SVG round trips exact L/U pixels without filling holes', async () => {
  const sharp = require('sharp');
  for (const shape of ['#./##', '#.#/###']) {
    const f = fixture(shape);
    const rendered = await sharp(Buffer.from(pixelsSvg(f.data, f.spec))).ensureAlpha().raw().toBuffer();
    assert.deepEqual(canonicalPixels(rendered), canonicalPixels(f.data));
  }
});

test('32 px geometry guides fill exactly 1024 pixels per occupied cell', async () => {
  const sharp = require('sharp');
  for (const shape of ['#./##', '#.#/###']) {
    const spec = parseShape(shape);
    const { data, info } = await sharp(Buffer.from(maskSvg(spec))).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    const report = validatePixels(data, info.width, info.height, spec, 1);
    assert.equal(report.pixelsOutsideFootprint, 0);
    assert.ok(report.cellPixelCounts.every(cell => cell.pixels === 1024));
  }
});
