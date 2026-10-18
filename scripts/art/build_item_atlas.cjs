// Rebuild the eight inventory icons from preserved image-generation sources.
// Requires sharp (install locally, or expose the bundled runtime with NODE_PATH).
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('sharp');

const root = path.resolve(__dirname, '../..');
const sources = path.join(root, 'workspace/docs/art/concepts/items-2026-10-15');
// Historical rebuilds are staged for review so they cannot overwrite current art.
const output = path.join(root, 'tests/output/item-atlas-rebuild');
const review = path.join(output, 'review');
const cell = 96;
// Inventory framing is independent of a held weapon's world-art length.
const items = [
  { file: '01-dagger', key: 'rusty_knife', title: 'Rusty Knife', fit: [74, 74] },
  { file: '02-shield', key: 'cracked_shield', title: 'Cracked shield', fit: [76, 80] },
  { file: '03-ruby', key: 'blood_gem', title: 'Ruby', fit: [58, 64] },
  { file: '04-bandage', key: 'bandage', title: 'Bandage roll', fit: [72, 58] },
  { file: '05-dagger', key: 'longsword', title: 'Iron dagger', fit: [74, 74] },
  { file: '06-shield-relic', key: 'tower_shield', title: 'Shield relic', fit: [64, 72] },
  { file: '07-cursed-idol', key: 'cursed_idol', title: 'Cursed idol', fit: [64, 76] },
  { file: '08-pendant', key: 'iron_charm', title: 'Pendant', fit: [50, 70] },
];

function bounds(data, width, height) {
  let x0 = width, y0 = height, x1 = -1, y1 = -1, count = 0;
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    if (data[(y * width + x) * 4 + 3] < 128) continue;
    x0 = Math.min(x0, x); y0 = Math.min(y0, y);
    x1 = Math.max(x1, x); y1 = Math.max(y1, y); count++;
  }
  if (!count) throw new Error('Empty icon');
  return { left: x0, top: y0, width: x1 - x0 + 1, height: y1 - y0 + 1, pixels: count };
}

