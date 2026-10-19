/** Build native pixel SVGs from preserved generated sources, then export PNGs.
 * Run: node systems/art/tools/build-branding.cjs --trace
 * Omit --trace to preserve SVG edits and regenerate PNG exports only.
 * Dependency: sharp (or the Codex bundled workspace runtime).
 */
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const { createRequire } = require('node:module');
let sharp;
try { sharp = require('sharp'); }
catch {
  const bundled = path.join(os.homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/node');
  sharp = createRequire(path.join(bundled, 'package.json'))('sharp');
}
const root = path.resolve(__dirname, '../../../assets/branding');

function bounds(data, width, height) {
  let left = width, top = height, right = -1, bottom = -1;
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    if (data[(y * width + x) * 4 + 3] >= 128) {
      left = Math.min(left, x); top = Math.min(top, y);
      right = Math.max(right, x); bottom = Math.max(bottom, y);
    }
  }
  if (right < left) throw new Error('Empty artwork');
  return { left, top, width: right - left + 1, height: bottom - top + 1 };
}
function solidAlpha(data) {
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] < 128) data.fill(0, i, i + 4);
    else data[i + 3] = 255;
  }
}
function hex(data, offset) { return '#' + data.subarray(offset, offset + 3).toString('hex'); }

// Explicit median-cut palette keeps the SVG small and predictable, independent
// of PNG encoders rounding their palette limit to a supported bit depth.
function quantize(data, limit) {
  const histogram = new Map();
  for (let i = 0; i < data.length; i += 4) {
    if (!data[i + 3]) continue;
    const key = (data[i] << 16) | (data[i + 1] << 8) | data[i + 2];
    const entry = histogram.get(key);
    if (entry) entry.n++;
    else histogram.set(key, { rgb: [data[i], data[i + 1], data[i + 2]], n: 1, key });
  }
  const box = entries => {
    const total = entries.reduce((sum, c) => sum + c.n, 0);
    const ranges = [0,1,2].map(k => Math.max(...entries.map(c => c.rgb[k])) - Math.min(...entries.map(c => c.rgb[k])));
    const channel = ranges.indexOf(Math.max(...ranges));
    return { entries, total, channel, score: ranges[channel] * Math.sqrt(total) };
  };
  const boxes = [box([...histogram.values()])];
  while (boxes.length < limit) {
    boxes.sort((a,b) => b.score-a.score);
    const current = boxes.shift();
    if (current.entries.length < 2) { boxes.push(current); break; }
    current.entries.sort((a,b) => a.rgb[current.channel] - b.rgb[current.channel]);
    let n = 0, split = 1;
    for (; split < current.entries.length; split++) {
      n += current.entries[split-1].n;
      if (n >= current.total / 2) break;
    }
    split = Math.min(split, current.entries.length-1);
    boxes.push(box(current.entries.slice(0,split)),box(current.entries.slice(split)));
  }
  const palette = boxes.map(b => [0,1,2].map(k => Math.round(b.entries.reduce((sum,c) => sum+c.rgb[k]*c.n,0)/b.total)));
  const nearest = new Map();
  for (const c of histogram.values()) {
    let best = 0, distance = Infinity;
    palette.forEach((p,j) => {
      const d = p.reduce((sum,v,k) => sum+(v-c.rgb[k])**2,0);
      if (d < distance) { best=j; distance=d; }
    });
    nearest.set(c.key,palette[best]);
  }
  for (let i=0; i<data.length; i+=4) if (data[i+3]) {
    const p = nearest.get((data[i]<<16)|(data[i+1]<<8)|data[i+2]);
    data[i]=p[0]; data[i+1]=p[1]; data[i+2]=p[2];
  }
}

