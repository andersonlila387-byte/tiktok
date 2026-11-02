// Draws the app icons (a rising bar chart on dark) into pulse_analytics/web.
// Pure Node, no dependencies:  node scripts/make-icons.js
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const OUT = path.join(__dirname, '..', 'pulse_analytics', 'web');
const BG = [22, 24, 35];
const BARS = [
  { x: 0.22, h: 0.22, c: [125, 185, 239] },
  { x: 0.43, h: 0.34, c: [10, 114, 216] },
  { x: 0.64, h: 0.5, c: [255, 255, 255] },
];
const BAR_W = 0.14;
const BASE = 0.74;

/** Colour at unit-square point (x, y), or null when transparent. */
function sample(x, y, rounded) {
  if (rounded) {
    const r = 0.22;
    const cx = Math.min(Math.max(x, r), 1 - r);
    const cy = Math.min(Math.max(y, r), 1 - r);
    if ((x - cx) ** 2 + (y - cy) ** 2 > r * r) return null;
  }
  for (const b of BARS) {
    if (x >= b.x && x <= b.x + BAR_W && y <= BASE && y >= BASE - b.h) return b.c;
  }
  return BG;
}

function render(size, rounded) {
  const rows = [];
  const N = 3;
  for (let py = 0; py < size; py++) {
    const row = Buffer.alloc(1 + size * 4);
    for (let px = 0; px < size; px++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < N; sy++) {
        for (let sx = 0; sx < N; sx++) {
          const c = sample((px + (sx + 0.5) / N) / size, (py + (sy + 0.5) / N) / size, rounded);
          if (c) { r += c[0]; g += c[1]; b += c[2]; a++; }
        }
      }
      const o = 1 + px * 4;
      if (a) {
        row[o] = Math.round(r / a);
        row[o + 1] = Math.round(g / a);
        row[o + 2] = Math.round(b / a);
        row[o + 3] = Math.round((a / (N * N)) * 255);
      }
    }
    rows.push(row);
  }
  return png(size, Buffer.concat(rows));
}

function png(size, raw) {
  const chunk = (type, data) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(zlib.crc32(body) >>> 0);
    return Buffer.concat([len, body, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

const files = {
  'icons/Icon-192.png': render(192, true),
  'icons/Icon-512.png': render(512, true),
  'icons/Icon-maskable-192.png': render(192, false),
  'icons/Icon-maskable-512.png': render(512, false),
  'favicon.png': render(64, true),
};
for (const [name, data] of Object.entries(files)) {
  fs.writeFileSync(path.join(OUT, name), data);
  console.log('wrote', name, data.length, 'bytes');
}
