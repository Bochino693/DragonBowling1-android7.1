"""Conversor de GDScript do Godot 4 para o Godot 3.6 (a TV Box S905L).

    python tools/godot4_para_godot3.py ORIGEM.gd DESTINO.gd

Faz a parte MECÂNICA da conversão (nomes que mudaram, sintaxe, sinais,
await, geometria de Control, sobreposições de tema). O que não dá para
converter sem entender o código (funções anônimas, rotação de Control em
radianos...) sai marcado com `# TODO-G3:` para ser resolvido à mão; o
relatório no fim lista essas linhas.

Nascido na conversão do Dragon Bowling (Pro Ultra, Godot 4.6 -> S905L,
Godot 3.6). Serve para os próximos jogos: acrescente regras aqui em vez de
consertar o mesmo nome à mão em cada arquivo.

Complementa `scripts/compat_g3.gd` (Compat), que recebe as chamadas que não
têm equivalente de uma linha no Godot 3 (fonte + tamanho + contorno de
Label, carga em segundo plano, randi_range...).
"""
import re
import sys

# ------------------------------------------------------------------ tipos
CONTROLS = {
    "Control", "Label", "Panel", "ColorRect", "TextureRect", "Button",
    "NinePatchRect", "MarginContainer", "VBoxContainer", "HBoxContainer",
    "CenterContainer", "PanelContainer", "RichTextLabel", "ProgressBar",
    "TextureProgressBar", "TextureProgress", "LineEdit", "ReferenceRect",
    "GridContainer", "ScrollContainer", "TextureButton", "BaseButton",
    "Container",
}
# propriedade do Godot 4 em Control -> Godot 3
CONTROL_PROPS = {
    "position": "rect_position",
    "size": "rect_size",
    "scale": "rect_scale",
    "pivot_offset": "rect_pivot_offset",
    "custom_minimum_size": "rect_min_size",
    "global_position": "rect_global_position",
    "rotation_degrees": "rect_rotation",
    "clip_contents": "rect_clip_content",
}
CLASSES = {
    "Node3D": "Spatial", "Sprite2D": "Sprite", "AnimatedSprite2D": "AnimatedSprite",
    "Texture2D": "Texture", "CompressedTexture2D": "StreamTexture",
    "PackedByteArray": "PoolByteArray", "PackedInt32Array": "PoolIntArray",
    "PackedInt64Array": "PoolIntArray", "PackedFloat32Array": "PoolRealArray",
    "PackedFloat64Array": "PoolRealArray", "PackedStringArray": "PoolStringArray",
    "PackedVector2Array": "PoolVector2Array", "PackedVector3Array": "PoolVector3Array",
    "PackedColorArray": "PoolColorArray", "Vector2i": "Vector2", "Rect2i": "Rect2",
    "Vector3i": "Vector3", "RenderingServer": "VisualServer", "FontFile": "DynamicFont",
    "TextureProgressBar": "TextureProgress", "AudioStreamOggVorbis": "AudioStreamOGGVorbis",
    "GPUParticles2D": "Particles2D",
}
MATEMATICA = {
    "lerpf": "lerp", "clampf": "clamp", "clampi": "clamp", "absf": "abs", "absi": "abs",
    "signf": "sign", "signi": "sign", "maxf": "max", "maxi": "max", "minf": "min",
    "mini": "min", "snappedf": "stepify", "snapped": "stepify", "deg_to_rad": "deg2rad",
    "rad_to_deg": "rad2deg", "randf_range": "rand_range", "is_zero_approx": "is_zero_approx",
    "fmod": "fmod", "posmod": "posmod", "fposmod": "fposmod",
}
COR = {
    "BLACK": "black", "WHITE": "white", "TRANSPARENT": "transparent", "RED": "red",
    "GREEN": "green", "BLUE": "blue", "YELLOW": "yellow", "ORANGE": "orange",
    "GRAY": "gray", "CYAN": "cyan", "MAGENTA": "magenta", "GOLD": "gold",
    "DARK_GRAY": "darkgray", "LIGHT_GRAY": "lightgray", "PURPLE": "purple",
}
ALINHAMENTO_H = {"LEFT": "ALIGN_LEFT", "CENTER": "ALIGN_CENTER", "RIGHT": "ALIGN_RIGHT", "FILL": "ALIGN_FILL"}
ALINHAMENTO_V = {"TOP": "VALIGN_TOP", "CENTER": "VALIGN_CENTER", "BOTTOM": "VALIGN_BOTTOM", "FILL": "VALIGN_FILL"}