function quantizePixels(data, limit) {
  // Explicitly cap the palette: PNG bit depths alone round 32 colors up to 256.
  const histogram = new Map();
  for (let p = 0; p < data.length; p += 4) {
    if (!data[p + 3]) continue;
    const key = data.subarray(p, p + 3).toString('hex');
    const entry = histogram.get(key) || { rgb: Array.from(data.subarray(p, p + 3)), count: 0 };
    entry.count++; histogram.set(key, entry);
  }
  const points = [...histogram.values()].sort((a, b) => b.count - a.count);
  const distance = (a, b) => 2 * (a[0] - b[0]) ** 2 + 3 * (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2;
  const centroids = [points[0].rgb];
  while (centroids.length < Math.min(limit, points.length)) {
    let best = points[0], score = -1;
    for (const point of points) {
      const value = Math.min(...centroids.map(c => distance(point.rgb, c))) * Math.pow(point.count, 0.25);
      if (value > score) { score = value; best = point; }
    }
    centroids.push(best.rgb.slice());
  }
  const nearest = rgb => {
    let best = 0, score = Infinity;
    for (let i = 0; i < centroids.length; i++) {
      const d = distance(rgb, centroids[i]);
      if (d < score) { score = d; best = i; }
    }
    return best;
  };
  for (let iteration = 0; iteration < 18; iteration++) {
    const sums = centroids.map(() => [0, 0, 0, 0]);
    for (const { rgb, count } of points) {
      const sum = sums[nearest(rgb)];
      for (let c = 0; c < 3; c++) sum[c] += rgb[c] * count;
      sum[3] += count;
    }
    for (let i = 0; i < centroids.length; i++) if (sums[i][3]) centroids[i] = sums[i].slice(0, 3).map(v => Math.round(v / sums[i][3]));
  }
  const result = Buffer.from(data);
  for (let p = 0; p < result.length; p += 4) if (result[p + 3]) {
    const rgb = centroids[nearest(result.subarray(p, p + 3))];
    for (let c = 0; c < 3; c++) result[p + c] = rgb[c];
  }
  return result;
}

function svgGroup(item, data, translateX = 0) {
  const colors = new Map();
  // Each filled path groups horizontal runs of one exact palette color.
  // All coordinates are integral and every segment is horizontal/vertical.
  for (let y = 0; y < cell; y++) {
    for (let x = 0; x < cell;) {
      const offset = (y * cell + x) * 4;
      if (!data[offset + 3]) { x++; continue; }
      const rgb = Array.from(data.subarray(offset, offset + 3));
      const hex = '#' + rgb.map(c => c.toString(16).padStart(2, '0')).join('');
      const start = x++;
      while (x < cell) {
        const next = (y * cell + x) * 4;
        if (!data[next + 3] || rgb.some((v, i) => data[next + i] !== v)) break;
        x++;
      }
      const length = x - start;
      const run = `M${start} ${y}h${length}v1h-${length}z`;
      colors.set(hex, (colors.get(hex) || '') + run);
    }
  }
  const paths = Array.from(colors, ([color, runs]) => `    <path fill="${color}" d="${runs}"/>`).join('\n');
  return `  <g id="${item.key}" data-inventory-cells="1x1" transform="translate(${translateX} 0)">\n    <title>${item.title}</title>\n${paths}\n  </g>`;
}

function svgDocument(width, content, title) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="96" viewBox="0 0 ${width} 96" shape-rendering="crispEdges">\n  <title>${title}</title>\n  <desc>Native editable palette-grouped pixel paths derived from preserved image-generated concepts. Inventory icons, one 96 by 96 cell each. See assets/items/README.md for provenance and rebuilding.</desc>\n${content}\n</svg>\n`;
}

async function main() {
  for (const item of items) {
    if (!fs.existsSync(path.join(sources, item.file + '.png'))) throw new Error('Missing source: ' + item.file);
  }
  fs.mkdirSync(output, { recursive: true });
  fs.mkdirSync(review, { recursive: true });
  const groups = [], manifest = [], icons = [];
  for (const [index, item] of items.entries()) {
    const source = path.join(sources, item.file + '.png');
    const original = fs.readFileSync(source);
    const decoded = await sharp(original).toColourspace('srgb').ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    const sourceBounds = bounds(decoded.data, decoded.info.width, decoded.info.height);
    const { pixels: ignored, ...crop } = sourceBounds;
    const factor = Math.min(item.fit[0] / crop.width, item.fit[1] / crop.height);
    const width = Math.max(1, Math.round(crop.width * factor));
    const height = Math.max(1, Math.round(crop.height * factor));
    const resized = await sharp(original).extract(crop)
      .resize(width, height, { fit: 'fill', kernel: 'nearest' })
      .toColourspace('srgb').ensureAlpha().raw().toBuffer();
    // Production pixel art has hard alpha, without translucent generation fringes.
    for (let p = 0; p < resized.length; p += 4) {
      const opaque = resized[p + 3] >= 128;
      resized[p + 3] = opaque ? 255 : 0;
      if (!opaque) resized.fill(0, p, p + 4);
    }
    const palette = quantizePixels(resized, 32);
    const data = Buffer.alloc(cell * cell * 4);
    const x0 = Math.floor((cell - width) / 2), y0 = Math.floor((cell - height) / 2);
    for (let y = 0; y < height; y++) {
      palette.copy(data, ((y + y0) * cell + x0) * 4, y * width * 4, (y + 1) * width * 4);
    }
    // Palette encoders may retain arbitrary RGB underneath transparent pixels.
    for (let p = 0; p < data.length; p += 4) if (!data[p + 3]) data.fill(0, p, p + 4);
    const icon = await sharp(data, { raw: { width: cell, height: cell, channels: 4 } }).png().toBuffer();
    const localSvg = svgDocument(cell, svgGroup(item, data), item.title);
    fs.writeFileSync(path.join(output, item.file + '.png'), icon);
    fs.writeFileSync(path.join(output, item.file + '.svg'), localSvg);
    const rendered = await sharp(Buffer.from(localSvg)).ensureAlpha().raw().toBuffer();
    if (!rendered.equals(data)) throw new Error('SVG/PNG pixel mismatch: ' + item.file);
    const colors = new Set(), alphas = new Set();
    for (let p = 0; p < data.length; p += 4) {
      alphas.add(data[p + 3]);
      if (data[p + 3]) colors.add(data.subarray(p, p + 3).toString('hex'));
    }
    const box = bounds(data, cell, cell);
    if (box.left < 8 || box.top < 8 || box.left + box.width > 88 || box.top + box.height > 88) throw new Error('Insufficient cell padding');
    if (Array.from(alphas).some(a => a !== 0 && a !== 255)) throw new Error('Partial alpha remains');
    if (colors.size > 32) throw new Error('Palette limit exceeded');
    manifest.push({ index, ...item, inventoryCells: [1, 1], cell: [96, 96],
      source: path.relative(root, source).replaceAll('\\', '/'),
      sourceSha256: crypto.createHash('sha256').update(original).digest('hex'),
      sourceBounds, bounds: box, paletteColors: colors.size, alphaValues: [...alphas].sort(),
      svgPixelMatch: true });
    groups.push(svgGroup(item, data, index * cell));
    icons.push(icon);
  }
  const atlas = svgDocument(cell * 8, groups.join('\n'), 'Packbound - eight basic inventory items');
  fs.writeFileSync(path.join(output, 'basic-items.svg'), atlas);
  const atlasPng = await sharp(Buffer.from(atlas)).png().toBuffer();
  fs.writeFileSync(path.join(output, 'items-atlas.png'), atlasPng);
  fs.writeFileSync(path.join(output, 'manifest.json'), JSON.stringify({
    generatedFrom: 'built-in image-generation tool, three delegated item artists',
    cellPixels: 96, layout: [8, 1], paletteLimitPerIcon: 32, alphaThreshold: 128,
    resize: 'nearest-neighbor, preserve aspect ratio', items: manifest,
  }, null, 2) + '\n');
  // Review board: 3x view, native 96px, and the game's 52px/42px display sizes.
  const boardWidth = 1440, boardHeight = 1272, column = 360, row = 612;
  let boardSvg = `<svg width="${boardWidth}" height="${boardHeight}" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#152027"/><text x="24" y="30" fill="#e7d4ae" font-family="sans-serif" font-size="20">PACKBOUND / BASIC ITEMS / ONE CELL EACH</text>`;
  const layers = [];
  for (const [index, item] of items.entries()) {
    const x = (index % 4) * column, y = 52 + Math.floor(index / 4) * row;
    boardSvg += `<text x="${x + 24}" y="${y + 24}" fill="#e7d4ae" font-family="sans-serif" font-size="18">${index + 1}. ${item.title}</text>`;
    boardSvg += `<rect x="${x + 24}" y="${y + 40}" width="312" height="312" fill="#202e34" stroke="#3d5157"/><text x="${x + 24}" y="${y + 380}" fill="#a0b2b7" font-family="sans-serif" font-size="14">3x view / 96 px source / 52 &amp; 42 px UI</text>`;
    layers.push({ input: await sharp(icons[index]).resize(288, 288, { kernel: 'nearest' }).toBuffer(), left: x + 36, top: y + 52 });
    layers.push({ input: icons[index], left: x + 24, top: y + 404 });
    layers.push({ input: await sharp(icons[index]).resize(52, 52, { kernel: 'nearest' }).toBuffer(), left: x + 164, top: y + 424 });
    layers.push({ input: await sharp(icons[index]).resize(42, 42, { kernel: 'nearest' }).toBuffer(), left: x + 264, top: y + 429 });
  }
  boardSvg += '</svg>';
  await sharp(Buffer.from(boardSvg)).composite(layers).png().toFile(path.join(review, 'items-review.png'));
  console.log(JSON.stringify(manifest.map(({ title, bounds, paletteColors, svgPixelMatch }) => ({ title, bounds, paletteColors, svgPixelMatch })), null, 2));
}
main().catch(error => { console.error(error); process.exit(1); });
