"""Prepara las piezas de un personaje animado por piezas (King Chiki) para Godot.

Lee la hoja de piezas y la pose de reposo (rig-layout.json), reduce cada pieza a la escala
del juego conservando el pixel art, y escribe:
  - una imagen por pieza en <carpeta>/<nombre>.png
  - <carpeta>/rig_data.gd con la posición, el punto de giro y la pieza padre de cada una

Uso:
  python3 scripts/art/rig_parts.py brand/king-chiki/piezas-original.webp \\
      brand/king-chiki/rig-layout.json game/assets/king_chiki_rig
Necesita numpy, pillow y scipy.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage


def is_background(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (r > 150) & (b > 110) & (g < 130) & (np.abs(r - b) < 110)


def shrink(rgba, factor):
    """Reduce con el color mayoritario de cada bloque (no mezcla colores ni deja bordes borrosos)."""
    a = np.asarray(rgba)
    h, w = a.shape[:2]
    nh, nw = max(1, round(h * factor)), max(1, round(w * factor))
    out = np.zeros((nh, nw, 4), dtype=np.uint8)
    ys = np.linspace(0, h, nh + 1).astype(int)
    xs = np.linspace(0, w, nw + 1).astype(int)
    for j in range(nh):
        for i in range(nw):
            blk = a[ys[j]:ys[j + 1], xs[i]:xs[i + 1]].reshape(-1, 4)
            solid = blk[blk[:, 3] > 0]
            # Bordes mezclados con el magenta del fondo: no cuentan como dibujo.
            r, g, bl = solid[:, 0].astype(int), solid[:, 1].astype(int), solid[:, 2].astype(int)
            solid = solid[~((r - g > 50) & (bl - g > 40) & (bl > 90))]
            if len(solid) < 0.35 * len(blk) or len(solid) == 0:
                continue
            # color más frecuente, agrupando tonos casi iguales
            q = (solid[:, :3] // 24).astype(int)
            keys = q[:, 0] * 10000 + q[:, 1] * 100 + q[:, 2]
            vals, counts = np.unique(keys, return_counts=True)
            pick = solid[keys == vals[counts.argmax()]][:, :3].mean(0)
            out[j, i] = (*pick.round().astype(int), 255)
    return Image.fromarray(out, 'RGBA')


def main():
    sheet_path, layout_path, out_dir = sys.argv[1:4]
    layout = json.load(open(layout_path))
    sheet = np.asarray(Image.open(sheet_path).convert('RGB')).astype(int)
    fg = ndimage.binary_opening(~is_background(sheet), iterations=1)
    gs = layout['game_scale']
    ox, oy = layout['origin']
    os.makedirs(out_dir, exist_ok=True)

    def to_game(p):
        return [round((p[0] - ox) * gs, 2), round((p[1] - oy) * gs, 2)]

    lines = ['class_name KingChikiRigData', '## Generado por scripts/art/rig_parts.py: no editar a mano.', '',
             '## Punto de la cadera (de donde cuelgan torso, piernas y cola), con los pies en (0, 0).',
             f'const HIPS := Vector2({to_game(layout["hips"])[0]}, {to_game(layout["hips"])[1]})', '',
             '## Piezas en orden de dibujo: imagen, pieza padre, punto de giro y centro en reposo (pies en 0, 0).',
             'const PARTS := [']
    for part in layout['parts']:
        x0, y0, x1, y1 = part['box']
        rgb = sheet[y0:y1, x0:x1]
        alpha = fg[y0:y1, x0:x1] * 255
        img = Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), 'RGBA')
        if part.get('flip'):
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        sc = part.get('scale', 1.0)
        if part.get('rot'):
            img = img.resize((round(img.width * sc), round(img.height * sc)), Image.NEAREST)
            img = img.rotate(part['rot'], resample=Image.NEAREST, expand=True)
            sc = 1.0
        small = shrink(img, sc * gs)
        small.save(os.path.join(out_dir, part['name'] + '.png'))
        c, p = to_game(part['center']), to_game(part['pivot'])
        lines.append(f'\t{{"name": "{part["name"]}", "parent": "{part["parent"]}", '
                     f'"pivot": Vector2({p[0]}, {p[1]}), "center": Vector2({c[0]}, {c[1]})}},')
    lines += [']', '']
    with open(os.path.join(out_dir, 'rig_data.gd'), 'w') as f:
        f.write('\n'.join(lines))
    print(f'{len(layout["parts"])} piezas -> {out_dir}')


if __name__ == '__main__':
    main()