async function trace({ name, source, width, colors, square, title, description }) {
  const original = await sharp(path.join(root, 'sources', source)).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  solidAlpha(original.data);
  const crop = bounds(original.data, original.info.width, original.info.height);
  const height = Math.round(crop.height * width / crop.width);
  const resized = await sharp(original.data, { raw: original.info }).extract(crop)
    .resize(width, height, { kernel: 'nearest', fit: 'fill' }).png().toBuffer();
  const { data, info } = await sharp(resized).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  solidAlpha(data);
  quantize(data, colors);
  const h = square ? width : info.height;
  const dy = square ? Math.floor((h - info.height) / 2) : 0;
  // One named group per palette swatch. Paths consist only of integer-grid
  // horizontal runs; no raster embedding, clipping, transforms, or fonts.
  const runs = new Map();
  for (let y = 0; y < info.height; y++) {
    let x = 0;
    while (x < width) {
      const offset = (y * width + x) * 4;
      if (data[offset + 3] === 0) { x++; continue; }
      const color = hex(data, offset);
      const start = x++;
      while (x < width && data[(y * width + x) * 4 + 3] && hex(data, (y * width + x) * 4) === color) x++;
      if (!runs.has(color)) runs.set(color, []);
      runs.get(color).push(`M${start} ${y + dy}h${x - start}v1h-${x - start}z`);
    }
  }
  const svg = [
    `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${h}" viewBox="0 0 ${width} ${h}" shape-rendering="crispEdges" role="img" aria-labelledby="title desc">`,
    `  <title id="title">${title}</title>`,
    `  <desc id="desc">${description} Native integer-grid paths, ${runs.size} colors. Preserved raster source: sources/${source}.</desc>`,
    ...Array.from(runs, ([color, pieces]) => `  <g id="color-${color.slice(1)}" fill="${color}"><path d="${pieces.join('')}"/></g>`),
    '</svg>', ''
  ].join('\n');
  await fs.writeFile(path.join(root, name + '.svg'), svg);
  return { name, source, grid: [width, h], visibleBounds: { ...crop }, colors: runs.size, sourcePixelGrid: [info.width, info.height] };
}

async function render(name, scale) {
  const source = path.join(root, name + '.svg');
  const m = await sharp(source).metadata();
  const native = await sharp(source).png().toBuffer();
  const target = path.join(root, name + '.png');
  await sharp(native).resize(m.width * scale, m.height * scale, { kernel: 'nearest' }).png().toFile(target);
  return { name, svg: [m.width, m.height], png: [m.width * scale, m.height * scale], scale };
}

async function windowsIcon() {
  const sizes = [16,32,48,64,128,256];
  const pngs = await Promise.all(sizes.map(size => fs.readFile(path.join(root, 'exports', `packbound-icon-${size}.png`))));
  const header = Buffer.alloc(6 + sizes.length * 16);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  pngs.forEach((png, i) => {
    const entry = 6 + i * 16;
    header[entry] = sizes[i] % 256;
    header[entry + 1] = sizes[i] % 256;
    header.writeUInt16LE(1, entry + 4);
    header.writeUInt16LE(32, entry + 6);
    header.writeUInt32LE(png.length, entry + 8);
    header.writeUInt32LE(offset, entry + 12);
    offset += png.length;
  });
  await fs.writeFile(path.join(root, 'packbound.ico'), Buffer.concat([header, ...pngs]));
}

async function validate(name) {
  const svg = await fs.readFile(path.join(root, name + '.svg'), 'utf8');
  if (/<(?:image|text|foreignObject)\b/.test(svg) || /data:image|<filter\b/.test(svg)) throw new Error(name + ': not standalone vector art');
  for (const [, d] of svg.matchAll(/\bd="([^"]+)"/g)) {
    if (/[.]/.test(d) || /[cqa]/i.test(d)) throw new Error(name + ': non-integer or curved paths');
  }
  const { data, info } = await sharp(path.join(root, name + '.png')).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const palette = new Set(); let transparent = 0;
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) { transparent++; continue; }
    if (data[i + 3] !== 255) throw new Error(name + ': antialiased alpha');
    palette.add(hex(data, i));
  }
  if (!transparent) throw new Error(name + ': missing transparency');
  return { name, pngSize: [info.width, info.height], paletteColors: palette.size, binaryAlpha: true, noEmbeddedRaster: true, integerPaths: true, bounds: bounds(data, info.width, info.height) };
}

