"""Gera sprites/marca/halo_abertura.png: o halo roxo atrás do alvo na
abertura (scripts/abertura.gd), numa imagem só.

Eram quatro círculos quase transparentes (raios 900, 700, 520 e 380, cada um
com 0.07 x (1 - raio/1000) de opacidade) pintados um sobre o outro a cada
quadro - quase a tela inteira quatro vezes para a Mali-450. A imagem guarda
a mesma soma das quatro transparências (branco + transparência; a cor vem
do jogo) e é pintada uma vez.

    python3 tools/gerar_halo_abertura.py
"""
import os
from PIL import Image

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RAIOS = [900.0, 700.0, 520.0, 380.0]
LADO = 256

img = Image.new("LA", (LADO, LADO))
px = img.load()
centro = (LADO - 1) * 0.5
escala = RAIOS[0] / (LADO * 0.5)
for y in range(LADO):
    for x in range(LADO):
        d = ((x - centro) ** 2 + (y - centro) ** 2) ** 0.5 * escala
        falta = 1.0
        for r in RAIOS:
            if d <= r:
                falta *= 1.0 - 0.07 * (1.0 - r / 1000.0)
        px[x, y] = (255, int(round((1.0 - falta) * 255)))
destino = os.path.join(RAIZ, "sprites", "marca", "halo_abertura.png")
img.save(destino, optimize=True)
print(destino, os.path.getsize(destino), "bytes")
