#!/usr/bin/env node
// Plan and validate item footprints. Never resize, clip, recolor or overwrite art.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const CELL = 32;

function parseShape(shape, cellPixels = CELL) {
  if (![32, 64, 128].includes(cellPixels)) throw new Error('Source cell density must be 32, 64 or 128 px.');
  if (typeof shape !== 'string') throw new Error('Provide --shape, for example "#./##".');
  const rows = shape.split('/');
  const width = rows[0].length;
  if (!width || rows.some(row => row.length !== width || !/^[#.]+$/.test(row))) {
    throw new Error('Mask rows must have equal nonzero length and contain only # or .; separate rows with /.');
  }
  const cells = [], emptyCells = [];
  rows.forEach((row, y) => [...row].forEach((value, x) => {
    (value === '#' ? cells : emptyCells).push({ x, y });
  }));
  if (!cells.length) throw new Error('The mask has no occupied cells.');
  if (!rows[0].includes('#') || !rows.at(-1).includes('#') ||
      !rows.some(row => row[0] === '#') || !rows.some(row => row.at(-1) === '#')) {
    throw new Error('Remove wholly empty outer rows/columns; keep internal empty cells.');
  }
  const remaining = new Set(cells.map(({ x, y }) => `${x},${y}`));
  let connectedComponents = 0;
  while (remaining.size) {
    connectedComponents++;
    const first = remaining.values().next().value;
    remaining.delete(first);
    const queue = [first];
    while (queue.length) {
      const [x, y] = queue.pop().split(',').map(Number);
      for (const key of [`${x - 1},${y}`, `${x + 1},${y}`, `${x},${y - 1}`, `${x},${y + 1}`]) {
        if (remaining.delete(key)) queue.push(key);
      }
    }
  }
  return {
    schemaVersion: 1, cellPixels, gapPixels: 0, rows,
    columns: width, rowCount: rows.length,
    canvas: { width: width * cellPixels, height: rows.length * cellPixels },
    occupiedCellCount: cells.length, cells, emptyCells, connectedComponents,
  };
}

function planView(shape, viewEdge = 0) {
  if (![0, 64, 128].includes(viewEdge)) throw new Error('View edge must be 64 or 128 px, or omitted for backpack art.');
  const base = parseShape(shape);
  const baseEdge = Math.max(base.canvas.width, base.canvas.height);
  const cellPixels = viewEdge <= baseEdge ? CELL : viewEdge <= baseEdge * 2 ? 64 : 128;
  return { ...parseShape(shape, cellPixels), backpackCellPixels: CELL,
    targetViewEdge: viewEdge || baseEdge, baseCanvas: base.canvas, reuseBase: cellPixels === CELL };
}

function validatePixels(data, width, height, spec, paletteLimit = 32) {
  if (!Number.isInteger(paletteLimit) || paletteLimit < 1 || paletteLimit > 256) {
    throw new Error('Palette limit must be an integer from 1 to 256.');
  }
  if (width !== spec.canvas.width || height !== spec.canvas.height) {
    throw new Error(`Expected ${spec.canvas.width}x${spec.canvas.height}, received ${width}x${height}.`);
  }
  if (data.length !== width * height * 4) throw new Error('Expected 8-bit RGBA pixels.');
  const colors = new Set();
  const counts = new Map(spec.cells.map(({ x, y }) => [`${x},${y}`, 0]));
  let left = width, top = height, right = -1, bottom = -1;
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const p = (y * width + x) * 4, alpha = data[p + 3];
    if (alpha !== 0 && alpha !== 255) throw new Error(`Partial alpha ${alpha} at pixel (${x},${y}).`);
    if (!alpha) continue;
    const cx = Math.floor(x / spec.cellPixels), cy = Math.floor(y / spec.cellPixels), key = `${cx},${cy}`;
    if (!counts.has(key)) throw new Error(`Opaque pixel (${x},${y}) spills into empty cell (${cx},${cy}).`);
    counts.set(key, counts.get(key) + 1);
    colors.add(data.subarray(p, p + 3).toString('hex'));
    left = Math.min(left, x); top = Math.min(top, y);
    right = Math.max(right, x); bottom = Math.max(bottom, y);
  }
  for (const [key, count] of counts) if (!count) throw new Error(`Occupied cell (${key}) contains no artwork.`);
  if (colors.size > paletteLimit) throw new Error(`${colors.size} opaque colors exceed palette limit ${paletteLimit}.`);
  return {
    paletteLimit, opaqueColors: colors.size, binaryAlpha: true,
    pixelsOutsideFootprint: 0,
    visibleBounds: { x: left, y: top, width: right - left + 1, height: bottom - top + 1 },
    cellPixelCounts: spec.cells.map(cell => ({ ...cell, pixels: counts.get(`${cell.x},${cell.y}`) })),
    warnings: spec.connectedComponents > 1 ? ['Footprint contains disconnected cell groups; confirm this is intentional.'] : [],
  };
}

function maskSvg(spec) {
  const { width, height } = spec.canvas;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" shape-rendering="crispEdges">\n` +
    '<title>Occupied cells only - geometry guide, not final art</title>\n' +
    spec.cells.map(({ x, y }) => `<rect x="${x * spec.cellPixels}" y="${y * spec.cellPixels}" width="${spec.cellPixels}" height="${spec.cellPixels}" fill="#718b96"/>`).join('\n') + '\n</svg>\n';
}

function pixelsSvg(data, spec) {
  const { width, height } = spec.canvas, colors = new Map();
  for (let y = 0; y < height; y++) for (let x = 0; x < width;) {
    const p = (y * width + x) * 4;
    if (!data[p + 3]) { x++; continue; }
    const color = data.subarray(p, p + 3).toString('hex'), start = x++;
    while (x < width) {
      const next = (y * width + x) * 4;
      if (!data[next + 3] || data.subarray(next, next + 3).toString('hex') !== color) break;
      x++;
    }
    const run = x - start;
    colors.set(color, (colors.get(color) || '') + `M${start} ${y}h${run}v1h-${run}z`);
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" shape-rendering="crispEdges">\n` +
    '<title>Packbound inventory item</title>\n' +
    `<g id="item" data-cell-pixels="${spec.cellPixels}" data-mask="${spec.rows.join('/')}">\n` +
    [...colors].map(([color, runs]) => `<path fill="#${color}" d="${runs}"/>`).join('\n') + '\n</g>\n</svg>\n';
}

function canonicalPixels(data) {
  const result = Buffer.from(data);
  for (let p = 0; p < result.length; p += 4) if (!result[p + 3]) result.fill(0, p, p + 4);
  return result;
}

function writeNewFiles(prefix, entries) {
  if (!prefix) throw new Error('Provide --out as an output file prefix.');
  const files = entries.map(([suffix, content]) => [path.resolve(prefix + suffix), content]);
  for (const [file] of files) if (fs.existsSync(file)) throw new Error(`Refusing to overwrite ${file}; use a new version.`);
  fs.mkdirSync(path.dirname(files[0][0]), { recursive: true });
  for (const [file, content] of files) fs.writeFileSync(file, content, { flag: 'wx' });
  return files.map(([file]) => file);
}

async function main(args) {
  if (!args.length || args[0] === '--help') {
    console.log('Usage: item-grid.cjs layout|check|export --shape "#./##" [--view-edge 64|128] [--image native.png] [--out output-prefix] [--palette-limit 32]');
    return;
  }
  const mode = args[0], options = {};
  if (!['layout', 'check', 'export'].includes(mode)) throw new Error('Choose layout, check or export.');
  const allowed = new Set(['shape', 'image', 'out', 'palette-limit', 'view-edge']);
  for (let i = 1; i < args.length; i += 2) {
    const key = args[i].slice(2);
    if (!args[i].startsWith('--') || !allowed.has(key) || args[i + 1] === undefined || key in options) {
      throw new Error(`Invalid or repeated option: ${args[i]}. Use --help.`);
    }
    options[key] = args[i + 1];
  }
  const spec = planView(options.shape, Number(options['view-edge'] || 0));
  if (mode === 'layout') {
    const files = writeNewFiles(options.out, [
      ['.footprint.json', JSON.stringify(spec, null, 2) + '\n'], ['.mask.svg', maskSvg(spec)],
    ]);
    console.log(JSON.stringify({ ...spec, files }, null, 2));
    return;
  }
  if (!options.image) throw new Error('Provide --image with a native-resolution PNG.');
  let sharp;
  try { sharp = require('sharp'); } catch {
    throw new Error('sharp is required for check/export. Expose bundled workspace Node dependencies through NODE_PATH.');
  }
  const source = fs.readFileSync(options.image), meta = await sharp(source).metadata();
  if (meta.format !== 'png' || (meta.pages || 1) !== 1) throw new Error('Input must be one still PNG.');
  if (meta.width !== spec.canvas.width || meta.height !== spec.canvas.height) {
    throw new Error(`Expected ${spec.canvas.width}x${spec.canvas.height}, received ${meta.width}x${meta.height}. No resizing was performed.`);
  }
  const { data, info } = await sharp(source).toColourspace('srgb').ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const validation = validatePixels(data, info.width, info.height, spec, Number(options['palette-limit'] || 32));
  const record = { ...spec, validation,
    sourcePng: path.relative(process.cwd(), path.resolve(options.image)).replaceAll('\\', '/'),
    sourceSha256: crypto.createHash('sha256').update(source).digest('hex'),
  };
  if (mode === 'export') {
    const svg = pixelsSvg(data, spec);
    const rendered = await sharp(Buffer.from(svg)).toColourspace('srgb').ensureAlpha().raw().toBuffer();
    if (!canonicalPixels(rendered).equals(canonicalPixels(data))) throw new Error('SVG/PNG render mismatch. Nothing was exported.');
    record.validation.svgPixelMatch = true;
    record.svgEncoding = 'Editable color-grouped integer pixel runs derived from source PNG';
    record.files = writeNewFiles(options.out, [
      ['.png', source], ['.svg', svg], ['.footprint.json', JSON.stringify(record, null, 2) + '\n'],
    ]);
  }
  console.log(JSON.stringify(record, null, 2));
}

module.exports = { parseShape, planView, validatePixels, maskSvg, pixelsSvg, canonicalPixels };
if (require.main === module) main(process.argv.slice(2)).catch(error => {
  console.error(error.message); process.exitCode = 1;
});
