"""Escreve os .import do Godot 3.6 de imagens e sons, do jeito da S905L.

    python tools/importacoes_godot3.py

POR QUÊ (Mali-450, 1 GB, OpenGL ES 2.0):
  • Imagem SEM transparência (fundos, pista, menu): comprimida na placa de
    vídeo (ETC1). 1024x1536 cai de 6 MB para 0,8 MB.
  • Imagem COM transparência: sem compressão. O ETC1 não tem alfa e o Godot
    3 rebaixaria para 16 tons por canal (faixas no degradê).
  • Sem mipmaps: no GLES2, imagem de tamanho qualquer com mipmaps é esticada
    para potência de 2 e dobra de memória. As imagens que aparecem muito
    reduzidas já foram reduzidas no arquivo (sprites/pino_em_pe.png) ou
    pelo `size_limit` abaixo.
  • Som SEM laço: no Godot 3 o OGG importa em laço por padrão, e o jogo
    espera o "acabou" de cada som para liberá-lo — em laço, nunca acabaria.
  • Efeitos em WAV (PCM 16 bits, sem compressão): tocar custa quase nada
    na CPU A53. MP3 é decodificado a cada vez que toca, e com vários sons
    juntos (pinos, bola, strike) a mistura de áudio atrasa e segura o jogo.
    Só as músicas longas ficam em OGG.

Rodar de novo depois de acrescentar imagem ou som.
"""
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parents[1]

## Imagens que aparecem bem menores que o arquivo (lado maior, em pixels).
LIMITE = {
    "sprites/logoofi.png": 400,
}

TEXTURA = """[remap]

importer="texture"
type="StreamTexture"

[deps]

source_file="res://{rel}"

[params]

compress/mode={modo}
compress/lossy_quality=0.7
compress/hdr_mode=0
compress/bptc_ldr=0
compress/normal_map=0
flags/repeat=0
flags/filter=true
flags/mipmaps=false
flags/anisotropic=false
flags/srgb=2
process/fix_alpha_border=true
process/premult_alpha=false
process/HDR_as_SRGB=false
process/invert_color=false
process/normal_map_invert_y=false
stream=false
size_limit={limite}
detect_3d=false
svg/scale=1.0
"""

WAV = """[remap]

importer="wav"
type="AudioStreamSample"

[deps]

source_file="res://{rel}"

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop=false
compress/mode=0
"""

SOM = """[remap]

importer="{importador}"
type="{tipo}"

[deps]

source_file="res://{rel}"

[params]

loop=false
loop_offset=0
"""


## Sempre sem compressão: a máscara do brilho da pista (os valores de R e G
## são medidas, não cor) e os ícones do Android.
SEM_COMPRESSAO = {"sprites/pista_mascara.png", "sprites/icone_boliche_exe.png",
                  "sprites/icone_dragon_bowling_exe.png"}


def tem_alfa(arq):
    with Image.open(arq) as im:
        if im.mode in ("RGBA", "LA"):
            return im.getextrema()[-1][0] < 255
        return im.mode == "PA" or "transparency" in im.info


def main():
    feitos = 0
    for arq in sorted(list(RAIZ.glob("sprites/**/*.png")) + list(RAIZ.glob("sprites/**/*.jpg"))
                      + [RAIZ / "icon.svg"]):
        rel = arq.relative_to(RAIZ).as_posix()
        if arq.suffix == ".svg" or rel in SEM_COMPRESSAO:
            modo = 0
        else:
            modo = 0 if tem_alfa(arq) else 2
        (arq.parent / (arq.name + ".import")).write_text(
            TEXTURA.format(rel=rel, modo=modo, limite=LIMITE.get(rel, 0)), encoding="utf-8")
        feitos += 1
    for arq in sorted(RAIZ.glob("songs/*.wav")):
        (arq.parent / (arq.name + ".import")).write_text(
            WAV.format(rel=arq.relative_to(RAIZ).as_posix()), encoding="utf-8")
        feitos += 1
    for arq in sorted(RAIZ.glob("songs/*.ogg")):
        (arq.parent / (arq.name + ".import")).write_text(SOM.format(
            rel=arq.relative_to(RAIZ).as_posix(), importador="ogg_vorbis",
            tipo="AudioStreamOGGVorbis"), encoding="utf-8")
        feitos += 1
    print("ok,", feitos, "arquivos .import")


if __name__ == "__main__":
    main()
