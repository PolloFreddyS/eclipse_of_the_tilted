"""Convierte una hoja de sprites hecha con IA (fondo magenta) en una hoja limpia para el juego.

Pasos: separa cada cuadro, reduce la paleta, encuentra la cuadrícula de píxeles de cada
cuadro, toma el color mayoritario de cada bloque y alinea todos los cuadros sobre un
lienzo fijo (pies abajo).

Uso (Pollito: cuadros sueltos sobre magenta):
  python3 scripts/art/sheet_to_frames.py brand/pollito/hoja-detallada.webp \
      game/assets/pollito/pollito.png game/assets/pollito/pollito.json \
      --scale 3.5 --colors 24 --frame 64 --body-from-right 20 \
      --rows idle:4 run:6 jump:2 fall:2 attack:4 dodge:4 hurt:2
Uso (King Chiki: hoja en cuadrícula de 4x8, dibujo detallado):
  python3 scripts/art/sheet_to_frames.py <hoja.webp> <salida.png> <salida.json> \
      --grid 4x8 --scale 2.6 --colors 28 --frame 96 --anchor feet --flip 3:2 \
      --rows idle:4 walk:4 block:2 bash:4 slam:4 cast:3 hurt:2 defeated:2

Necesita numpy, pillow y scipy.
"""
import argparse
import json

import numpy as np
from PIL import Image
from scipy import ndimage



def is_background(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (r > 170) & (b > 170) & (g < 120)


def find_frames(a):
    fg = ndimage.binary_opening(~is_background(a), iterations=1)
    lab, _ = ndimage.label(ndimage.binary_dilation(fg, iterations=8))
    raw = []
    for s in ndimage.find_objects(lab):
        y0, y1, x0, x1 = s[0].start, s[0].stop, s[1].start, s[1].stop
        if (y1 - y0) * (x1 - x0) >= 3000:
            raw.append((y0, y1, x0, x1))
    # Cuadros pegados (por ejemplo, por un efecto de golpe que toca al vecino): si un bloque
    # mide lo que varios cuadros normales, se divide por las columnas con menos dibujo.
    typical = float(np.median([x1 - x0 for _, _, x0, x1 in raw]))
    boxes = []
    for y0, y1, x0, x1 in raw:
        pieces = max(1, int(round((x1 - x0) / typical)))
        if pieces == 1:
            boxes.append((y0, y1, x0, x1))
            continue
        cols = fg[y0:y1, x0:x1].sum(axis=0)
        cuts = [x0]
        for k in range(1, pieces):
            guess = int((x1 - x0) * k / pieces)
            lo, hi = max(guess - 40, 1), min(guess + 40, x1 - x0 - 1)
            cuts.append(x0 + lo + int(np.argmin(cols[lo:hi])))
        cuts.append(x1)
        boxes += [(y0, y1, cuts[i], cuts[i + 1]) for i in range(pieces)]
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


def grid_frames(a, cols, rows, counts, margin=4):
    """Cuadros de una hoja dividida en celdas iguales; se ignora el borde de cada celda."""
    fg = ~is_background(a)
    h, w = a.shape[0] / rows, a.shape[1] / cols
    border = np.zeros_like(fg)
    for r in range(rows + 1):
        border[max(int(r * h) - margin, 0):int(r * h) + margin, :] = True
    for c in range(cols + 1):
        border[:, max(int(c * w) - margin, 0):int(c * w) + margin] = True
    fg &= ~border
    fg = ndimage.binary_opening(fg, iterations=1)
    boxes = [[(int(r * h), int((r + 1) * h), int(c * w), int((c + 1) * w)) for c in range(n)] for r, n in enumerate(counts)]
    return boxes, fg


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
    ap.add_argument('--grid', help='COLSxROWS si la hoja viene en celdas iguales')
    ap.add_argument('--frame', type=int, default=48, help='tamaño del lienzo de cada cuadro')
    ap.add_argument('--anchor', choices=['beak', 'feet'], default='beak',
                    help='beak: alinea desde el borde derecho (Pollito); feet: centra los pies')
    ap.add_argument('--body-from-right', type=int, default=15)
    ap.add_argument('--flip', nargs='*', default=[], help='fila:columna (desde 0) de cuadros que miran al lado contrario')
    args = ap.parse_args()
    FRAME = args.frame
    flips = {tuple(int(v) for v in f.split(':')) for f in args.flip}

    a = np.asarray(Image.open(args.sheet).convert('RGB')).astype(int)
    spec = [(name, int(n)) for name, n in (r.split(':') for r in args.rows)]
    if args.grid:
        gc, gr = (int(v) for v in args.grid.lower().split('x'))
        rows, fg = grid_frames(a, gc, gr, [n for _, n in spec])
    else:
        rows, fg = find_frames(a)
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
            # En dibujos de bloques grandes se busca la cuadrícula; en dibujos finos no hace falta.
            oy, ox = best_grid(lab, m, args.scale) if args.scale >= 3 else (0, 0)
            small = downsample(lab, m, args.scale, oy, ox, bg)
            ys, xs = np.nonzero(small != bg)
            small = small[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            if (r, c) in flips:
                small = small[:, ::-1]
            h, w = small.shape
            top = FRAME - h - 1
            if args.anchor == 'feet':
                feet = np.nonzero((small[-max(h // 8, 2):] != bg).any(axis=0))[0]
                left = FRAME // 2 - int(round(feet.mean()))
            else:
                left = FRAME // 2 + args.body_from_right - w
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
