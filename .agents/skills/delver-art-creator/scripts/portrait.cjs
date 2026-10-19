#!/usr/bin/env node
'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('sharp');

const HELP = `Prepare a 64x64 portrait from a deliberately framed detailed source.

node portrait.cjs --source full-body.png --rect X,Y,SIZE,SIZE --out portrait --stage concept

Required:
  --source PATH          Full-body PNG to crop; it is never modified.
  --rect X,Y,W,H         Integer, square source-pixel rectangle, fully in bounds.
  --out PREFIX           Writes PREFIX.png, PREFIX@Nx.png and PREFIX.crop.json.
  --stage STAGE          concept or production; production accepts 384x320 PNGs
                         and preserved legacy 192x160 PNGs.
Optional:
  --preview-scale N      Integer 2..16, default 4; nearest-neighbor preview only.
  --mode MODE            portrait (default): resize the chosen square to 64x64.
                         exact: retain source pixels for intermediate extraction.

Choose --rect after visually centering the head, preserving hair/headwear and chin.
Portrait mode requires at least 64x64 source pixels; it never enlarges a tiny face.
It preserves source identity but cannot identify or repair weapon obstructions.
Finish the portrait in spritex JSON and export via its CLI, inspect at native/UI size, and record
cleanup separately. Existing outputs are refused. Source art is never modified.
Requires the sharp Node package.
`;

function parseArguments(argv) {
  const allowed = new Set(['source', 'rect', 'out', 'stage', 'preview-scale', 'mode']);
  const flags = {};
  for (let i = 0; i < argv.length; i += 2) {
    const name = argv[i].startsWith('--') ? argv[i].slice(2) : '';
    if (!allowed.has(name) || flags[name] !== undefined) {
      throw new Error(`Unknown or repeated option: ${argv[i]}`);
    }
    const value = argv[i + 1];
    if (!value || value.startsWith('--')) throw new Error(`Missing value for --${name}`);
    flags[name] = value;
  }
  for (const name of ['source', 'rect', 'out', 'stage']) {
    if (!flags[name]) throw new Error(`Missing required --${name}`);
  }
  if (!/^\d+,\d+,\d+,\d+$/.test(flags.rect)) {
    throw new Error('--rect must contain four non-negative integers: X,Y,W,H');
  }
  const rect = flags.rect.split(',').map(Number);
  const previewScale = Number(flags['preview-scale'] ?? 4);
  return { source: flags.source, rect, out: flags.out, stage: flags.stage, previewScale, mode: flags.mode ?? 'portrait' };
}

const sha256 = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');

