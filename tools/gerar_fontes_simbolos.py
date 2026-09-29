"""Gera as fontes de reserva do jogo (fonts/emoji_do_jogo.ttf e
fonts/simbolos_do_jogo.ttf) só com os emojis e símbolos que os textos usam.

POR QUÊ: as fontes do jogo não têm 🎳 🏆 ★ ◆ ▼ etc. Sem reserva própria, o
Godot vai procurar nas fontes do SISTEMA na hora em que o texto aparece —
no Android isso é abrir e ler a fonte de emoji inteira (vários MB), e a
tela trava (era a demora do modal de jogadores e do placar). Com estas
fontinhas embutidas, nada é procurado no sistema.

Se um texto novo usar outro emoji/símbolo, acrescente-o aqui e rode:
    python tools/gerar_fontes_simbolos.py
"""
import os
from fontTools import subset
from fontTools.ttLib import TTFont

RAIZ = os.path.join(os.path.dirname(__file__), "..")
EMOJI = "🎳🏆🎮🤝👀✅✔"
SIMBOLOS = "◆▼★→▶•·×º—✔"
FONTES = [
    ("/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf", EMOJI, "emoji_do_jogo.ttf"),
    ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", SIMBOLOS, "simbolos_do_jogo.ttf"),
]

for origem, texto, nome in FONTES:
    opcoes = subset.Options()
    opcoes.layout_features = ["*"]
    opcoes.notdef_outline = True
    s = subset.Subsetter(opcoes)
    fonte = TTFont(origem)
    s.populate(text=texto)
    s.subset(fonte)
    destino = os.path.join(RAIZ, "fonts", nome)
    fonte.save(destino)
    print(nome, os.path.getsize(destino), "bytes")