TODO = "  # TODO-G3: "
avisos = []

ID = r"[A-Za-z_][A-Za-z0-9_]*"


def tipo_declarado(linha):
    """(nome, tipo) de uma declaração de variável/parâmetro na linha."""
    achados = []
    for m in re.finditer(r"\bvar\s+(%s)\s*:\s*(%s)" % (ID, ID), linha):
        achados.append((m.group(1), m.group(2)))
    for m in re.finditer(r"\bvar\s+(%s)\s*:?=\s*(%s)\.new\(" % (ID, ID), linha):
        achados.append((m.group(1), m.group(2)))
    for m in re.finditer(r"\bvar\s+(%s)\s*:?=\s*.*\bas\s+(%s)\s*$" % (ID, ID), linha):
        achados.append((m.group(1), m.group(2)))
    if linha.lstrip().startswith(("func ", "static func ")):
        for m in re.finditer(r"[(,]\s*(%s)\s*:\s*(%s)" % (ID, ID), linha):
            achados.append((m.group(1), m.group(2)))
    for m in re.finditer(r"\bfor\s+(%s)\s*:\s*(%s)\s+in\b" % (ID, ID), linha):
        achados.append((m.group(1), m.group(2)))
    return achados


def mapa_de_tipos(linhas, base):
    """Tipos dos membros (arquivo todo) e dos locais (por função)."""
    membros = {"self": base}
    locais = [dict() for _ in linhas]
    atual = {}
    for i, l in enumerate(linhas):
        sem = l.split("#", 1)[0]
        if re.match(r"(static\s+)?func\s", sem):
            atual = {}
        topo = not sem.startswith(("\t", " "))
        for nome, tipo in tipo_declarado(sem):
            if topo and not sem.lstrip().startswith(("func", "static")):
                membros[nome] = tipo
            else:
                atual[nome] = tipo
        locais[i] = dict(atual)
    return membros, locais


def eh_control(nome, i, membros, locais):
    t = locais[i].get(nome) or membros.get(nome)
    return t in CONTROLS


# ------------------------------------------------------------ conversões
def geometria(l, i, membros, locais, base_control):
    """x.position -> x.rect_position quando x é um Control."""
    def troca(m):
        alvo, prop = m.group(1), m.group(2)
        if prop not in CONTROL_PROPS:
            return m.group(0)
        if alvo in ("self",) and base_control or eh_control(alvo, i, membros, locais):
            return "%s.%s" % (alvo, CONTROL_PROPS[prop])
        return m.group(0)
    l = re.sub(r"\b(%s)\.(%s)\b(?!\s*\()" % (ID, ID), troca, l)
    # rotação de Control: Godot 4 em radianos, Godot 3 em graus
    m = re.search(r"\b(%s)\.rotation\b" % ID, l)
    if m and (eh_control(m.group(1), i, membros, locais)):
        l = l.replace(m.group(0), m.group(1) + ".rect_rotation") + TODO + "rotation (rad) -> rect_rotation (graus)"
    # offset_* -> margin_*
    l = re.sub(r"\.offset_(left|right|top|bottom)\b", r".margin_\1", l)
    # dentro de um script que é Control, `position`/`size` soltos
    if base_control:
        l = re.sub(r"(?<![\.\w\"])(position|size|scale|pivot_offset|custom_minimum_size|global_position)\b(?!\s*[\(:])",
                   lambda m: CONTROL_PROPS[m.group(1)], l)
    # tween_property(x, "scale", ...) com x Control
    def tp(m):
        alvo, prop = m.group(1), m.group(2)
        base_prop = prop.split(":")[0]
        if base_prop in CONTROL_PROPS and eh_control(alvo, i, membros, locais):
            return 'tween_property(%s, "%s"' % (alvo, CONTROL_PROPS[base_prop] + prop[len(base_prop):])
        return m.group(0)
    l = re.sub(r'tween_property\((%s),\s*"([a-z_:]+)"' % ID, tp, l)
    # alvo de tipo desconhecido: decide na hora (Compat.prop)
    l = re.sub(r'tween_property\(([^,]+?),\s*"(scale|position|size|rotation_degrees|pivot_offset|global_position)((?::\w+)?)"',
               r'tween_property(\1, Compat.prop(\1, "\2\3")', l)
    return l


