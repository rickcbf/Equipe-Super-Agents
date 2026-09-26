#!/usr/bin/env python3
"""Embute o logo RickEA (assets/logo-rickea.webp) como array de pixels ARGB
dentro do RickEA_SuperTrend_Bot.mq5, entre os marcadores LOGO DATA BEGIN/END.
Assim o robo desenha o logo sem precisar de nenhum arquivo em MQL5/Images.

Uso: python3 indicador/supertrend-bot/gerar_logo_mq5.py
"""
import os, re
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
LOGO = os.path.join(RAIZ, "assets", "logo-rickea.webp")
MQ5 = os.path.join(AQUI, "RickEA_SuperTrend_Bot.mq5")
TAM = 180      # resolucao embutida (px); o EA redimensiona em tempo real
FADE = 0.10    # borda suave (fracao do tamanho)

img = Image.open(LOGO).convert("RGB").resize((TAM, TAM), Image.LANCZOS)
px = img.load()

def suave(d):
    t = max(0.0, min(1.0, d / (FADE * TAM)))
    return t * t * (3 - 2 * t)

vals = []
for y in range(TAM):
    for x in range(TAM):
        r, g, b = px[x, y]
        d = min(x, y, TAM - 1 - x, TAM - 1 - y)
        a = int(round(255 * suave(d)))
        vals.append("0x%02X%02X%02X%02X" % (a, r, g, b))

linhas = []
for i in range(0, len(vals), 12):
    linhas.append("   " + ",".join(vals[i:i + 12]) + ("," if i + 12 < len(vals) else ""))

bloco = ("// === LOGO DATA BEGIN === (gerado por gerar_logo_mq5.py - nao editar a mao)\r\n"
         "#define LOGO_W %d\r\n#define LOGO_H %d\r\n"
         "uint LOGO_DATA[] =\r\n  {\r\n%s\r\n  };\r\n"
         "// === LOGO DATA END ===" % (TAM, TAM, "\r\n".join(linhas)))

src = open(MQ5, "rb").read().decode("ascii").replace("\r\n", "\n")
novo, n = re.subn(r"// === LOGO DATA BEGIN ===.*?// === LOGO DATA END ===",
                  lambda m: bloco, src, flags=re.S)
if n != 1:
    raise SystemExit("marcadores LOGO DATA nao encontrados no .mq5")
novo = novo.replace("\r\n", "\n").replace("\n", "\r\n")  # CRLF (MetaEditor)
open(MQ5, "wb").write(novo.encode("ascii"))
print("logo %dx%d embutido em %s" % (TAM, TAM, MQ5))
