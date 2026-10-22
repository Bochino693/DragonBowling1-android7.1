"""Gera as fontes de reserva do jogo (fonts/emoji_do_jogo.ttf e
fonts/simbolos_do_jogo.ttf) só com os emojis e símbolos que os textos usam.

POR QUÊ: as fontes do jogo não têm 🎳 🏆 ★ ◆ ▼ etc. Sem reserva própria, o
Godot vai procurar nas fontes do SISTEMA na hora em que o texto aparece —
no Android isso é abrir e ler a fonte de emoji inteira (vários MB), e a
tela trava (era a demora do modal de jogadores e do placar). Com estas
fontinhas embutidas, nada é procurado no sistema.

EMOJI NÍTIDO EM QUALQUER TAMANHO. A fonte de emoji colorida (Noto Color
Emoji) traz cada emoji desenhado UMA vez, com 136 px. O Godot 3 desenha o
emoji de 22-46 px do jogo encolhendo esse desenho 3 a 6 vezes, sem
suavizar: na TV ele sai serrilhado e "chiando" quando o texto anima. Aqui a
fonte ganha o mesmo desenho já reduzido (com filtro bom) em vários tamanhos
(TAMANHOS); o Godot escolhe sozinho o mais próximo do tamanho do texto. O
emoji fica no mesmo tamanho e no mesmo lugar - só fica nítido.

Se um texto novo usar outro emoji/símbolo, acrescente-o aqui e rode:
    python tools/gerar_fontes_simbolos.py
"""
import copy
import io
import os
from fontTools import subset
from fontTools.ttLib import TTFont
from PIL import Image, ImageFilter

RAIZ = os.path.join(os.path.dirname(__file__), "..")
EMOJI = "🎳🏆🎮🤝👀✅✔"
SIMBOLOS = "◆▼★→▶•·×º—✔"
FONTES = [
    ("/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf", EMOJI, "emoji_do_jogo.ttf"),
    ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", SIMBOLOS, "simbolos_do_jogo.ttf"),
]
## Larguras (px) dos desenhos extras do emoji. O Godot 3 escolhe o desenho
## cuja largura é a mais próxima do tamanho do texto (e o desenha com a
## largura do tamanho do texto); os tamanhos de emoji do jogo hoje: 22, 30,
## 34, 40, 44 e 46.
TAMANHOS = [16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 40, 44, 46, 48, 52, 56, 64]


def reduzir_png(dados, largura, altura):
    """PNG RGBA reduzido com filtro Lanczos e alfa pré-multiplicado (sem
    borda escura em volta do emoji)."""
    img = Image.open(io.BytesIO(dados)).convert("RGBA")
    menor = img.convert("RGBa").resize((largura, altura), Image.LANCZOS)
    # um pouco de nitidez: na TV a tela do jogo é ampliada 1,25 vez na
    # altura e o emoji perderia o contorno firme
    menor = menor.filter(ImageFilter.UnsharpMask(radius=1.0, percent=70, threshold=0)).convert("RGBA")
    saida = io.BytesIO()
    menor.save(saida, "PNG", optimize=True)
    return saida.getvalue()


def emoji_em_varios_tamanhos(fonte):
    """Acrescenta à fonte de emoji (CBDT/CBLC com um desenho só) os mesmos
    desenhos reduzidos para cada altura de linha de TAMANHOS."""
    cblc = fonte["CBLC"]
    cbdt = fonte["CBDT"]
    base = cblc.strikes[0]
    dados_base = cbdt.strikeData[0]
    asc = base.bitmapSizeTable.hori.ascender
    desc = base.bitmapSizeTable.hori.descender
    altura_base = asc - desc
    largura_base = base.bitmapSizeTable.hori.widthMax
    ppem_base = base.bitmapSizeTable.ppemY
    novos, novos_dados = [], []
    for alvo in TAMANHOS:
        if alvo >= largura_base:
            continue
        f = alvo / float(largura_base)
        st = copy.deepcopy(base)
        bs = st.bitmapSizeTable
        bs.ppemX = bs.ppemY = max(1, round(ppem_base * f))
        a = round(asc * f)
        altura = round(altura_base * f)
        for lado in (bs.hori, bs.vert):
            lado.ascender = a
            lado.descender = -(altura - a)
            lado.widthMax = alvo
        dados = {}
        for nome, g in dados_base.items():
            ng = copy.deepcopy(g)
            m = ng.metrics
            largura = max(1, round(m.width * f))
            altura = max(1, round(m.height * f))
            ng.imageData = reduzir_png(g.imageData, largura, altura)
            m.width, m.height = largura, altura
            m.BearingX = round(m.BearingX * f)
            m.BearingY = round(m.BearingY * f)
            m.Advance = max(1, round(m.Advance * f))
            dados[nome] = ng
        novos.append(st)
        novos_dados.append(dados)
    # do menor para o maior, com o desenho original por último
    cblc.strikes = novos + [base]
    cbdt.strikeData = novos_dados + [dados_base]


def sem_caractere_de_nao_encontrado():
    """SEM LOSANGO PRETO ATRÁS DO EMOJI. Num texto com contorno, o Godot 3
    desenha primeiro o contorno de cada letra; a fonte de emoji só tem os
    desenhos coloridos (o FreeType não usa forma de letra em fonte de emoji
    desse tipo). Sem contorno para o emoji, o Godot desenhava o contorno do
    caractere de "não encontrado" (�) da fonte padrão (Open Sans): um
    losango preto atrás de cada emoji. A Open Sans perde só esse caractere
    no mapa (as outras fontes do jogo não o têm): sem ele, o contorno do
    emoji não desenha nada e o emoji colorido aparece limpo."""
    caminho = os.path.join(RAIZ, "fonts", "padrao_opensans.ttf")
    fonte = TTFont(caminho, recalcBBoxes=False, recalcTimestamp=False)
    mudou = False
    for t in fonte["cmap"].tables:
        if 0xFFFD in t.cmap:
            del t.cmap[0xFFFD]
            mudou = True
    if mudou:
        fonte.save(caminho)
        print("padrao_opensans.ttf: sem o caractere de não encontrado (U+FFFD)")


sem_caractere_de_nao_encontrado()

for origem, texto, nome in FONTES:
    opcoes = subset.Options()
    opcoes.layout_features = ["*"]
    opcoes.notdef_outline = True
    s = subset.Subsetter(opcoes)
    fonte = TTFont(origem)
    s.populate(text=texto)
    s.subset(fonte)
    if "CBDT" in fonte:
        emoji_em_varios_tamanhos(fonte)
    destino = os.path.join(RAIZ, "fonts", nome)
    fonte.save(destino)
    print(nome, os.path.getsize(destino), "bytes")