def tema(l):
    """Sobreposições de tema de Label/Control."""
    l = re.sub(r"(\S+?)\.add_theme_font_size_override\(\s*\"font_size\"\s*,\s*(.+)\)\s*$",
               r"Compat.tamanho(\1, \2)", l)
    l = re.sub(r"(\S+?)\.add_theme_font_override\(\s*\"font\"\s*,\s*(.+)\)\s*$",
               r"Compat.fonte(\1, \2)", l)
    l = re.sub(r"(\S+?)\.add_theme_constant_override\(\s*\"outline_size\"\s*,\s*(.+)\)\s*$",
               r"Compat.contorno(\1, \2)", l)
    l = l.replace('add_theme_color_override("font_outline_color"', 'add_color_override("font_outline_modulate"')
    for g4, g3 in (("font_shadow_color", "font_color_shadow"), ("font_hover_color", "font_color_hover"),
                   ("font_pressed_color", "font_color_pressed"), ("font_disabled_color", "font_color_disabled"),
                   ("font_focus_color", "font_color_focus"), ("font_hover_pressed_color", "font_color_hover_pressed")):
        l = l.replace('add_theme_color_override("%s"' % g4, 'add_color_override("%s"' % g3)
    l = l.replace("add_theme_color_override(", "add_color_override(")
    l = l.replace("add_theme_constant_override(", "add_constant_override(")
    l = l.replace("add_theme_stylebox_override(", "add_stylebox_override(")
    l = l.replace("add_theme_font_override(", "add_font_override(")
    l = l.replace("add_theme_icon_override(", "add_icon_override(")
    l = l.replace("remove_theme_color_override(", "add_color_override(")  # raro
    m = re.search(r"\.horizontal_alignment\s*=\s*HORIZONTAL_ALIGNMENT_(\w+)", l)
    if m:
        l = l.replace(m.group(0), ".align = Label.%s" % ALINHAMENTO_H[m.group(1)])
    m = re.search(r"\.vertical_alignment\s*=\s*VERTICAL_ALIGNMENT_(\w+)", l)
    if m:
        l = l.replace(m.group(0), ".valign = Label.%s" % ALINHAMENTO_V[m.group(1)])
    l = re.sub(r"\bHORIZONTAL_ALIGNMENT_(LEFT|CENTER|RIGHT|FILL)\b", r"Label.ALIGN_\1", l)
    l = re.sub(r"\bVERTICAL_ALIGNMENT_(TOP|CENTER|BOTTOM|FILL)\b", r"Label.VALIGN_\1", l)
    l = re.sub(r"\.horizontal_alignment\s*=", ".align =", l)
    l = re.sub(r"\.vertical_alignment\s*=", ".valign =", l)
    l = re.sub(r"\.autowrap_mode\s*=\s*TextServer\.AUTOWRAP_OFF", ".autowrap = false", l)
    l = re.sub(r"\.autowrap_mode\s*=\s*TextServer\.AUTOWRAP_\w+", ".autowrap = true", l)
    l = re.sub(r"\.expand_mode\s*=\s*TextureRect\.EXPAND_IGNORE_SIZE", ".expand = true", l)
    l = re.sub(r"\.expand_mode\s*=\s*TextureRect\.EXPAND_\w+", ".expand = false", l)
    l = re.sub(r"\bset_anchors_and_offsets_preset\(", "set_anchors_and_margins_preset(", l)
    if re.search(r"\.texture_filter\s*=", l) or re.search(r"^\s*\w+\.layout_mode\s*=", l):
        l = re.sub(r"^(\s*)", r"\1pass  # G3 (filtro na importação): ", l)
    return l


