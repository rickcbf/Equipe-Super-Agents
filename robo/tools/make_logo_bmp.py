#!/usr/bin/env python3
"""
Gera os BMPs da marca d'agua do RickEA MA a partir de assets/logo-rickea.webp.

O MetaTrader 5 so aceita BMP em OBJ_BITMAP_LABEL. Este script gera duas
familias de arquivos:

  RickEA_Logo_<tam>.bmp        -> 32 bits com canal alfa (fundo transparente)
  RickEA_Logo_<tam>_dark.bmp   -> 24 bits, ja mesclado com o fundo do grafico
                                  (use quando o alfa nao renderizar no seu build)

Uso:
    python3 make_logo_bmp.py                       # gera os tamanhos padrao
    python3 make_logo_bmp.py --sizes 128 256 512 --opacity 12 --bg 0,0,0
"""
import argparse
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "logo-rickea.webp")
OUT = os.path.join(ROOT, "robo", "Images")


def build(size, opacity, bg):
    src = Image.open(SRC).convert("RGBA")
    img = src.resize((size, size), Image.LANCZOS)
    a = opacity / 100.0

    # 32 bits com alfa (canais ja pre-multiplicados: e o que o MT5 espera)
    rgba = img.copy()
    px = rgba.load()
    for y in range(size):
        for x in range(size):
            r, g, b, _ = px[x, y]
            px[x, y] = (int(r * a), int(g * a), int(b * a), int(255 * a))
    alpha_path = os.path.join(OUT, "RickEA_Logo_%d.bmp" % size)
    rgba.save(alpha_path, "BMP")

    # 24 bits ja mesclado com a cor de fundo do grafico
    flat = Image.new("RGB", (size, size), bg)
    flat = Image.blend(flat, img.convert("RGB"), a)
    flat_path = os.path.join(OUT, "RickEA_Logo_%d_dark.bmp" % size)
    flat.save(flat_path, "BMP")

    return alpha_path, flat_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sizes", nargs="+", type=int, default=[96, 128, 192, 256, 512])
    ap.add_argument("--opacity", type=int, default=14, help="opacidade em %% (1-100)")
    ap.add_argument("--bg", default="0,0,0", help="cor de fundo do grafico R,G,B")
    args = ap.parse_args()

    bg = tuple(int(v) for v in args.bg.split(","))
    os.makedirs(OUT, exist_ok=True)
    for size in args.sizes:
        for path in build(size, args.opacity, bg):
            print("%-44s %d bytes" % (os.path.relpath(path, ROOT), os.path.getsize(path)))


if __name__ == "__main__":
    main()
