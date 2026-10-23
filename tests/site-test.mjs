// Prueba del sitio: build con releases de ejemplo + revisión en navegador (celular y PC).
// Uso: node site-test.mjs   (desde tests/, después de npm install en la raíz y en tests/)
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const DIST = path.join(ROOT, 'dist');
const SHOTS = path.join(ROOT, 'test-results', 'sitio');
const TMP = fs.mkdtempSync(path.join(process.env.TMPDIR || os.tmpdir(), 'eclipse-site-'));
const LOCAL_CHROMIUM = '/opt/pw-browsers/chromium-1243/chrome-linux64/chrome';
fs.mkdirSync(SHOTS, { recursive: true });

const results = [];
function check(name, ok, detail = '') {
  results.push({ name, ok });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  — ' + detail : ''}`);
}

const asset = (name, size) => ({ name, size, browser_download_url: `https://github.com/x/y/releases/download/t/${name}`, digest: 'sha256:' + 'ab'.repeat(32) });
const FIXTURE = [
  { tag_name: 'v0.3.0-beta', name: 'Borrador secreto', draft: true, prerelease: true, published_at: null, created_at: '2026-12-20T10:00:00Z',
    html_url: 'https://github.com/x/y/releases/v0.3.0-beta', body: 'Notas de un borrador que nadie debe ver.', assets: [asset('borrador.apk', 1)] },
  { tag_name: 'v0.2.0-beta', name: 'Beta 2: ajustes', draft: false, prerelease: true, published_at: '2026-12-10T10:00:00Z', created_at: '2026-12-10T10:00:00Z',
    html_url: 'https://github.com/x/y/releases/v0.2.0-beta',
    body: '<!-- title-en: Beta 2: tweaks -->\n- Ajustes de balance.\n- Corrección de errores.\n<!-- en -->\n- Balance adjustments.\n- Bug fixes.',
    assets: [asset('eclipse-of-the-tilted-v0.2.0-beta.apk', 58 * 1048576)] },
  { tag_name: 'v0.1.0-beta', name: 'Primera beta', draft: false, prerelease: true, published_at: '2026-12-01T10:00:00Z', created_at: '2026-12-01T10:00:00Z',
    html_url: 'https://github.com/x/y/releases/v0.1.0-beta', body: 'Primera beta pública.', assets: [] },
];

function build(name, releases, playDir) {
  const file = path.join(TMP, `${name}.json`);
  fs.writeFileSync(file, JSON.stringify(releases));
  const env = { ...process.env, RELEASES_FILE: file };
  delete env.PLAY_DIR;
  if (playDir) env.PLAY_DIR = playDir;
  execFileSync('node', ['scripts/build.mjs'], { cwd: ROOT, env, stdio: 'pipe' });
  const out = path.join(TMP, name);
  fs.cpSync(DIST, out, { recursive: true });
  return { dir: out, html: fs.readFileSync(path.join(out, 'index.html'), 'utf8'), json: JSON.parse(fs.readFileSync(path.join(out, 'releases.json'), 'utf8')) };
}

// Un "juego" mínimo para no depender del export de Godot en esta prueba.
const fakePlay = path.join(TMP, 'play');
fs.mkdirSync(fakePlay, { recursive: true });
fs.writeFileSync(path.join(fakePlay, 'index.html'), '<!doctype html><title>juego</title>');

// ---------- 1. Sin versiones: "Próximamente" y ningún enlace de descarga ----------
const empty = build('vacio', [], fakePlay);
check('Vacío: dice "Próximamente"', empty.html.includes('Próximamente') && empty.html.includes('Coming soon'));
check('Vacío: sin enlaces de descarga ni de juego', !/href="[^"]*\.apk"/.test(empty.html) && !empty.html.includes('href="play/"') && !fs.existsSync(path.join(empty.dir, 'play')));
check('Vacío: releases.json sin versiones', empty.json.latest === null && empty.json.releases.length === 0);
check('Vacío: botón de WhatsApp con el canal correcto', empty.html.includes('https://whatsapp.com/channel/0029Vb8L8o82ER6ktNYvy327'));
check('Vacío: no quedan marcadores sin reemplazar', !/<!--(STATUS|PLAY|CHANGELOG|SCREENS|REPO|WHATSAPP|BUILT_AT|CONTENT:[\w-]+)-->/.test(empty.html));

