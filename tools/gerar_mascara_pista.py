"""Gera sprites/pista_mascara.png: as máscaras do brilho da pista.

O shader do fundo calculava, em CADA pixel e em CADA quadro, onde ficam
as canaletas (azul) e os detalhes dourados da imagem da pista. Isso não
muda nunca: aqui vira uma textura pequena, e o shader só lê o valor.
  R = canaleta (azul, só nas laterais)
  G = dourado
Uso: python tools/gerar_mascara_pista.py   (rode de novo se trocar a pista)
"""
import os
import numpy as np
from PIL import Image

RAIZ = os.path.join(os.path.dirname(__file__), "..")
PISTA = os.path.join(RAIZ, "sprites", "ball-new.png")
SAIDA = os.path.join(RAIZ, "sprites", "pista_mascara.png")
LIMITE_BRILHO = 0.55


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


im = Image.open(PISTA).convert("RGB")
w, h = im.size
im = im.resize((w // 2, h // 2), Image.LANCZOS)
t = np.asarray(im, dtype=np.float32) / 255.0
r, g, b = t[..., 0], t[..., 1], t[..., 2]
H, W = r.shape
ux = (np.arange(W, dtype=np.float32) + 0.5)[None, :] / W
uy = (np.arange(H, dtype=np.float32) + 0.5)[:, None] / H

azul = smoothstep(LIMITE_BRILHO, 1.0, (b * 1.2 + g * 0.8) - r * 1.4)
esq = smoothstep(0.0, 0.22, ux) * (1.0 - smoothstep(0.22, 0.38, ux))
dir_ = smoothstep(0.62, 0.78, ux) * (1.0 - smoothstep(0.78, 1.0, ux))
lados = np.clip(esq + dir_, 0.0, 1.0)
faixa_y = smoothstep(0.08, 0.25, uy) * (1.0 - smoothstep(0.90, 1.0, uy))
canaleta = azul * lados * faixa_y
dourado = smoothstep(0.75, 1.0, (r * 1.1 + g * 1.0) * 0.5 - b * 0.3)

saida = np.dstack([canaleta, dourado, np.zeros_like(r)])
Image.fromarray((np.clip(saida, 0, 1) * 255 + 0.5).astype(np.uint8)).save(SAIDA, optimize=True)
print("gerado", SAIDA, saida.shape)