async function preview() {
  const panel = Buffer.from(`<svg width="1440" height="1120" xmlns="http://www.w3.org/2000/svg"><rect width="1440" height="1120" fill="#17171d"/><g fill="#bfae9f" font-family="Segoe UI, sans-serif" font-size="18"><text x="56" y="45">PACKBOUND · PRODUCTION ASSETS</text><text x="56" y="430">DETAILED SATCHEL · 128 PX GRID</text><text x="580" y="430">SIMPLIFIED SATCHEL · 32 PX GRID</text><text x="1112" y="430">SMALL ICONS</text><text x="1112" y="570">16 / 32 / 48 / 64 PX</text><text x="56" y="1000">Transparent PNG exports · Editable native SVG paths · Nearest-neighbor scaling</text><text x="56" y="1048">Plum leather / ivory skull / brass fittings / gold title / violet curse</text></g></svg>`);
  const title = await sharp(path.join(root, 'packbound-title.svg')).resize(1328, null, { kernel: 'nearest' }).png().toBuffer();
  const detailed = await sharp(path.join(root, 'packbound-satchel-detailed.svg')).resize(448,448,{kernel:'nearest'}).png().toBuffer();
  const simple = await sharp(path.join(root, 'packbound-satchel-simple.svg')).resize(448,448,{kernel:'nearest'}).png().toBuffer();
  const layers = [{input:title,left:56,top:80},{input:detailed,left:56,top:460},{input:simple,left:580,top:460}];
  let x = 1112;
  for (const size of [16,32,48,64]) {
    const icon = await fs.readFile(path.join(root,'exports',`packbound-icon-${size}.png`));
    layers.push({input:icon,left:x,top:480+64-size}); x += size+12;
  }
  // Light surface checks make leftover dark backgrounds / edge fringes visible.
  const tile = Buffer.from('<svg width="220" height="220" xmlns="http://www.w3.org/2000/svg"><rect width="220" height="220" fill="#f2e6d4"/></svg>');
  layers.push({input:tile,left:1112,top:620});
  const onLight = await sharp(path.join(root,'packbound-satchel-simple.svg')).resize(192,192,{kernel:'nearest'}).png().toBuffer();
  layers.push({input:onLight,left:1126,top:634});
  await sharp(panel).composite(layers).png().toFile(path.join(root,'previews','asset-sheet.png'));
  const micro = await sharp(path.join(root,'exports','packbound-icon-16.png')).resize(256,256,{kernel:'nearest'}).png().toBuffer();
  const standard = await sharp(path.join(root,'exports','packbound-icon-32.png')).resize(256,256,{kernel:'nearest'}).png().toBuffer();
  await sharp({create:{width:640,height:320,channels:4,background:'#24202a'}})
    .composite([{input:micro,left:32,top:32},{input:standard,left:352,top:32}])
    .png().toFile(path.join(root,'previews','icon-pixel-check.png'));
}

async function main() {
  await fs.mkdir(path.join(root, 'exports'), { recursive: true });
  await fs.mkdir(path.join(root, 'previews'), { recursive: true });
  const traced = [];
  if (process.argv.includes('--trace')) {
    traced.push(await trace({ name: 'packbound-title', source: 'title-isolated.png', width: 696, colors: 56, square: false,
      title: 'Packbound — The Cursed Descent title logo', description: 'Warm gold pixel lettering with a violet curse wisp in the O and a matching subtitle.' }));
    traced.push(await trace({ name: 'packbound-satchel-detailed', source: 'satchel-isolated.png', width: 128, colors: 48, square: true,
      title: 'Packbound detailed skull satchel', description: 'Plum leather backpack, brown straps, brass buckles and ivory skull seal.' }));
    await fs.writeFile(path.join(root, 'sources', 'trace-manifest.json'), JSON.stringify(traced, null, 2) + '\n');
  }
  const assets = [await render('packbound-title', 4), await render('packbound-satchel-detailed',4), await render('packbound-satchel-simple',8)];
  const simple = path.join(root, 'packbound-satchel-simple.svg');
  for (const size of [16,32,48,64,128,256]) {
    const iconSource = size === 16 ? path.join(root, 'sources', 'satchel-micro-16.svg') : simple;
    await sharp(iconSource).resize(size,size,{kernel:'nearest'}).png().toFile(path.join(root,'exports',`packbound-icon-${size}.png`));
  }
  await windowsIcon();
  const checks = [];
  for (const {name} of assets) checks.push(await validate(name));
  await preview();
  const report = { assets, checks };
  await fs.writeFile(path.join(root, 'previews', 'validation.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
}
main().catch(error => { console.error(error); process.exitCode = 1; });
