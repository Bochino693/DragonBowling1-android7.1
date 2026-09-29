"""Gera as imagens da abertura Lazer & Sport (sprites/marca/).

  alvo_<P>.png   o alvo com o dardo (parte de cima do logo)
  placa_<P>.png  a placa "Lazer & Sport" (parte de baixo)
                 P = tamanho em % do logo original (25, 50, 100): as duas
                 peças na MESMA escala, para montar o logo certinho.
  splash_giro_1.png / splash_giro_m1.png / splash_giro_0.png
                 a imagem que o Android mostra ENQUANTO o jogo abre
                 (antes era uma tela preta), já girada como a tela do
                 jogo, igual ao primeiro quadro da abertura.

VERSÕES POR TAMANHO: cada peça sai em várias larguras, reduzidas com
filtro Lanczos. O jogo usa a menor versão que ainda é maior que o tamanho
na tela — reduzir 1280 px para 150 px na hora do desenho é o que deixava o
logo serrilhado ("pixelado").
Uso: python tools/gerar_marca.py
"""
import os
import numpy as np
from PIL import Image

RAIZ = os.path.join(os.path.dirname(__file__), "..")
LOGO = os.path.join(RAIZ, "sprites", "logoofi.png")
PASTA = os.path.join(RAIZ, "sprites", "marca")
PERCENTUAIS = [25, 50, 100]
# A abertura: placa com 820 px de largura na tela, alvo centrado em y=640.
ESCALA_FINAL = 820.0 / 1280.0
CENTRO_ALVO = (492, 640)   # o alvo fica um pouco à esquerda do centro da placa, como no logo
TELA = (1024, 1536)          # a tela do jogo, em pé
HDMI = (1920, 1080)          # a saída da TV Box, deitada

os.makedirs(PASTA, exist_ok=True)
logo = Image.open(LOGO).convert("RGBA")
a = np.asarray(logo)[..., 3]
ocupacao = (a > 20).sum(1)
corte = int(np.argmax(ocupacao > logo.width * 0.85))   # onde a placa começa


def recortar(im):
    # Só o que é visível de verdade: pixels quase transparentes nas bordas
    # do desenho inflavam a caixa e deixavam o alvo pequeno.
    alfa = im.getchannel("A").point(lambda v: 255 if v > 24 else 0)
    return im.crop(alfa.getbbox())


pecas = {
    "alvo": recortar(logo.crop((0, 0, logo.width, corte))),
    "placa": recortar(logo.crop((0, corte, logo.width, logo.height))),
}
for nome, im in pecas.items():
    for p in PERCENTUAIS:
        tam = (max(1, round(im.width * p / 100)), max(1, round(im.height * p / 100)))
        im.resize(tam, Image.LANCZOS).save(os.path.join(PASTA, f"{nome}_{p}.png"), optimize=True)
    print(nome, im.size)


def quadro_inicial():
    """O primeiro quadro da abertura: só o fundo escuro, na mesma cor que
    a abertura desenha. O emblema aparece depois, na montagem animada
    (nada de logo parado — e cortado — antes da hora)."""
    return Image.new("RGB", TELA, (6, 8, 22))


q = quadro_inicial()
# giro 1: o topo do jogo fica na ESQUERDA do HDMI (girar 90° anti-horário)
q.rotate(90, expand=True).resize(HDMI, Image.LANCZOS).save(os.path.join(PASTA, "splash_giro_1.png"), optimize=True)
q.rotate(-90, expand=True).resize(HDMI, Image.LANCZOS).save(os.path.join(PASTA, "splash_giro_m1.png"), optimize=True)
q.save(os.path.join(PASTA, "splash_giro_0.png"), optimize=True)
print("corte da placa em y =", corte)