def sinais(l):
    # x.sig.connect(metodo[.bind(a, b)][, flags])
    def con(m):
        obj, sig, resto = m.group(1), m.group(2), m.group(3)
        obj = obj or "self"
        if resto.startswith("func"):
            return m.group(0)  # função anônima: à mão
        flags = ""
        m2 = re.match(r"(%s)\.bind\((.*)\)\s*(,\s*(.+))?$" % ID, resto)
        if m2:
            metodo, binds = m2.group(1), m2.group(2)
            flags = m2.group(4) or ""
            args = '%s.connect("%s", self, "%s", [%s]' % (obj, sig, metodo, binds)
        else:
            m3 = re.match(r"(%s)\s*(,\s*(.+))?$" % ID, resto)
            if not m3:
                return m.group(0)
            metodo, flags = m3.group(1), m3.group(3) or ""
            args = '%s.connect("%s", self, "%s"' % (obj, sig, metodo)
            if flags:
                args += ", []"
        if flags:
            args += ", " + flags.replace("CONNECT_ONE_SHOT", "CONNECT_ONESHOT")
        return args + ")"
    l = re.sub(r"(?:(\S+?)\.)?(%s)\.connect\((.+)\)" % ID, con, l)
    l = re.sub(r"(?:(\S+?)\.)?(%s)\.is_connected\((%s)\)" % (ID, ID),
               lambda m: '%s.is_connected("%s", self, "%s")' % (m.group(1) or "self", m.group(2), m.group(3)), l)
    l = re.sub(r"(?:(\S+?)\.)?(%s)\.disconnect\((%s)\)" % (ID, ID),
               lambda m: '%s.disconnect("%s", self, "%s")' % (m.group(1) or "self", m.group(2), m.group(3)), l)
    # sig.emit(args)
    l = re.sub(r"(?:(\S+?)\.)?(%s)\.emit\(\)" % ID,
               lambda m: '%semit_signal("%s")' % ((m.group(1) + ".") if m.group(1) else "", m.group(2)), l)
    l = re.sub(r"(?:(\S+?)\.)?(%s)\.emit\(" % ID,
               lambda m: '%semit_signal("%s", ' % ((m.group(1) + ".") if m.group(1) else "", m.group(2)), l)
    # metodo.call_deferred(args) / get_tree().change_scene_to_file.call_deferred(x)
    l = re.sub(r"get_tree\(\)\.change_scene_to_file\.call_deferred\(", 'get_tree().call_deferred("change_scene", ', l)
    l = re.sub(r"\b(%s)\.call_deferred\(\)" % ID, r'call_deferred("\1")', l)
    l = re.sub(r"\b(%s)\.call_deferred\(" % ID,
               lambda m: m.group(0) if m.group(1) in ("self",) else 'call_deferred("%s", ' % m.group(1), l)
    # tween_callback(metodo[.bind(...)])
    l = re.sub(r"tween_callback\((%s)\.bind\((.*?)\)\)" % ID, r'tween_callback(self, "\1", [\2])', l)
    l = re.sub(r"tween_callback\((%s)\)" % ID, r'tween_callback(self, "\1")', l)
    l = re.sub(r"tween_method\((%s)\s*," % ID, r'tween_method(self, "\1",', l)
    return l


AWAIT_SINAL = [
    (r"await\s+get_tree\(\)\.process_frame", 'yield(get_tree(), "idle_frame")'),
    (r"await\s+(\S+?)\.process_frame", r'yield(\1, "idle_frame")'),
    (r"await\s+get_tree\(\)\.physics_frame", 'yield(get_tree(), "physics_frame")'),
    (r"await\s+(?:RenderingServer|VisualServer)\.frame_post_draw", 'yield(VisualServer, "frame_post_draw")'),
    (r"await\s+(get_tree\(\)\.create_timer\(.*\))\.timeout", r'yield(\1, "timeout")'),
    (r"await\s+(\S+?)\.(finished|timeout|animation_finished|tree_exited|completed)\b(?!\()", r'yield(\1, "\2")'),
]


