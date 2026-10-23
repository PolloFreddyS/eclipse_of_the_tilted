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
const state = (page) => page.evaluate(() => (window.__eclipse ? JSON.parse(window.__eclipse) : null));

async function boot(context, label) {
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e)));
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  const t0 = Date.now();
  await page.goto(URL_);
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

  await page.keyboard.down("ArrowRight"); await sleep(1000); await page.keyboard.up("ArrowRight");
  const s1 = await state(page);
  check("Teclado: flecha derecha mueve al pollito", s1.player.x > s0.player.x + 80, `x ${s0.player.x.toFixed(0)} → ${s1.player.x.toFixed(0)}`);

  await page.keyboard.down("Space"); await sleep(250);
  const sAir = await state(page);
  await page.keyboard.up("Space"); await sleep(1200);
  const s2 = await state(page);
  check("Teclado: espacio salta y vuelve al suelo", sAir.player.y < s1.player.y - 20 && s2.player.on_floor && s2.player.jumps === 1, `y ${s1.player.y.toFixed(0)} → ${sAir.player.y.toFixed(0)} → ${s2.player.y.toFixed(0)}`);

  // Caminar hasta el muñeco (x = 760) y golpearlo.
  await page.keyboard.down("ArrowRight");
  await page.waitForFunction(() => JSON.parse(window.__eclipse).player.x > 715, null, { timeout: 10000 }).catch(() => {});
  await page.keyboard.up("ArrowRight"); await sleep(400);
  for (let i = 0; i < 3; i++) { await page.keyboard.press("j"); await sleep(350); }
  const s3 = await state(page);
  check("Teclado: J golpea al muñeco", s3.dummy_hits >= 3, `golpes ${s3.dummy_hits}, ataques ${s3.player.attacks}`);

  await page.keyboard.press("Shift"); await sleep(400);
  const s4 = await state(page);
  check("Teclado: Shift esquiva", s4.player.dodges === 1);
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

await browser.close();
server.close();
const failed = results.filter((r) => !r.ok).length;
console.log(`\n${results.length - failed}/${results.length} comprobaciones pasaron.`);
clearTimeout(WATCHDOG);
process.exit(failed ? 1 : 0);
