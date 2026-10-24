"""Convierte una hoja de sprites hecha con IA (fondo magenta) en una hoja limpia para el juego.

Pasos: separa cada cuadro, reduce la paleta, encuentra la cuadrícula de píxeles de cada
cuadro, toma el color mayoritario de cada bloque y alinea todos los cuadros sobre un
lienzo fijo (pies abajo, cuerpo centrado).

Uso:
  python3 scripts/art/sheet_to_frames.py <hoja.webp> <salida.png> <salida.json> \
      --rows idle:4 run:6 jump:2 fall:2 attack:4 dodge:4 hurt:2
"""
import argparse
import json

import numpy as np
from PIL import Image
from scipy import ndimage

FRAME = 48          # tamaño del lienzo de cada cuadro, en píxeles del juego
BODY_FROM_RIGHT = 15  # el cuerpo se alinea desde el pico (borde derecho), no desde la capa


def is_background(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (r > 170) & (b > 170) & (g < 120)


def find_frames(a):
    fg = ndimage.binary_opening(~is_background(a), iterations=1)
    lab, _ = ndimage.label(ndimage.binary_dilation(fg, iterations=8))
    boxes = []
    for s in ndimage.find_objects(lab):
        y0, y1, x0, x1 = s[0].start, s[0].stop, s[1].start, s[1].stop
        if (y1 - y0) * (x1 - x0) < 3000:
            continue
        # Dos cuadros pegados: se separan por la columna con menos contenido cerca del centro.
        if (x1 - x0) > 1.6 * (y1 - y0):
            cols = fg[y0:y1, x0:x1].sum(axis=0)
            mid = (x1 - x0) // 2
            cut = x0 + mid - 40 + int(np.argmin(cols[mid - 40: mid + 40]))
            boxes += [(y0, y1, x0, cut), (y0, y1, cut, x1)]
        else:
            boxes.append((y0, y1, x0, x1))
    # Filas por posición vertical, y de izquierda a derecha dentro de cada fila.
    boxes.sort(key=lambda b: b[0])
    rows, current = [], [boxes[0]]
    for b in boxes[1:]:
        if b[0] - current[-1][0] > 60:
            rows.append(sorted(current, key=lambda b: b[2]))
            current = [b]
        else:
            current.append(b)
    rows.append(sorted(current, key=lambda b: b[2]))
    return rows, fg


def kmeans(pixels, k, iters=25, seed=0):
    rng = np.random.default_rng(seed)
    centers = pixels[rng.choice(len(pixels), k, replace=False)].astype(float)
    for _ in range(iters):
        d = ((pixels[:, None, :] - centers[None]) ** 2).sum(-1)
        idx = d.argmin(1)
        for c in range(k):
            if (idx == c).any():
                centers[c] = pixels[idx == c].mean(0)
    return centers.round().astype(int)


def best_grid(labels, mask, scale):
    """Busca el desfase de cuadrícula con bloques más 'puros' (un solo color)."""
    best = None
    steps = np.arange(0, scale, 0.5)
    for oy in steps:
        for ox in steps:
            ys = np.arange(oy, labels.shape[0], scale)
            xs = np.arange(ox, labels.shape[1], scale)
            impurity = 0
            for y in ys[:-1]:
                for x in xs[:-1]:
                    blk = labels[int(y):int(y + scale), int(x):int(x + scale)][mask[int(y):int(y + scale), int(x):int(x + scale)]]
                    if blk.size:
                        impurity += blk.size - np.bincount(blk).max()
            if best is None or impurity < best[0]:
                best = (impurity, oy, ox)
    return best[1], best[2]


def downsample(labels, mask, scale, oy, ox, background):
    ys = np.arange(oy, labels.shape[0] - scale / 2, scale)
    xs = np.arange(ox, labels.shape[1] - scale / 2, scale)
    out = np.full((len(ys), len(xs)), background)
    for j, y in enumerate(ys):
        for i, x in enumerate(xs):
            sl = (slice(int(y), int(y + scale)), slice(int(x), int(x + scale)))
            m = mask[sl]
            if m.mean() >= 0.5:  # más de la mitad del bloque es personaje
                out[j, i] = np.bincount(labels[sl][m]).argmax()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sheet')
    ap.add_argument('out_png')
    ap.add_argument('out_json')
    ap.add_argument('--rows', nargs='+', required=True, help='nombre:cuadros por fila, en orden')
    ap.add_argument('--scale', type=float, default=4.5, help='tamaño aproximado de un píxel del dibujo')
    ap.add_argument('--colors', type=int, default=12)
    args = ap.parse_args()

    a = np.asarray(Image.open(args.sheet).convert('RGB')).astype(int)
    rows, fg = find_frames(a)
    spec = [(name, int(n)) for name, n in (r.split(':') for r in args.rows)]
    counts = [len(r) for r in rows]
    if counts != [n for _, n in spec]:
        raise SystemExit(f'Se esperaban {[n for _, n in spec]} cuadros por fila y se encontraron {counts}')

    palette = kmeans(a[fg][::7], args.colors)
    flat = a.reshape(-1, 3)
    labels = np.empty(len(flat), dtype=int)
    for i in range(0, len(flat), 200000):  # por partes para no gastar memoria
        chunk = flat[i:i + 200000]
        labels[i:i + 200000] = ((chunk[:, None, :] - palette[None]) ** 2).sum(-1).argmin(1)
    labels = labels.reshape(a.shape[:2])
    bg = len(palette)
    # Colores de borde mezclados con el magenta del fondo cuentan como fondo.
    fringe = [i for i, (r, g, b) in enumerate(palette) if r > 140 and b > 110 and g < 130 and abs(r - b) < 110]
    if fringe:
        fg &= ~np.isin(labels, fringe)
        print('colores de borde descartados:', [tuple(palette[i]) for i in fringe])

    cols = max(n for _, n in spec)
    sheet = np.zeros((len(spec) * FRAME, cols * FRAME, 4), dtype=np.uint8)
    for r, ((name, n), boxes) in enumerate(zip(spec, rows)):
        for c, (y0, y1, x0, x1) in enumerate(boxes):
            lab, m = labels[y0:y1, x0:x1], fg[y0:y1, x0:x1]
            oy, ox = best_grid(lab, m, args.scale)
            small = downsample(lab, m, args.scale, oy, ox, bg)
            ys, xs = np.nonzero(small != bg)
            small = small[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            h, w = small.shape
            top = FRAME - h - 1
            left = FRAME // 2 + BODY_FROM_RIGHT - w
            left = min(max(left, 0), FRAME - w)
            top = max(top, 0)
            for j in range(min(h, FRAME)):
                for i in range(min(w, FRAME - left)):
                    k = small[j, i]
                    if k != bg:
                        sheet[r * FRAME + top + j, c * FRAME + left + i] = (*palette[k], 255)

    Image.fromarray(sheet, 'RGBA').save(args.out_png)
    meta = {'frame': FRAME, 'animations': {name: {'row': r, 'frames': n} for r, (name, n) in enumerate(spec)}}
    with open(args.out_json, 'w') as f:
        json.dump(meta, f, indent=2)
    print(f'{sum(counts)} cuadros -> {args.out_png} ({len(palette)} colores)')


if __name__ == '__main__':
    main()
