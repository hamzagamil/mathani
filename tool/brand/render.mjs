// Renders the brand SVGs (tool/brand/*.svg, downloaded unmodified from the Mathani brand design
// system) into every raster the app needs. Logos are scaled, never redrawn (brand guide).
//   cd tool/brand && npm ci && node render.mjs
import { Resvg } from '@resvg/resvg-js';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const svg = (name) => readFileSync(join(here, `${name}.svg`), 'utf8');

const NAVY = '#183159'; // brand-navy / bar (launch background)
const LOGO_GREEN = '#062516'; // logo tile ground (adaptive icon background)

/** Renders [source] to a [size]×[size] PNG: the artwork scaled to [fill] of the canvas, centred. */
function render(source, size, { fill = 1, background } = {}) {
  const inner = Math.round(size * fill);
  const art = new Resvg(source, { fitTo: { mode: 'width', value: inner } }).render();
  if (fill === 1 && !background) return art.asPng();
  // Compose on a square canvas with an SVG wrapper so the artwork stays vector until rasterised.
  const b64 = Buffer.from(art.asPng()).toString('base64');
  const x = Math.round((size - art.width) / 2), y = Math.round((size - art.height) / 2);
  const canvas = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}">` +
    (background ? `<rect width="100%" height="100%" fill="${background}"/>` : '') +
    `<image x="${x}" y="${y}" width="${art.width}" height="${art.height}" href="data:image/png;base64,${b64}"/></svg>`;
  return new Resvg(canvas).render().asPng();
}

function write(path, png) {
  const full = join(root, path);
  mkdirSync(dirname(full), { recursive: true });
  writeFileSync(full, png);
  console.log(path);
}

// In-app images (Flutter resolution-aware assets: 1x, 2.0x, 3.0x).
for (const [name, file, base] of [
  ['mark_navy', 'mathani-mark-navy', 96], // empty states (on cream surface)
]) {
  for (const [dir, scale] of [['', 1], ['2.0x/', 2], ['3.0x/', 3]]) {
    write(`assets/images/${dir}${name}.png`, new Resvg(svg(file), { fitTo: { mode: 'width', value: base * scale } }).render().asPng());
  }
}

// Android launcher icons: legacy full-bleed square, plus adaptive foreground (mark inside the
// 66/108 safe zone) on the logo-green background.
const androidDensities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
for (const [d, s] of Object.entries(androidDensities)) {
  write(`android/app/src/main/res/mipmap-${d}/ic_launcher.png`, render(svg('mathani-app-icon'), Math.round(48 * s)));
  write(`android/app/src/main/res/mipmap-${d}/ic_launcher_foreground.png`,
    render(svg('mathani-mark-gold'), Math.round(108 * s), { fill: 0.52 }));
  // Launch mark: 96 dp, centred on navy by the launch drawable.
  write(`android/app/src/main/res/drawable-${d}/launch_mark.png`, render(svg('mathani-mark-gold'), Math.round(96 * s)));
  // Android 12+ splash icon: 288 dp canvas, mark inside the 192 dp visible circle.
  write(`android/app/src/main/res/drawable-${d}/splash_icon.png`,
    render(svg('mathani-mark-gold'), Math.round(288 * s), { fill: 0.42 }));
}
writeFileSync(join(root, 'android/app/src/main/res/values/ic_launcher_background.xml'),
  `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">${LOGO_GREEN}</color>\n    <color name="launch_background">${NAVY}</color>\n</resources>\n`);

// iOS app icon set: every size in the existing Contents.json (opaque, full-bleed).
const iconSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const contents = JSON.parse(readFileSync(join(root, iconSet, 'Contents.json'), 'utf8'));
for (const image of contents.images) {
  if (!image.filename) continue;
  const px = Math.round(parseFloat(image.size) * parseInt(image.scale));
  write(`${iconSet}/${image.filename}`, render(svg('mathani-app-icon'), px, { background: LOGO_GREEN }));
}

// iOS launch image: the gold mark at 120 pt, centred on navy by LaunchScreen.storyboard.
for (const [suffix, scale] of [['', 1], ['@2x', 2], ['@3x', 3]]) {
  write(`ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage${suffix}.png`,
    render(svg('mathani-mark-gold'), 120 * scale));
}

// Web app (specs/008 T066): the full-bleed icon for tabs and installs, and maskable icons with
// the gold mark inside the 80% safe zone on the logo green.
write('web/favicon.png', render(svg('mathani-app-icon'), 32, { background: LOGO_GREEN }));
for (const size of [192, 512]) {
  write(`web/icons/Icon-${size}.png`, render(svg('mathani-app-icon'), size, { background: LOGO_GREEN }));
  write(`web/icons/Icon-maskable-${size}.png`,
    render(svg('mathani-mark-gold'), size, { fill: 0.56, background: LOGO_GREEN }));
}
