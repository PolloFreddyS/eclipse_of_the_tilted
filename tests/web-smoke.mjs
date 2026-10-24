// Prueba de humo del build web: teclado, control (simulado) y pantalla táctil.
// Sirve build/web sin cabeceras especiales, igual que GitHub Pages.
// Uso: node web-smoke.mjs [carpeta-del-build] [carpeta-de-capturas]
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { chromium } from "playwright";

const ROOT = path.resolve(process.argv[2] ?? "../build/web");
const SHOTS = path.resolve(process.argv[3] ?? "../test-results");
// Si existe el Chromium preinstalado de este entorno se usa; en CI se usa el de Playwright.
const LOCAL_CHROMIUM = "/opt/pw-browsers/chromium-1243/chrome-linux64/chrome";
const CHROMIUM = process.env.CHROMIUM_PATH ?? (fs.existsSync(LOCAL_CHROMIUM) ? LOCAL_CHROMIUM : undefined);
const MIME = { ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm", ".pck": "application/octet-stream", ".png": "image/png" };

// Si algo se cuelga (por ejemplo, el navegador deja de responder), la prueba falla en vez de esperar para siempre.
const WATCHDOG = setTimeout(() => { console.log("FAIL  la prueba tardó más de 4 minutos"); process.exit(1); }, 4 * 60 * 1000);
fs.mkdirSync(SHOTS, { recursive: true });
const server = http.createServer((req, res) => {
  const file = path.join(ROOT, decodeURIComponent(new URL(req.url, "http://x").pathname).replace(/\/$/, "/index.html"));
  if (!file.startsWith(ROOT) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { "Content-Type": MIME[path.extname(file)] ?? "application/octet-stream" });
  fs.createReadStream(file).pipe(res);
}).listen(0);
const URL_ = `http://127.0.0.1:${server.address().port}/`;

const results = [];
function check(name, ok, detail = "") {
  results.push({ name, ok, detail });
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? "  — " + detail : ""}`);
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// Además de leer el estado, anota cada animación que se vio para comprobar que todas se reproducen.
const seenAnims = new Set();
const state = async (page) => {
  const s = await page.evaluate(() => (window.__eclipse ? JSON.parse(window.__eclipse) : null));
  if (s?.player?.anim) seenAnims.add(s.player.anim);
  return s;
};
async function watchAnims(page, ms) {
  for (let t = 0; t < ms; t += 40) { await state(page); await sleep(40); }
}

async function boot(context, label, query = "") {
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e)));
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  const t0 = Date.now();
  await page.goto(URL_ + query);
  await page.waitForFunction(() => window.__eclipse && JSON.parse(window.__eclipse).player?.on_floor, null, { timeout: 90000 });
  check(`${label}: el juego carga`, true, `${((Date.now() - t0) / 1000).toFixed(1)} s`);
  return { page, errors };
}

const browser = await chromium.launch({ executablePath: CHROMIUM, args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });

// ---------- Teclado (PC) ----------
{
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const { page, errors } = await boot(context, "Teclado");
  await page.mouse.click(640, 360);
  const s0 = await state(page);

  // Salto en la posición inicial, donde no hay plataformas encima.
  // Se registra el punto más alto de todo el salto: una sola muestra puede llegar tarde.
  const s1 = s0;
  await page.keyboard.down("Space");
  let peak = s1.player.y;
  for (let t = 0; t < 12; t++) { await sleep(50); peak = Math.min(peak, (await state(page)).player.y); }
  await page.keyboard.up("Space"); await watchAnims(page, 1200);
  const s2 = await state(page);
  check("Teclado: espacio salta y vuelve al suelo", peak < s1.player.y - 40 && s2.player.on_floor && s2.player.jumps === 1, `y ${s1.player.y.toFixed(0)} → pico ${peak.toFixed(0)} → ${s2.player.y.toFixed(0)}`);

  const sBefore = await state(page);
  await page.keyboard.down("ArrowRight"); await watchAnims(page, 1000); await page.keyboard.up("ArrowRight");
  const sAfter = await state(page);
  check("Teclado: flecha derecha mueve al pollito", sAfter.player.x > sBefore.player.x + 80, `x ${sBefore.player.x.toFixed(0)} → ${sAfter.player.x.toFixed(0)}`);

  // Caminar hasta el muñeco (x = 760) y golpearlo.
  await page.keyboard.down("ArrowRight");
  await page.waitForFunction(() => JSON.parse(window.__eclipse).player.x > 715, null, { timeout: 10000 }).catch(() => {});
  await page.keyboard.up("ArrowRight"); await sleep(400);
  for (let i = 0; i < 3; i++) { await page.keyboard.press("j"); await sleep(350); }
  const s3 = await state(page);
  check("Teclado: J golpea al muñeco", s3.dummy_hits >= 3, `golpes ${s3.dummy_hits}, ataques ${s3.player.attacks}`);

  await page.keyboard.press("j"); await watchAnims(page, 300);
  await page.keyboard.press("Shift"); await watchAnims(page, 400);
  const s4 = await state(page);
  check("Teclado: Shift esquiva", s4.player.dodges === 1);
  await watchAnims(page, 400);
  const expected = ["idle", "run", "jump", "fall", "attack", "dodge"];
  check("Teclado: se ven todas las animaciones del pollito", expected.every((a) => seenAnims.has(a)), [...seenAnims].join(", "));
  check("Teclado: se detecta 'Teclado'", s4.device === "Teclado");
  check("Teclado: botones táctiles ocultos en PC", s4.touch_visible === false);

  await page.keyboard.down("ArrowLeft"); await sleep(150); await page.keyboard.press("j"); await sleep(60);
  await page.screenshot({ path: path.join(SHOTS, "pc-teclado.png") });
  await page.keyboard.up("ArrowLeft");
  check("Teclado: sin errores en consola", errors.length === 0, errors.slice(0, 3).join(" | "));
  await context.close();
}

// ---------- Control (Gamepad API simulada) ----------
{
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  await context.addInitScript(() => {
    const pad = {
      id: "Xbox Wireless Controller (STANDARD GAMEPAD)", index: 0, connected: true, mapping: "standard",
      axes: [0, 0, 0, 0], buttons: Array.from({ length: 17 }, () => ({ pressed: false, touched: false, value: 0 })), timestamp: 0,
    };
    window.__pad = pad;
    navigator.getGamepads = () => [pad, null, null, null];
    window.__padSet = (axes, buttons) => {
      pad.axes = axes; pad.timestamp = performance.now();
      pad.buttons = pad.buttons.map((_, i) => ({ pressed: !!buttons[i], touched: !!buttons[i], value: buttons[i] ? 1 : 0 }));
    };
    window.addEventListener("load", () => {
      const ev = new Event("gamepadconnected"); Object.defineProperty(ev, "gamepad", { value: pad }); window.dispatchEvent(ev);
    });
  });
  const { page, errors } = await boot(context, "Control");
  const s0 = await state(page);
  await page.evaluate(() => window.__padSet([1, 0, 0, 0], []));
  await sleep(1000);
  await page.evaluate(() => window.__padSet([0, 0, 0, 0], []));
  await sleep(300);
  const s1 = await state(page);
  check("Control: palanca izquierda mueve al pollito", s1.player.x > s0.player.x + 80, `x ${s0.player.x.toFixed(0)} → ${s1.player.x.toFixed(0)}`);
  await page.evaluate(() => window.__padSet([0, 0, 0, 0], [true])); await sleep(200);
  await page.evaluate(() => window.__padSet([0, 0, 0, 0], [])); await sleep(1200);
  const s2 = await state(page);
  check("Control: botón A salta", s2.player.jumps === 1);
  check("Control: se detecta 'Control'", s2.device === "Control", `device=${s2.device}`);
  check("Control: sin errores en consola", errors.length === 0, errors.slice(0, 3).join(" | "));
  await context.close();
}

// ---------- Pantalla táctil (celular Android en horizontal) ----------
{
  const context = await browser.newContext({
    viewport: { width: 844, height: 390 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true,
    userAgent: "Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36",
  });
  const { page, errors } = await boot(context, "Táctil");
  const s0 = await state(page);
  check("Táctil: botones visibles al abrir en celular", s0.touch_visible === true);

  // Coordenadas del juego → píxeles de la pantalla.
  const box = await page.locator("canvas").boundingBox();
  const toScreen = ([x, y]) => ({ x: box.x + (x * box.width) / s0.viewport[0], y: box.y + (y * box.height) / s0.viewport[1] });
  const right = toScreen(s0.touch_buttons.move_right);
  const jump = toScreen(s0.touch_buttons.jump);
  const cdp = await context.newCDPSession(page);
  const touch = (type, points) => cdp.send("Input.dispatchTouchEvent", { type, touchPoints: points });

  await touch("touchStart", [{ ...right, id: 0 }]);
  await sleep(900);
  const s1 = await state(page);
  check("Táctil: mantener ▶ mueve al pollito", s1.player.x > s0.player.x + 60, `x ${s0.player.x.toFixed(0)} → ${s1.player.x.toFixed(0)}`);

  // Segundo dedo en Saltar mientras el primero sigue en ▶.
  await touch("touchStart", [{ ...right, id: 0 }, { ...jump, id: 1 }]);
  await sleep(200);
  await page.screenshot({ path: path.join(SHOTS, "celular-tactil.png") });
  await touch("touchEnd", [{ ...right, id: 0 }]);
  await sleep(300);
  const s2 = await state(page);
  await touch("touchEnd", []);
  await sleep(1200);
  const s3 = await state(page);
  check("Táctil: dos dedos a la vez (correr + saltar)", s2.player.jumps === 1 && s2.player.x > s1.player.x, `saltos ${s2.player.jumps}, x ${s1.player.x.toFixed(0)} → ${s2.player.x.toFixed(0)}`);
  check("Táctil: al soltar, el pollito se detiene", Math.abs(s3.player.x - (await state(page)).player.x) < 1 && s3.player.on_floor);
  check("Táctil: se detecta 'Táctil'", s3.device === "Táctil", `device=${s3.device}`);
  check("Táctil: sin errores en consola", errors.length === 0, errors.slice(0, 3).join(" | "));
  await context.close();
}

// ---------- Vida: Santuario, daño, invulnerabilidad, muerte y reaparición ----------
{
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const { page, errors } = await boot(context, "Vida", "?pruebas");
  await page.mouse.click(640, 360);
  await page.keyboard.down("ArrowRight"); await sleep(600); await page.keyboard.up("ArrowRight");
  const s0 = await state(page);
  check("Vida: tocar el Santuario lo guarda como punto de reaparición", Math.abs(s0.player.respawn_x - 150) < 1 && s0.player.hp === 100, `respawn_x=${s0.player.respawn_x}`);

  // Se pone sobre las espinas (x 1040-1104) una y otra vez hasta caer.
  const timeline = [];
  let lastHp = 100, sawHurt = false;
  const t0 = Date.now();
  let lastTeleport = 0;
  while (Date.now() - t0 < 12000) {
    if (Date.now() - lastTeleport > 250) { await page.evaluate(() => window.__eclipseCmd("teleport", 1072, 320)); lastTeleport = Date.now(); }
    const s = await state(page);
    if (s.player.anim === "hurt") sawHurt = true;
    if (s.player.hp < lastHp) timeline.push({ t: Date.now() - t0, hp: s.player.hp, x: s.player.x });
    lastHp = s.player.hp;
    if (s.player.deaths >= 1) break;
    await sleep(30);
  }
  check("Vida: las espinas quitan vida y se ve la animación de daño", timeline.length > 0 && timeline[0].hp === 75 && sawHurt, timeline.map((e) => e.hp).join(" → "));
  const gaps = timeline.slice(1).map((e, i) => e.t - timeline[i].t);
  check("Vida: después de un golpe hay invulnerabilidad (golpes separados)", gaps.every((g) => g >= 700), `separación ms: ${gaps.join(", ")}`);

  const sDead = await state(page);
  check("Vida: con 0 de vida el Pollito muere", sDead.player.deaths === 1 && sDead.player.state === "dead", `state=${sDead.player.state} deaths=${sDead.player.deaths}`);
  await page.screenshot({ path: path.join(SHOTS, "vida-muerte.png") });
  await page.waitForFunction(() => JSON.parse(window.__eclipse).player.state !== "dead", null, { timeout: 5000 }).catch(() => {});
  await sleep(300);
  const sBack = await state(page);
  check("Vida: reaparece en el Santuario con la vida llena", Math.abs(sBack.player.x - 150) < 4 && sBack.player.hp === 100, `x=${sBack.player.x.toFixed(0)} hp=${sBack.player.hp}`);
  await page.screenshot({ path: path.join(SHOTS, "vida-santuario.png") });

  // Onda de la Democión Maldita, sin el jefe: saltándola no hace daño; quieto, sí.
  await sleep(1200);  // termina la invulnerabilidad de la reaparición
  await page.evaluate(() => window.__eclipseCmd("teleport", 400, 320));
  await sleep(300);
  await page.evaluate(() => window.__eclipseCmd("wave", 300, 328, 1));  // llega en ~0.5 s
  await sleep(150);
  await page.keyboard.down("Space"); await sleep(400); await page.keyboard.up("Space");
  await sleep(700);
  const hpJump = (await state(page)).player.hp;
  await page.evaluate(() => window.__eclipseCmd("wave", 300, 328, 1));
  await sleep(1000);
  const hpStand = (await state(page)).player.hp;
  check("Vida: la onda se puede saltar", hpJump === 100, `vida tras saltar=${hpJump}`);
  check("Vida: quedarse quieto ante la onda sí hace daño", hpStand < hpJump, `vida quieto=${hpStand}`);
  check("Vida: sin errores en consola", errors.length === 0, errors.slice(0, 3).join(" | "));
  await context.close();
}

// ---------- King Chiki, fase I ----------
async function waitFor(page, pred, ms) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) { const s = await state(page); if (pred(s)) return s; await sleep(40); }
  return state(page);
}
// Se pone detrás de King Chiki, mira hacia él y le pega una vez.
async function hitFromBehind(page) {
  const s = await state(page);
  await page.evaluate(([x]) => window.__eclipseCmd("teleport", x, 230), [s.boss.x - s.boss.facing * 30]);
  const toward = s.boss.facing > 0 ? "ArrowRight" : "ArrowLeft";  // detrás de él, mirando hacia él
  await page.keyboard.down(toward); await sleep(30); await page.keyboard.up(toward);
  await page.keyboard.press("j"); await sleep(120);
}
{
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const { page, errors } = await boot(context, "Jefe", "?pruebas&sala=jefe");
  await page.mouse.click(640, 360);
  const s0 = await state(page);
  check("Jefe: la arena carga con King Chiki esperando", s0.boss?.state === "waiting" && s0.sealed === false, `state=${s0.boss?.state}`);

  await page.keyboard.down("ArrowRight");
  const s1 = await waitFor(page, (s) => s.boss.state !== "waiting", 4000);
  await page.keyboard.up("ArrowRight");
  check("Jefe: al avanzar se sella la entrada y dice su frase", s1.sealed === true && s1.boss.speech.includes("DIAMANTE"), s1.boss.speech);

  // De frente, 4 golpes seguidos contra el escudo durante su pausa inicial.
  await page.evaluate(([x]) => window.__eclipseCmd("teleport", x, 230), [s1.boss.x - 40]);
  for (let i = 0; i < 4; i++) { await page.keyboard.press("j"); await sleep(240); }
  const s2 = await state(page);
  check("Jefe: de frente el escudo bloquea (no pierde vida)", s2.boss.hp === 260 && s2.boss.blocked >= 4, `hp=${s2.boss.hp} bloqueados=${s2.boss.blocked}`);
  check("Jefe: tras muchos golpes al escudo grita y contraataca", s2.boss.counters >= 1 && s2.boss.speech.includes("APRENDE"), s2.boss.speech);
  const s3 = await waitFor(page, (s) => s.player.hp < 100, 2500);
  check("Jefe: el golpe de escudo le hace daño al Pollito", s3.player.hp < 100, `vida del Pollito=${s3.player.hp}`);
  await page.screenshot({ path: path.join(SHOTS, "jefe-contraataque.png") });

  await sleep(1200);
  const before = (await state(page)).boss.hp;
  await hitFromBehind(page);
  const s4 = await state(page);
  check("Jefe: por detrás sí le hace daño", s4.boss.hp < before, `hp ${before} → ${s4.boss.hp}`);

  await page.evaluate(() => window.__eclipseCmd("teleport", 200, 230));
  await page.evaluate(() => window.__eclipseCmd("player_hp", 100));
  let sawMark = false, sawLine = false;
  const t0 = Date.now();
  while (Date.now() - t0 < 12000 && !(sawMark && sawLine)) {
    const s = await state(page);
    if (s.marks_warning > 0) sawMark = true;
    if (s.boss.speech.includes("POR AHÍ NO")) sawLine = true;
    if (sawMark) await page.screenshot({ path: path.join(SHOTS, "jefe-por-ahi-no.png") });
    await sleep(60);
  }
  check("Jefe: ¡POR AHÍ NO! marca la zona antes de explotar y grita su frase", sawMark && sawLine, `marca=${sawMark} frase=${sawLine}`);

  await page.evaluate(() => window.__eclipseCmd("player_hp", 100));
  await page.evaluate(() => window.__eclipseCmd("boss_hp", 5));
  await sleep(300);
  let s5 = await state(page);
  for (let i = 0; i < 4 && s5.boss.state !== "defeated"; i++) { await sleep(700); await hitFromBehind(page); s5 = await state(page); }
  await sleep(300);
  s5 = await state(page);
  check("Jefe: con 0 de vida queda derrotado y se abre la entrada", s5.boss.state === "defeated" && s5.sealed === false, `state=${s5.boss.state} sellado=${s5.sealed}`);
  await page.screenshot({ path: path.join(SHOTS, "jefe-derrotado.png") });
  check("Jefe: sin errores en consola", errors.length === 0, errors.slice(0, 3).join(" | "));
  await context.close();
}
{
  // Fase II: transición al 50 %, sin escudo, Democión Maldita, Raíces del Tilt y Furia del Chiquito.
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const { page, errors } = await boot(context, "Jefe fase II", "?pruebas&sala=jefe");
  await page.mouse.click(640, 360);
  await page.keyboard.down("ArrowRight");
  await waitFor(page, (s) => s.boss.state !== "waiting", 4000);
  await page.keyboard.up("ArrowRight");
  await page.evaluate(() => window.__eclipseCmd("boss_hp", 105));
  await sleep(1700);  // termina la pausa inicial
  await hitFromBehind(page);
  const s1 = await state(page);
  check("Fase II: al 50 % empieza la transición y grita", s1.boss.state === "transition" && s1.boss.speech.includes("OTRA VEZ"), `state=${s1.boss.state} hp=${s1.boss.hp}`);
  await page.screenshot({ path: path.join(SHOTS, "jefe-transicion.png") });
  const hpDuring = s1.boss.hp;
  await hitFromBehind(page);
  check("Fase II: durante la transición no recibe daño", (await state(page)).boss.hp === hpDuring);
  const s2 = await waitFor(page, (s) => s.boss.phase === 2, 4000);
  check("Fase II: termina la transición en la fase II", s2.boss.phase === 2, `fase=${s2.boss.phase}`);

  // Sin escudo: de frente también le hace daño.
  await sleep(200);
  const s3 = await state(page);
  await page.evaluate(([x]) => window.__eclipseCmd("teleport", x, 230), [s3.boss.x + s3.boss.facing * 40]);
  const toward = s3.boss.facing > 0 ? "ArrowLeft" : "ArrowRight";
  await page.keyboard.down(toward); await sleep(30); await page.keyboard.up(toward);
  await page.keyboard.press("j"); await sleep(150);
  const s4 = await state(page);
  check("Fase II: sin escudo, de frente también le hace daño", s4.boss.hp < s3.boss.hp, `hp ${s3.boss.hp} → ${s4.boss.hp}`);

  // Observa sus ataques (con la vida del Pollito siempre llena para que no se reinicie la pelea).
  let sawWave = false, sawRoots = false;
  const fury0 = s4.boss.fury;
  let furyDone = false;
  const t0 = Date.now();
  while (Date.now() - t0 < 25000 && !(sawWave && sawRoots && furyDone)) {
    await page.evaluate(() => window.__eclipseCmd("player_hp", 100));
    const s = await state(page);
    if (s.roots_warning > 0) { sawRoots = true; await page.screenshot({ path: path.join(SHOTS, "jefe-raices.png") }); }
    if (s.boss.fury > fury0) furyDone = true;
    if (s.waves.length > 0 && !sawWave) { sawWave = true; await page.screenshot({ path: path.join(SHOTS, "jefe-onda.png") }); }
    await sleep(50);
  }
  check("Fase II: Democión Maldita lanza ondas por el suelo", sawWave);
  check("Fase II: Raíces del Tilt avisan antes de salir", sawRoots);
  check("Fase II: Furia del Chiquito (combo de 3 golpes)", furyDone);

  await page.evaluate(() => window.__eclipseCmd("boss_hp", 5));
  let s5 = await state(page);
  for (let i = 0; i < 5 && s5.boss.state !== "defeated"; i++) { await sleep(600); await hitFromBehind(page); s5 = await state(page); }
  check("Fase II: con 0 de vida queda derrotado", s5.boss.state === "defeated", `state=${s5.boss.state}`);
  check("Fase II: sin errores en consola", errors.length === 0, errors.slice(0, 3).join(" | "));
  await context.close();
}
{
  // Si el Pollito cae durante la pelea, todo vuelve a empezar desde el Santuario.
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const { page, errors } = await boot(context, "Jefe (reinicio)", "?pruebas&sala=jefe");
  await page.mouse.click(640, 360);
  await page.keyboard.down("ArrowRight");
  const s1 = await waitFor(page, (s) => s.boss.state !== "waiting", 4000);
  await page.keyboard.up("ArrowRight");
  await page.evaluate(() => window.__eclipseCmd("boss_hp", 120));
  await page.evaluate(() => window.__eclipseCmd("player_hp", 1));
  await page.evaluate(([x]) => window.__eclipseCmd("teleport", x, 230), [s1.boss.x - 50]);
  const sDead = await waitFor(page, (s) => s.player.deaths >= 1, 12000);
  const sBack = await waitFor(page, (s) => s.player.state !== "dead", 4000);
  await sleep(300);
  const s2 = await state(page);
  check("Jefe (reinicio): al caer vuelve al Santuario y la pelea se reinicia",
    sDead.player.deaths === 1 && s2.player.hp === 100 && s2.boss.hp === 260 && s2.boss.state === "waiting" && s2.boss.phase === 1 && s2.sealed === false,
    `muertes=${sDead.player.deaths} vida=${s2.player.hp} jefe=${s2.boss.hp} ${s2.boss.state} sellado=${s2.sealed}`);
  check("Jefe (reinicio): sin errores en consola", errors.length === 0, errors.slice(0, 3).join(" | "));
  await context.close();
}

await browser.close();
server.close();
const failed = results.filter((r) => !r.ok).length;
console.log(`\n${results.length - failed}/${results.length} comprobaciones pasaron.`);
clearTimeout(WATCHDOG);
process.exit(failed ? 1 : 0);