def _chamada_em(l, ini):
    """O texto de `f(...)` (parênteses balanceados) a partir de `ini`."""
    m = re.match(r"[\w\.]+\(", l[ini:])
    if not m:
        return None
    nivel, j = 0, ini
    while j < len(l):
        if l[j] == "(":
            nivel += 1
        elif l[j] == ")":
            nivel -= 1
            if nivel == 0:
                return l[ini:j + 1]
        j += 1
    return None


def aguardar(linhas):
    """await -> yield. Chamada de função vira o padrão que tolera função
    que às vezes NÃO espera nada (no Godot 3, yield numa função que
    retornou direto dá erro)."""
    saida = []
    for l in linhas:
        if "await " not in l or l.lstrip().startswith("#"):
            saida.append(l)
            continue
        feito = False
        for pad, rep in AWAIT_SINAL:
            novo = re.sub(pad, rep, l)
            if novo != l:
                saida.append(novo)
                feito = True
                break
        if feito:
            continue
        ind = re.match(r"\s*", l).group(0)
        m = re.match(r"(\s*)(?:(var\s+%s(?:\s*:\s*%s)?\s*:?=|%s\s*=)\s*)?await\s+(.+?)\s*(#.*)?$" % (ID, ID, ID), l)
        if m and m.group(3).endswith(")"):
            atrib = m.group(2)
            chamada = m.group(3)
            saida.append('%svar _g3_estado = %s' % (ind, chamada))
            saida.append('%sif _g3_estado is GDScriptFunctionState:' % ind)
            saida.append('%s\t_g3_estado = yield(_g3_estado, "completed")' % ind)
            if atrib:
                saida.append("%s%s _g3_estado" % (ind, atrib))
            continue
        m = re.search(r"\bawait\s+", l)
        chamada = _chamada_em(l, m.end()) if m else None
        cab = l.lstrip()
        if chamada and not cab.startswith(("elif", "while", "return")):
            saida.append('%svar _g3_estado = %s' % (ind, chamada))
            saida.append('%sif _g3_estado is GDScriptFunctionState:' % ind)
            saida.append('%s\t_g3_estado = yield(_g3_estado, "completed")' % ind)
            saida.append(l[:m.start()] + "_g3_estado" + l[m.end() + len(chamada):])
            continue
        if chamada and cab.startswith("return"):
            saida.append('%svar _g3_estado = %s' % (ind, chamada))
            saida.append('%sif _g3_estado is GDScriptFunctionState:' % ind)
            saida.append('%s\t_g3_estado = yield(_g3_estado, "completed")' % ind)
            saida.append(l[:m.start()] + "_g3_estado" + l[m.end() + len(chamada):])
            continue
        saida.append(l + TODO + "await não convertido")
    # `_g3_estado` é declarada UMA vez, logo no começo da função (no Godot 3
    # a variável criada dentro de um bloco não existe fora dele).
    saida = [l.replace("var _g3_estado = ", "_g3_estado = ") for l in saida]
    final, i = [], 0
    while i < len(saida):
        l = saida[i]
        m = re.match(r"(\s*)(static\s+)?func\s", l)
        if not m:
            final.append(l)
            i += 1
            continue
        # cabeçalho pode ocupar várias linhas: vai até a que termina em ':'
        j = i
        while j < len(saida) and not saida[j].split("#", 1)[0].rstrip().endswith(":"):
            j += 1
        final.extend(saida[i:j + 1])
        k = j + 1
        base = m.group(1)
        while k < len(saida):
            t = saida[k]
            if t.strip() == "" or t.lstrip().startswith("#"):
                k += 1
                continue
            ind = re.match(r"\s*", t).group(0)
            if len(ind) <= len(base):
                break
            k += 1
        corpo = saida[j + 1:k]
        if any("_g3_estado" in c for c in corpo):
            final.append(m.group(1) + "\tvar _g3_estado = null")
        final.extend(corpo)
        i = k
    return final


ACENTOS = str.maketrans("áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇñÑ",
                        "aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUCnN")


