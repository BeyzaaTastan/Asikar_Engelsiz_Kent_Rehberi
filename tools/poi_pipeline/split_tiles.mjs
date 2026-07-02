// ND-JSON (tile'a göre sıralı) → z12 tile dosyaları: tiles/x=<x>/y=<y>/data_0.json
// Bağımlılık YOK (Node yerleşik fs/readline). Bellek-güvenli: aynı anda tek tile bellekte.
//
// Kullanım:
//   node tools/poi_pipeline/split_tiles.mjs
//   node tools/poi_pipeline/split_tiles.mjs <input.json> <out_dir>
//
// Girdi, extract_turkey_pois.sql'in ürettiği `pois_with_tiles.json` (x,y ile, ORDER BY x,y).

import fs from 'fs';
import path from 'path';
import readline from 'readline';

const IN = process.argv[2] || 'tools/poi_pipeline/pois_with_tiles.json';
const OUT = process.argv[3] || 'tools/poi_pipeline/tiles';

if (!fs.existsSync(IN)) {
  console.error(`Girdi yok: ${IN} — önce extract_turkey_pois.sql'i çalıştır.`);
  process.exit(1);
}
// Temiz başla (eski tile'lar kalmasın)
fs.rmSync(OUT, { recursive: true, force: true });

const rl = readline.createInterface({
  input: fs.createReadStream(IN),
  crlfDelay: Infinity,
});

let curKey = null, curX = null, curY = null, buf = [], files = 0, rows = 0, skipped = 0;

function flush() {
  if (curKey === null) return;
  const dir = path.join(OUT, `x=${curX}`, `y=${curY}`);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'data_0.json'), JSON.stringify(buf));
  files++;
  buf = [];
}

for await (const line of rl) {
  const s = line.trim();
  if (!s) continue;
  let o;
  try {
    o = JSON.parse(s);
  } catch {
    skipped++;        // bozuk/yarım satırı atla (gömülü newline vb.)
    continue;
  }
  const key = `${o.x}/${o.y}`;
  if (key !== curKey) {
    flush();
    curKey = key; curX = o.x; curY = o.y;
  }
  delete o.x; delete o.y;        // x,y dosya içine yazılmaz (Worker lat/lon kullanır)
  buf.push(o);
  rows++;
}
flush();

console.log(`${files} tile dosyası, ${rows} POI yazıldı → ${OUT}` +
  (skipped ? `  (atlanan bozuk satır: ${skipped})` : ''));