async function extractPortrait(options) {
  const { rect, stage, previewScale = 4, mode = 'portrait' } = options;
  if (!['portrait', 'exact'].includes(mode)) throw new Error('Mode must be portrait or exact');
  if (!Array.isArray(rect) || rect.length !== 4 ||
      !rect.every(Number.isSafeInteger) || rect.some((value) => value < 0)) {
    throw new Error('The crop rectangle must contain four non-negative integers');
  }
  const [left, top, width, height] = rect;
  if (width < 1 || width !== height) throw new Error('The portrait crop must be a nonempty square');
  if (mode === 'portrait' && width < 64) {
    throw new Error('64 x 64 portraits require a detailed source crop at least 64 x 64; do not enlarge a tiny sprite face');
  }
  if (!['concept', 'production'].includes(stage)) throw new Error('Stage must be concept or production');
  if (!Number.isInteger(previewScale) || previewScale < 2 || previewScale > 16) {
    throw new Error('Preview scale must be an integer from 2 to 16');
  }

  const sourcePath = path.resolve(options.source);
  const prefix = path.resolve(options.out);
  const outputs = {
    portrait: `${prefix}.png`,
    preview: `${prefix}@${previewScale}x.png`,
    metadata: `${prefix}.crop.json`,
  };
  const sourceBytes = await fs.readFile(sourcePath);
  const imageMetadata = await sharp(sourceBytes).metadata();
  if (imageMetadata.format !== 'png' || (imageMetadata.pages ?? 1) !== 1) {
    throw new Error('Source must be a single-frame PNG');
  }
  const supportedProductionCanvas = [[384, 320], [192, 160]]
    .some(([w, h]) => imageMetadata.width === w && imageMetadata.height === h);
  if (stage === 'production' && !supportedProductionCanvas) {
    throw new Error('Production source must have the 384 x 320 character canvas or preserved legacy 192 x 160 canvas');
  }
  if (left + width > imageMetadata.width || top + height > imageMetadata.height) {
    throw new Error('Crop rectangle extends outside the source; choose it after inspecting the image');
  }
  for (const output of Object.values(outputs)) {
    try {
      await fs.lstat(output);
    } catch (error) {
      if (error.code === 'ENOENT') continue;
      throw error;
    }
    throw new Error(`Output already exists; use a new version: ${output}`);
  }

  // Decode once. Sample nearest pixels directly to preserve RGBA, including
  // low-alpha colors, without alpha premultiplication or interpolation blur.
  const cropped = await sharp(sourceBytes).ensureAlpha()
    .extract({ left, top, width, height }).raw().toBuffer({ resolveWithObject: true });
  const outputSize = mode === 'portrait' ? 64 : width;
  const channels = cropped.info.channels;
  const pixels = Buffer.alloc(outputSize * outputSize * channels);
  for (let y = 0; y < outputSize; y++) {
    for (let x = 0; x < outputSize; x++) {
      const sourceX = Math.min(width - 1, Math.floor((x + 0.5) * width / outputSize));
      const sourceY = Math.min(height - 1, Math.floor((y + 0.5) * height / outputSize));
      const from = (sourceY * width + sourceX) * channels;
      cropped.data.copy(pixels, (y * outputSize + x) * channels, from, from + channels);
    }
  }
  const raw = { width: outputSize, height: outputSize, channels };
  const portrait = await sharp(pixels, { raw }).png().toBuffer();
  // Replicate integer blocks directly. A resize pipeline can premultiply alpha
  // and round low-alpha RGB values even when its interpolation is nearest.
  const previewWidth = outputSize * previewScale;
  const previewHeight = outputSize * previewScale;
  const enlarged = Buffer.alloc(previewWidth * previewHeight * channels);
  for (let y = 0; y < previewHeight; y++) {
    for (let x = 0; x < previewWidth; x++) {
      const from = (Math.floor(y / previewScale) * outputSize + Math.floor(x / previewScale)) * channels;
      const to = (y * previewWidth + x) * channels;
      pixels.copy(enlarged, to, from, from + channels);
    }
  }
  const preview = await sharp(enlarged, { raw: { width: previewWidth, height: previewHeight, channels } })
    .png().toBuffer();
  const record = {
    stage,
    relationship: mode === 'exact' ? 'exact-crop' : 'concept-derived-matching-portrait',
    source: { path: sourcePath, sha256: sha256(sourceBytes), width: imageMetadata.width, height: imageMetadata.height },
    crop: { x: left, y: top, width, height, sourcePixelScale: outputSize / width },
    transform: { mode, filter: 'nearest', cleanup: 'None in this helper; finish in spritex JSON and export through its CLI.' },
    portrait: { file: path.basename(outputs.portrait), width: outputSize, height: outputSize, sha256: sha256(portrait) },
    preview: { file: path.basename(outputs.preview), scale: previewScale, filter: 'nearest', sha256: sha256(preview) },
    validation: { cropInBounds: true, squareCrop: true, outputDimensionsChecked: true, headCenteringAndObstructionsChecked: false, bodyHeightAndArtQualityChecked: false },
  };
  await fs.mkdir(path.dirname(prefix), { recursive: true });
  await fs.writeFile(outputs.portrait, portrait, { flag: 'wx' });
  await fs.writeFile(outputs.preview, preview, { flag: 'wx' });
  await fs.writeFile(outputs.metadata, `${JSON.stringify(record, null, 2)}\n`, { flag: 'wx' });
  return { outputs, record };
}

if (require.main === module) {
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    process.stdout.write(HELP);
  } else {
    Promise.resolve().then(() => extractPortrait(parseArguments(process.argv.slice(2))))
      .then((result) => process.stdout.write(`${JSON.stringify(result, null, 2)}\n`))
      .catch((error) => { process.stderr.write(`${error.message}\n`); process.exitCode = 1; });
  }
}

module.exports = { extractPortrait, parseArguments };