def partes_de_codigo(l):
    """Divide a linha em pedaços (texto, eh_codigo): strings e comentário
    não são código."""
    pedacos, atual, i, aspas = [], "", 0, None
    while i < len(l):
        c = l[i]
        if aspas:
            atual += c
            if c == "\\" and i + 1 < len(l):
                atual += l[i + 1]
                i += 2
                continue
            if c == aspas:
                pedacos.append((atual, False))
                atual, aspas = "", None
        elif c in "\"'":
            if atual:
                pedacos.append((atual, True))
            atual, aspas = c, c
        elif c == "#":
            if atual:
                pedacos.append((atual, True))
            pedacos.append((l[i:], False))
            return pedacos
        else:
            atual += c
        i += 1
    if atual:
        pedacos.append((atual, aspas is None))
    return pedacos


def so_no_codigo(l, funcao):
    return "".join(funcao(t) if cod else t for t, cod in partes_de_codigo(l))


TIPO_CONHECIDO = re.compile(r"^\s*(-?\d+(\.\d*)?|-?\.\d+|\"[^\"]*\"|true|false|[A-Za-z_][A-Za-z0-9_]*\.new\(\))\s*(#.*)?$")


def atribuicao_inferida(l):
    """`var x := expr` só fica tipado se o tipo de expr é óbvio; senão o
    Godot 3 não consegue inferir e recusa o script."""
    m = re.match(r"^(\s*var\s+%s)\s*:=\s*(.*)$" % ID, l)
    if m and not TIPO_CONHECIDO.match(m.group(2)):
        return "%s = %s" % (m.group(1), m.group(2))
    return l