// ---------- 2. Con versiones: borrador oculto, betas, notas bilingües ----------
const full = build('versiones', FIXTURE, fakePlay);
check('Versiones: el borrador no aparece en la página', !full.html.includes('Borrador secreto') && !full.html.includes('borrador.apk') && !full.html.includes('v0.3.0'));
check('Versiones: el borrador no aparece en releases.json', !JSON.stringify(full.json).includes('v0.3.0'));
check('Versiones: la más reciente es la actual', full.json.latest === 'v0.2.0-beta', `latest=${full.json.latest}`);
check('Versiones: título en inglés separado', full.html.includes('<span data-l="es">Beta 2: ajustes</span><span data-l="en">Beta 2: tweaks</span>'));
check('Versiones: notas en inglés separadas', /<div data-l="es">[\s\S]*Ajustes de balance[\s\S]*<\/div><div data-l="en">[\s\S]*Balance adjustments/.test(full.html));
check('Versiones: el comentario title-en no se filtra a las notas', !full.html.includes('title-en'));
check('Versiones: sin notas en inglés se usa el español', full.html.includes('Primera beta pública.'));
check('Versiones: botón "Jugar ahora" y juego copiado', full.html.includes('href="play/"') && fs.existsSync(path.join(full.dir, 'play', 'index.html')));
check('Versiones: enlace al APK', full.html.includes('eclipse-of-the-tilted-v0.2.0-beta.apk'));
check('Versiones: etiqueta Beta y "Beta disponible"', full.html.includes('tag-beta') && full.html.includes('Beta disponible'));

// ---------- 3. Versión sin juego web: solo APK ----------
const apkOnly = build('solo-apk', FIXTURE, null);
check('Solo APK: sin botón "Jugar ahora"', !apkOnly.html.includes('href="play/"'));
check('Solo APK: con enlace al APK', apkOnly.html.includes('.apk"'));

// ---------- Navegador: celular y PC ----------
function serve(dir) {
  const MIME = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.webp': 'image/webp', '.jpg': 'image/jpeg' };
  const server = http.createServer((req, res) => {
    const file = path.join(dir, decodeURIComponent(new URL(req.url, 'http://x').pathname).replace(/\/$/, '/index.html'));
    if (!file.startsWith(dir) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] ?? 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
  }).listen(0);
  return server;
}

const browser = await chromium.launch(fs.existsSync(LOCAL_CHROMIUM) ? { executablePath: LOCAL_CHROMIUM } : {});
for (const [label, site] of [['vacio', empty], ['versiones', full]]) {
  const server = serve(site.dir);
  const url = `http://127.0.0.1:${server.address().port}/`;
  for (const [device, opts] of [['celular', { viewport: { width: 375, height: 812 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 }], ['pc', { viewport: { width: 1280, height: 800 } }]]) {
    const context = await browser.newContext(opts);
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    page.on('requestfailed', (r) => { if (!r.url().includes('fonts.g')) errors.push('falló ' + r.url()); });
    await page.goto(url, { waitUntil: 'networkidle' }).catch(() => page.goto(url, { waitUntil: 'load' }));
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    check(`${label}/${device}: sin desplazamiento horizontal`, overflow <= 0, `sobra ${overflow}px`);
    const es = await page.locator('#juego h2').innerText();
    await page.click('[data-set-lang="en"]');
    const en = await page.locator('#juego h2').innerText();
    await page.reload();
    const remembered = await page.locator('#juego h2').innerText();
    check(`${label}/${device}: cambia a inglés y lo recuerda`, es === 'El Corral ha caído' && en === 'The Corral has fallen' && remembered === en, `${es} → ${en} → ${remembered}`);
    await page.click('[data-set-lang="es"]');
    check(`${label}/${device}: sin errores ni recursos rotos`, errors.length === 0, errors.slice(0, 3).join(' | '));
    await page.screenshot({ path: path.join(SHOTS, `${label}-${device}.png`), fullPage: true });
    await context.close();
  }
  server.close();
}
await browser.close();
fs.rmSync(TMP, { recursive: true, force: true });

const failed = results.filter((r) => !r.ok).length;
console.log(`\n${results.length - failed}/${results.length} comprobaciones pasaron. Capturas en test-results/sitio/`);
process.exit(failed ? 1 : 0);
