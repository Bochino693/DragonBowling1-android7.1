"""A LISTA DOS ARQUIVOS DO JOGO (tools/android/arquivos_do_jogo.txt).

O GERAR_APK_AGORA.bat (Windows) e o montar_apk.sh (Linux) exportam uma CÓPIA
do projeto com exatamente estes arquivos. Assim:
  - arquivo que sobrou de uma versão antiga na pasta (zip novo extraído por
    cima do velho, script do Godot 4 esquecido) não entra no APK nem dá erro
    na importação - e nada da pasta é apagado;
  - se falta um arquivo da lista (zip extraído pela metade), a geração para
    e diz qual.

Fora da lista: ferramentas, documentos, o Arduino, o modelo Android, testes
e os arquivos do PC. Depois de acrescentar ou tirar um arquivo do jogo:
    python3 -I tools/android/lista_do_jogo.py            (refaz a lista)
    python3 -I tools/android/lista_do_jogo.py --conferir (só confere)
"""
import os
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
P = os.path.dirname(os.path.dirname(AQUI))
LISTA = os.path.join(AQUI, "arquivos_do_jogo.txt")
PASTAS_FORA = {"tools", "docs", "arduino", "android", "addons", "build", "APK-Pronto", "logs",
               "sobras_de_versoes_antigas", ".teste", ".import", ".git", ".godot"}


def do_jogo(nome):
    partes = nome.split("/")
    if len(partes) > 1:
        return partes[0] not in PASTAS_FORA and not partes[-1] == ".gdignore"
    # na raiz: só o que o Godot usa
    return not (nome.startswith(".") or nome.lower().endswith((".bat", ".ps1", ".txt", ".md", ".apk", ".zip")))


def arquivos_do_git():
    saida = subprocess.run(["git", "-C", P, "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                           check=True, stdout=subprocess.PIPE).stdout.decode("utf-8")
    return sorted(n for n in set(saida.split("\0")) if n and os.path.isfile(os.path.join(P, n)) and do_jogo(n))


def main():
    novos = arquivos_do_git()
    for obrigatorio in ("project.godot", "export_presets.cfg"):
        assert obrigatorio in novos, "falta " + obrigatorio
    texto = "".join(n + "\n" for n in novos)
    if "--conferir" in sys.argv:
        atual = open(LISTA, encoding="utf-8").read() if os.path.exists(LISTA) else ""
        if atual != texto:
            antigos = set(atual.split())
            print("A LISTA DO JOGO ESTÁ DESATUALIZADA (rode: python3 -I tools/android/lista_do_jogo.py)")
            for n in sorted(set(novos) - antigos):
                print("  + " + n)
            for n in sorted(antigos - set(novos)):
                print("  - " + n)
            sys.exit(1)
        print("lista do jogo em dia: %d arquivos" % len(novos))
        return
    with open(LISTA, "w", encoding="utf-8", newline="\n") as f:
        f.write(texto)
    print("ok: tools/android/arquivos_do_jogo.txt (%d arquivos)" % len(novos))


if __name__ == "__main__":
    main()