def linha(l, i, membros, locais, base_control):
    if l.lstrip().startswith("#"):
        return l
    l = so_no_codigo(l, lambda t: t.translate(ACENTOS))
    l = atribuicao_inferida(l)
    # `a not in b` não existe no Godot 3
    l = re.sub(r"\b(if|elif|while)\s+(\S+)\s+not\s+in\s+(.+?):(\s*(#.*)?)$", r"\1 not (\2 in \3):\4", l)
    l = re.sub(r"\bStringName\(", "String(", l)
    l = re.sub(r"\bStringName\b", "String", l)
    # load("x.ttf") no Godot 3 é DynamicFontData, que não é Font
    l = re.sub(r"(\bvar\s+%s)\s*:\s*Font\s*=" % ID, r"\1 =", l)
    # anotações
    l = re.sub(r"^@tool\b", "tool", l)
    l = re.sub(r"^(\s*)@onready\s+var\b", r"\1onready var", l)
    l = re.sub(r"^(\s*)@export_file\((.*?)\)\s+var\b", r'\1export(String, FILE, \2) var', l)
    l = re.sub(r"^(\s*)@export_range\((.*?)\)\s+var\b", r"\1export(float, \2) var", l)
    l = re.sub(r"^(\s*)@export_multiline\s+var\b", r"\1export(String, MULTILINE) var", l)
    l = re.sub(r"^(\s*)@export\s+var\b", r"\1export var", l)
    l = re.sub(r"^\s*@warning_ignore\(.*\)\s*$", "", l)
    l = re.sub(r"@warning_ignore\([^)]*\)\s*", "", l)
    # tipos
    l = re.sub(r"\b(?:Array|Dictionary)\[[^\]]*\]", lambda m: m.group(0).split("[")[0], l)
    l = re.sub(r"\bfor\s+(%s)\s*:\s*%s\s+in\b" % (ID, ID), r"for \1 in", l)
    l = re.sub(r":\s*Variant\b(\s*=)?", lambda m: " =" if m.group(1) else "", l)
    l = re.sub(r"->\s*Variant\s*:", ":", l)
    l = re.sub(r"\bas\s+(Key|JoyButton|MouseButton)\b", "", l)
    # nomes de classe só no CÓDIGO: dentro de string e depois de `$` são
    # nomes de nó, que continuam os mesmos na cena
    for g4, g3 in CLASSES.items():
        l = so_no_codigo(l, lambda t, a=g4, b=g3: re.sub(r"(?<!\$)\b%s\b" % a, b, t))
    l = re.sub(r":\s*Tween\b", ": SceneTreeTween", l)
    l = re.sub(r"->\s*Tween\b", "-> SceneTreeTween", l)
    l = re.sub(r"\bas\s+Tween\b", "as SceneTreeTween", l)
    l = re.sub(r"(?<![\w\"])&\"", '"', l)
    if re.match(r"\s*signal\s", l):
        l = re.sub(r"(\w+)\s*:\s*\w+", r"\1", l)
    # nomes de função
    # maxi/mini/clampi/absi/signi devolvem int no Godot 4; no 3, max() é float
    for g4, g3 in (("maxi", "max"), ("mini", "min"), ("clampi", "clamp"), ("absi", "abs"), ("signi", "sign")):
        while True:
            m = re.search(r"(?<![\.\w])%s\(" % g4, l)
            if not m:
                break
            nivel, j = 0, m.end() - 1
            while j < len(l):
                nivel += {"(": 1, ")": -1}.get(l[j], 0)
                if nivel == 0:
                    break
                j += 1
            l = l[:m.start()] + "int(%s%s)" % (g3, l[m.end() - 1:j + 1]) + l[j + 1:]
    for g4, g3 in MATEMATICA.items():
        l = re.sub(r"(?<![\.\w])%s\(" % g4, g3 + "(", l)
    l = re.sub(r"(?<![\.\w])randi_range\(", "Compat.randi_range(", l)
    l = re.sub(r"(?<![\.\w])roundi\(", "Compat.roundi(", l)
    l = re.sub(r"(?<![\.\w])floori\(", "Compat.floori(", l)
    l = re.sub(r"(?<![\.\w])ceili\(", "Compat.ceili(", l)
    l = re.sub(r"Vector2\.from_angle\(", "Vector2.RIGHT.rotated(", l)
    l = re.sub(r"\bColor\.([A-Z_]+)\b", lambda m: "Color." + COR.get(m.group(1), m.group(1).lower()), l)
    l = l.replace(".is_empty()", ".empty()")
    l = l.replace(".remove_at(", ".remove(")
    l = l.replace(".instantiate(", ".instance(")
    l = l.replace(".find_child(", ".find_node(")
    l = l.replace("queue_redraw()", "update()")
    l = l.replace("set_shader_parameter(", "set_shader_param(")
    l = l.replace(".gdshader\"", ".shader\"")
    l = l.replace("get_shader_parameter(", "get_shader_param(")
    l = l.replace("change_scene_to_file(", "change_scene(")
    l = l.replace("change_scene_to_packed(", "change_scene_to(")
    l = l.replace(".is_valid_int()", ".is_valid_integer()")
    l = l.replace("OS.get_keycode_string(", "OS.get_scancode_string(")
    l = l.replace("InputMap.action_get_events(", "InputMap.get_action_list(")
    l = re.sub(r"\.physical_keycode\b", ".physical_scancode", l)
    l = re.sub(r"(?<!physical_)\bkeycode\b", "scancode", l)
    l = l.replace("KEY_NONE", "0")
    l = l.replace(".sprite_frames", ".frames")
    l = l.replace(".get_frame_texture(", ".get_frame(")
    if re.search(r"\bskew\b", l) and "#" not in l.split("skew")[0]:
        l += TODO + "Node2D.skew não existe no Godot 3"
    l = re.sub(r"\.lerp\(", ".linear_interpolate(", l)
    l = re.sub(r"\bprocess_mode\s*=\s*Node\.PROCESS_MODE_ALWAYS", "pause_mode = Node.PAUSE_MODE_PROCESS", l)
    l = re.sub(r"\bprocess_mode\s*=\s*Node\.PROCESS_MODE_PAUSABLE", "pause_mode = Node.PAUSE_MODE_STOP", l)
    l = re.sub(r"\bprocess_mode\s*=\s*Node\.PROCESS_MODE_INHERIT", "pause_mode = Node.PAUSE_MODE_INHERIT", l)
    l = re.sub(r"\.scene_file_path\b", ".filename", l)
    l = re.sub(r"\bget_tree\(\)\.root\b", "get_tree().root", l)
    l = re.sub(r"(\w+)\.contains\(", r"Compat.contem(\1, ", l)
    # carga em segundo plano (Compat faz uma por quadro, na linha do jogo)
    l = l.replace("ResourceLoader.load_threaded_request(", "Compat.pedir_carga(")
    l = l.replace("ResourceLoader.load_threaded_get_status(", "Compat.estado_carga(")
    l = l.replace("ResourceLoader.load_threaded_get(", "Compat.pegar_carga(")
    l = l.replace("ResourceLoader.THREAD_LOAD_IN_PROGRESS", "Compat.CARGA_EM_ANDAMENTO")
    l = l.replace("ResourceLoader.THREAD_LOAD_LOADED", "Compat.CARGA_PRONTA")
    l = l.replace("ResourceLoader.THREAD_LOAD_FAILED", "Compat.CARGA_FALHOU")
    l = l.replace("ResourceLoader.THREAD_LOAD_INVALID_RESOURCE", "Compat.CARGA_INVALIDA")
    l = re.sub(r"(\S+?)\.find_children\(\s*\"\*\"\s*,\s*(\"\w+\")[^)]*\)", r"Compat.filhos_do_tipo(\1, \2)", l)
    l = re.sub(r"\bsuper\(\)", ".%s()" % "_ready", l) if False else l
    # z_index: no Godot 3 Control não tem; Compat.z resolve os dois casos
    l = re.sub(r"^(\s*)((?!self\b)[A-Za-z_][\w\.]*)\.z_index\s*=\s*(.+?)\s*$", r"\1Compat.z(\2, \3)", l)
    l = re.sub(r"\bOS\.create_process\(([^,]+),\s*(.+?),\s*false\)", r"OS.execute(\1, \2, false)", l)
    l = re.sub(r"\.enabled\s*=\s*(true|false)\s*$", lambda m: m.group(0), l)
    l = tema(l)
    l = geometria(l, i, membros, locais, base_control)
    l = sinais(l)
    if re.search(r"\bfunc\s*\(", l) and not re.match(r"\s*(static\s+)?func\s+\w", l):
        l += TODO + "função anônima"
    for sinal in ("content_scale", "clip_children", "TextServer",
                  "get_theme_font", "get_theme_constant", "FontVariation", "SystemFont", "ThemeDB",
                  "allow_system_fallback", "fallbacks", ".fallback_font", "super", "Callable",
                  "scale_amount_min", "scale_amount_max", "initial_velocity_min", "initial_velocity_max",
                  "get_window", "DisplayServer", "Engine.max_fps", "pick_random", ".filter(", ".map("):
        if sinal in l and "TODO-G3" not in l:
            l += TODO + sinal
    return l


