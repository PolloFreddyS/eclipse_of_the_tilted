# El Corral: Eclipse of the Tilted

Un juego de **Corral Studios**. Metroidvania de fantasía oscura del universo de Los Gallos Sin Planes, hecho con Godot 4.

Obra de fans sin fines de lucro. Sin relación con Riot Games ni Konami.

## Estructura

| Carpeta | Qué hay |
|---|---|
| `game/` | El juego (proyecto de Godot 4.7). |
| `site/`, `content/`, `scripts/build.mjs` | La página del juego (GitHub Pages). |
| `tests/` | Pruebas automáticas del juego web y del sitio. |
| `brand/` | Logos y arte de Corral Studios. |

## Publicar una versión

1. Crea un release en GitHub con una etiqueta como `v0.1.0-beta`. Marca **pre-release** si es beta.
2. Adjunta el APK (`.apk`) si hay versión de Android.
3. Escribe las notas en español; si quieres, agrega el inglés:

```markdown
<!-- title-en: First beta -->
- Primera beta pública.
- Ajustes de balance.
<!-- en -->
- First public beta.
- Balance adjustments.
```

- `<!-- title-en: ... -->` es el título en inglés. Sin él, se usa el título en español.
- Todo lo que va después de `<!-- en -->` son las notas en inglés.
- `<!-- fecha: 2026-12-01 -->` (opcional) fija la fecha que se muestra.
- Las notas son públicas: sin spoilers ni detalles de cambios secretos; "ajustes de balance" es suficiente.

Al publicar el release, el workflow **Publicar sitio** actualiza la página sola: el botón **Jugar** usa la versión web de ese release y el APK queda para descargar. Los borradores nunca aparecen. Si la página no se actualiza, se puede relanzar el workflow a mano (`gh workflow run pages.yml`).

## Probar en local

```bash
npm ci && node scripts/build.mjs          # arma el sitio en dist/
cd tests && npm ci && node site-test.mjs  # prueba el sitio con releases de ejemplo
node web-smoke.mjs                        # prueba el juego web (necesita build/web)
```

## Créditos

Corral Studios · Los Gallos Sin Planes (Cake & Others) · divilight (ciberseguridad y diseño) · Godot Engine
