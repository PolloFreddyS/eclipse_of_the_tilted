// Construye el sitio estático en dist/.
//
// Fuentes:
//   - GitHub Releases de este repo  -> "Jugar", descarga del APK e historial de versiones
//   - content/*.md (+ *.en.md)      -> secciones de texto editables, en español e inglés
//   - site/                         -> plantilla, estilos e imágenes
//
// Uso: node scripts/build.mjs
//   GITHUB_TOKEN, GITHUB_REPOSITORY  opcionales en local
//   RELEASES_FILE=ruta.json          usa releases de un archivo (pruebas) en vez de la API
//   PLAY_DIR=build/play              copia el juego web a dist/play/ y activa el botón "Jugar"
//   node scripts/build.mjs --latest-tag   solo imprime la etiqueta de la versión que se publica

import { cp, mkdir, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const SITE = join(ROOT, 'site');
const CONTENT = join(ROOT, 'content');
const DIST = join(ROOT, 'dist');
const REPO = process.env.GITHUB_REPOSITORY || 'PolloFreddyS/eclipse_of_the_tilted';
const TOKEN = process.env.GITHUB_TOKEN || process.env.GH_TOKEN || '';
const PLAY_DIR = process.env.PLAY_DIR ? resolve(process.env.PLAY_DIR) : '';
const WHATSAPP = 'https://whatsapp.com/channel/0029Vb8L8o82ER6ktNYvy327';

// Línea opcional en las notas para fijar la fecha: <!-- fecha: 2026-12-01 -->
const DATE_RE = /<!--\s*fecha:\s*(\d{4}-\d{2}-\d{2})\s*-->/i;
// Versión en inglés: el título en <!-- title-en: ... --> y las notas después de <!-- en -->.
// Sin ellas, el título y las notas en español se muestran en ambos idiomas.
const TITLE_EN_RE = /<!--\s*title-en:\s*(.*?)\s*-->/i;
const EN_RE = /<!--\s*en\s*-->/i;
const MONTHS = {
  es: ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'],
  en: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
};

const L = (es, en) => `<span data-l="es">${es}</span><span data-l="en">${en}</span>`;
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

function formatDate(iso) {
  const [y, m, d] = iso.slice(0, 10).split('-').map(Number);
  return L(`${d} ${MONTHS.es[m - 1]} ${y}`, `${MONTHS.en[m - 1]} ${d}, ${y}`);
}

const formatSize = (bytes) => (bytes >= 1048576 ? `${(bytes / 1048576).toFixed(0)} MB` : `${(bytes / 1024).toFixed(0)} KB`);

async function fetchReleases() {
  if (process.env.RELEASES_FILE) return JSON.parse(await readFile(process.env.RELEASES_FILE, 'utf8'));
  const headers = { Accept: 'application/vnd.github+json', 'User-Agent': 'eclipse-site' };
  if (TOKEN) headers.Authorization = `Bearer ${TOKEN}`;
  const out = [];
  for (let page = 1; ; page++) {
    const res = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=100&page=${page}`, { headers });
    if (!res.ok) throw new Error(`GitHub API ${res.status}: ${await res.text()}`);
    const batch = await res.json();
    out.push(...batch);
    if (batch.length < 100) return out;
  }
}

function normalize(r) {
  const body = r.body || '';
  const date = body.match(DATE_RE)?.[1] || r.published_at || r.created_at;
  const [es, ...en] = body.replace(DATE_RE, '').replace(TITLE_EN_RE, '').split(EN_RE);
  const esHtml = marked.parse(es.trim() || '_Sin notas._');
  const enText = en.join('\n').trim();
  const apk = r.assets.find((a) => /\.apk$/i.test(a.name)) || null;
  return {
    tag: r.tag_name,
    name: r.name || r.tag_name,
    nameEn: body.match(TITLE_EN_RE)?.[1] || null,
    date: date.slice(0, 10),
    sortKey: `${date.slice(0, 10)}|${r.published_at || r.created_at}`,
    prerelease: r.prerelease,
    url: r.html_url,
    notesHtml: enText ? `<div data-l="es">${esHtml}</div><div data-l="en">${marked.parse(enText)}</div>` : esHtml,
    apk: apk && {
      name: apk.name,
      size: apk.size,
      url: apk.browser_download_url,
      sha256: apk.digest?.startsWith('sha256:') ? apk.digest.slice(7) : null,
    },
  };
}

async function loadReleases() {
  return (await fetchReleases())
    .filter((r) => !r.draft)
    .map(normalize)
    .sort((a, b) => b.sortKey.localeCompare(a.sortKey));
}

// La versión que se juega en el sitio: la estable más reciente o, si solo hay betas, la beta más reciente.
const pickLatest = (releases) => releases.find((r) => !r.prerelease) || releases[0] || null;

const relName = (r) => (r.nameEn ? L(esc(r.name), esc(r.nameEn)) : esc(r.name));

function renderStatus(latest, canPlay) {
  if (!latest) {
    return `<p class="status">${L('Próximamente', 'Coming soon')}</p>`;
  }
  return `<p class="status status-live">${latest.prerelease ? L('Beta disponible', 'Beta available') : L('Ya disponible', 'Out now')}</p>
<div class="hero-actions">
  ${canPlay ? `<a class="btn btn-primary" href="play/">${L('Jugar ahora', 'Play now')}</a>` : ''}
  <a class="btn btn-ghost" href="#jugar">${L('Más opciones', 'More options')}</a>
</div>`;
}

function renderPlay(latest, canPlay) {
  if (!latest) {
    return `<div class="panel soon">
  <h3>${L('La primera beta todavía no está lista', 'The first beta is not ready yet')}</h3>
  <p>${L('Cuando salga podrás jugar aquí mismo, en el navegador del celular o de la PC, o instalar la versión para Android. Síguenos en WhatsApp para enterarte primero.', 'When it comes out you will be able to play right here, in your phone or PC browser, or install the Android version. Follow us on WhatsApp to hear about it first.')}</p>
  <a class="btn btn-whatsapp" href="${WHATSAPP}" rel="noopener">${L('Síguenos en WhatsApp', 'Follow us on WhatsApp')}</a>
</div>`;
  }
  const apk = latest.apk;
  return `<div class="panel latest">
  <div class="latest-head">
    <span class="tag">${latest.prerelease ? 'Beta' : L('Última versión', 'Latest version')}</span>
    <span class="muted">${formatDate(latest.date)}</span>
  </div>
  <h3>${relName(latest)}</h3>
  <div class="play-options">
    ${canPlay ? `<div class="option-card">
      <h4>${L('En el navegador', 'In your browser')}</h4>
      <p>${L('Celular o PC, sin instalar nada.', 'Phone or PC, nothing to install.')}</p>
      <a class="btn btn-primary" href="play/">${L('Jugar ahora', 'Play now')}</a>
    </div>` : ''}
    ${apk ? `<div class="option-card">
      <h4>Android</h4>
      <p>${L('Instala el APK para mejor rendimiento.', 'Install the APK for better performance.')}</p>
      <a class="btn btn-ghost" href="${esc(apk.url)}">${L('Descargar APK', 'Download APK')}</a>
      <p class="file-meta"><code>${esc(apk.name)}</code> · ${esc(formatSize(apk.size))}</p>
      ${apk.sha256 ? `<p class="hash">SHA-256 <code>${esc(apk.sha256)}</code></p>` : ''}
    </div>` : ''}
  </div>
  <a class="link" href="#v-${esc(latest.tag)}">${L('Ver qué cambió', 'See what changed')} →</a>
</div>`;
}

function renderChangelog(releases, latestTag) {
  if (!releases.length) return `<p class="muted">${L('Aún no hay versiones publicadas.', 'No versions released yet.')}</p>`;
  return releases
    .map((r) => `<article class="release" id="v-${esc(r.tag)}">
  <header class="release-head">
    <h3><a href="#v-${esc(r.tag)}">${relName(r)}</a></h3>
    <div class="release-meta">
      <time datetime="${esc(r.date)}">${formatDate(r.date)}</time>
      <span class="chip">${esc(r.tag)}</span>
      ${r.tag === latestTag ? `<span class="tag">${L('Actual', 'Current')}</span>` : ''}
      ${r.prerelease ? '<span class="tag tag-beta">Beta</span>' : ''}
    </div>
  </header>
  <div class="notes">${r.notesHtml}</div>
  <footer class="release-foot">
    ${r.apk ? `<a class="link" href="${esc(r.apk.url)}">APK (${esc(formatSize(r.apk.size))})</a>` : ''}
    <a class="link" href="${esc(r.url)}">${L('Ver en GitHub', 'View on GitHub')}</a>
  </footer>
</article>`)
    .join('\n');
}

// Preguntas frecuentes: cada "### Pregunta" del markdown se vuelve un desplegable.
function renderFaq(md) {
  return md
    .split(/^### /m)
    .slice(1)
    .map((block) => {
      const [q, ...a] = block.split('\n');
      return `<details><summary>${esc(q.trim())}</summary>${marked.parse(a.join('\n').trim())}</details>`;
    })
    .join('\n');
}

async function renderContent(html) {
  const files = existsSync(CONTENT) ? await readdir(CONTENT) : [];
  for (const f of files.filter((f) => f.endsWith('.md') && !f.endsWith('.en.md'))) {
    const key = f.replace(/\.md$/, '');
    const render = key === 'faq' ? renderFaq : (md) => marked.parse(md);
    const es = render(await readFile(join(CONTENT, f), 'utf8'));
    const enFile = join(CONTENT, `${key}.en.md`);
    const out = existsSync(enFile) ? `<div data-l="es">${es}</div><div data-l="en">${render(await readFile(enFile, 'utf8'))}</div>` : es;
    html = html.replaceAll(`<!--CONTENT:${key}-->`, out);
  }
  return html.replace(/<!--CONTENT:[\w-]+-->/g, '');
}

async function renderScreens() {
  const dir = join(SITE, 'assets', 'capturas');
  const shots = existsSync(dir) ? (await readdir(dir)).filter((f) => /\.(webp|png|jpe?g)$/i.test(f)).sort() : [];
  if (!shots.length) {
    return `<p class="muted">${L('Las capturas llegan con la primera beta.', 'Screenshots arrive with the first beta.')}</p>`;
  }
  return `<div class="shots">${shots.map((f) => `<img src="assets/capturas/${esc(f)}" alt="" loading="lazy" width="640" height="360">`).join('')}</div>`;
}

async function main() {
  const releases = await loadReleases();
  const latest = pickLatest(releases);
  if (process.argv.includes('--latest-tag')) {
    console.log(latest?.tag ?? '');
    return;
  }

  const canPlay = Boolean(latest && PLAY_DIR && existsSync(join(PLAY_DIR, 'index.html')));
  const builtAt = new Date().toISOString();

  let html = await readFile(join(SITE, 'index.html'), 'utf8');
  html = html
    .replace('<!--STATUS-->', renderStatus(latest, canPlay))
    .replace('<!--PLAY-->', renderPlay(latest, canPlay))
    .replace('<!--CHANGELOG-->', renderChangelog(releases, latest?.tag))
    .replace('<!--SCREENS-->', await renderScreens())
    .replaceAll('<!--REPO-->', esc(REPO))
    .replaceAll('<!--WHATSAPP-->', WHATSAPP)
    .replace('<!--BUILT_AT-->', `<time datetime="${builtAt}">${formatDate(builtAt)}</time>`);
  html = await renderContent(html);

  await rm(DIST, { recursive: true, force: true });
  await mkdir(DIST, { recursive: true });
  await cp(SITE, DIST, { recursive: true });
  await writeFile(join(DIST, 'index.html'), html);
  if (canPlay) await cp(PLAY_DIR, join(DIST, 'play'), { recursive: true });
  await writeFile(
    join(DIST, 'releases.json'),
    JSON.stringify({ repo: REPO, builtAt, latest: latest?.tag ?? null, releases: releases.map(({ notesHtml, sortKey, ...r }) => r) }, null, 2),
  );
  console.log(`Built ${releases.length} release(s); latest = ${latest?.tag ?? 'none'}; play = ${canPlay ? 'yes' : 'no'}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