def converter(texto):
    linhas = texto.replace("\r\n", "\n").split("\n")
    m = re.search(r"^extends\s+(\w+)", texto, re.M)
    base = m.group(1) if m else "Reference"
    base_control = base in CONTROLS
    membros, locais = mapa_de_tipos(linhas, base)
    saida = [linha(l, i, membros, locais, base_control) for i, l in enumerate(linhas)]
    saida = aguardar(saida)
    texto = "\n".join(saida)
    texto = re.sub(r"^extends\s+Node2D", "extends Node2D", texto, flags=re.M)
    texto = re.sub(r"^extends\s+Sprite2D", "extends Sprite", texto, flags=re.M)
    texto = re.sub(r"^extends\s+AnimatedSprite2D", "extends AnimatedSprite", texto, flags=re.M)
    texto = re.sub(r"^extends\s+RefCounted", "extends Reference", texto, flags=re.M)
    texto = texto.replace("RefCounted", "Reference")
    return texto


def main():
    origem, destino = sys.argv[1], sys.argv[2]
    texto = open(origem, encoding="utf-8").read()
    novo = converter(texto)
    open(destino, "w", encoding="utf-8").write(novo)
    todos = [(n + 1, l.strip()) for n, l in enumerate(novo.split("\n")) if "TODO-G3" in l]
    print("%s: %d linhas, %d TODO-G3" % (destino, novo.count("\n") + 1, len(todos)))
    for n, l in todos:
        print("   %5d  %s" % (n, l[:150]))


if __name__ == "__main__":
    main()
