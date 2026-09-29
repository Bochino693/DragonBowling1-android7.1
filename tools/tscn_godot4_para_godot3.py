"""Converte cena .tscn do Godot 4 (format=3) para o Godot 3 (format=2).

    python tools/tscn_godot4_para_godot3.py ORIGEM.tscn DESTINO.tscn

Cobre o que as cenas 2D destes jogos usam: recursos externos e internos,
SpriteFrames (animações com AtlasTexture), Sprite/AnimatedSprite, Control
(offset -> margin), instâncias de cena. `uid` e `unique_id` somem (o Godot
3 não tem). O que não conhece fica como está e é avisado.
"""
import re
import sys

TIPOS = {
    "Sprite2D": "Sprite", "AnimatedSprite2D": "AnimatedSprite", "Texture2D": "Texture",
    "Node3D": "Spatial", "CompressedTexture2D": "StreamTexture",
}
PROPS = {
    "offset_left": "margin_left", "offset_right": "margin_right",
    "offset_top": "margin_top", "offset_bottom": "margin_bottom",
    "sprite_frames": "frames",
}
FORA = {"layout_mode", "anchors_preset", "frame_progress", "unique_id", "texture_filter"}


def blocos(texto):
    atual = None
    for linha in texto.replace("\r\n", "\n").split("\n"):
        if linha.startswith("["):
            if atual:
                yield atual
            atual = [linha]
        elif atual is not None:
            atual.append(linha)
    if atual:
        yield atual


def cabecalho(linha):
    m = re.match(r"\[(\w+)\s*(.*)\]$", linha.strip())
    tipo, resto = m.group(1), m.group(2)
    attrs = dict(re.findall(r'(\w+)=("(?:[^"\\]|\\.)*"|\S+)', resto))
    return tipo, attrs


def converter(texto):
    ext, sub = {}, {}
    saida, avisos = [], []
    corpo = list(blocos(texto))
    n_ext = n_sub = 0
    for b in corpo:
        tipo, a = cabecalho(b[0])
        if tipo == "ext_resource":
            n_ext += 1
            ext[a["id"].strip('"')] = n_ext
        elif tipo == "sub_resource":
            n_sub += 1
            sub[a["id"].strip('"')] = n_sub

    def valor(v):
        v = re.sub(r'ExtResource\("([^"]+)"\)', lambda m: "ExtResource( %d )" % ext[m.group(1)], v)
        v = re.sub(r'SubResource\("([^"]+)"\)', lambda m: "SubResource( %d )" % sub[m.group(1)], v)
        v = re.sub(r'&"', '"', v)
        v = re.sub(r"PackedStringArray\(", "PoolStringArray( ", v)
        v = re.sub(r"PackedVector2Array\(", "PoolVector2Array( ", v)
        for g4, g3 in TIPOS.items():
            v = v.replace('"%s"' % g4, '"%s"' % g3)
        return v

    carga = sum(1 for b in corpo if cabecalho(b[0])[0] in ("ext_resource", "sub_resource")) + 1
    for b in corpo:
        tipo, a = cabecalho(b[0])
        if tipo == "gd_scene":
            saida.append("[gd_scene load_steps=%d format=2]" % carga)
            saida.append("")
            continue
        if tipo == "ext_resource":
            t = TIPOS.get(a["type"].strip('"'), a["type"].strip('"'))
            saida.append('[ext_resource path=%s type="%s" id=%d]' % (a["path"], t, ext[a["id"].strip('"')]))
            continue
        if tipo == "sub_resource":
            t = TIPOS.get(a["type"].strip('"'), a["type"].strip('"'))
            saida.append("")
            saida.append('[sub_resource type="%s" id=%d]' % (t, sub[a["id"].strip('"')]))
            props = "\n".join(b[1:]).strip()
            if t == "SpriteFrames" and props:
                props = frames_g3(props)
            if props:
                saida.append(valor(props))
            continue
        if tipo == "node":
            partes = []
            for chave in ("name", "type", "parent", "instance"):
                if chave in a:
                    v = a[chave]
                    if chave == "type":
                        v = '"%s"' % TIPOS.get(v.strip('"'), v.strip('"'))
                    if chave == "instance":
                        v = valor(v)
                    partes.append("%s=%s" % (chave, v))
            saida.append("")
            saida.append("[node %s]" % " ".join(partes))
            for l in b[1:]:
                if not l.strip():
                    continue
                m = re.match(r"(\w+)\s*=\s*(.*)$", l)
                if not m:
                    saida.append(valor(l))
                    continue
                k, v = m.group(1), m.group(2)
                if k in FORA:
                    continue
                k = PROPS.get(k, k)
                saida.append("%s = %s" % (k, valor(v)))
            continue
        if tipo == "connection":
            saida.append(valor(b[0]))
            continue
        avisos.append(b[0])
        saida.extend(b)
    return "\n".join(saida).rstrip() + "\n", avisos


def frames_g3(props):
    """animations do Godot 4 (frames com duração) -> Godot 3 (lista)."""
    m = re.match(r"animations\s*=\s*(\[.*\])\s*$", props, re.S)
    if not m:
        return props
    bruto = m.group(1)
    anims = []
    for am in re.finditer(r'\{\s*"frames":\s*\[(.*?)\],\s*"loop":\s*(\w+),\s*"name":\s*&?"([^"]*)",\s*"speed":\s*([\d.]+)\s*\}', bruto, re.S):
        texturas = re.findall(r'"texture":\s*(SubResource\("[^"]+"\)|ExtResource\("[^"]+"\))', am.group(1))
        anims.append('{\n"frames": [ %s ],\n"loop": %s,\n"name": "%s",\n"speed": %s\n}' % (
            ", ".join(texturas), am.group(2), am.group(3), am.group(4)))
    return "animations = [ %s ]" % ", ".join(anims)


def main():
    texto = open(sys.argv[1], encoding="utf-8").read()
    novo, avisos = converter(texto)
    open(sys.argv[2], "w", encoding="utf-8").write(novo)
    print("%s ok%s" % (sys.argv[2], (" — avisos: %s" % avisos) if avisos else ""))


if __name__ == "__main__":
    main()
