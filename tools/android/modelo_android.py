"""Faz android/modelo_android/extras.zip: o que o modelo Android oficial do
Godot 3.6.3 (android_release.apk) precisa ganhar para virar o modelo do
Dragon Bowling da TV Box - o mesmo que a Build 10 montava com o Gradle:

  - a atividade de TELA CHEIA (com.lazersport.dragonbowling.TelaCheia, no
    tools/android/TelaCheia/classes2.dex) no lugar da com.godot.game.GodotApp;
  - o tema de tela cheia, inclusive na área de overscan da TV;
  - o jogo na lista de apps da TV (LEANBACK_LAUNCHER), sem exigir tela de
    toque nem o modo leanback;
  - O JOGO ABRE SOZINHO AO LIGAR, com o mesmo método do Strike Kids
    (InicioDaTv): a tela inicial invisível (DragonInicioAtivo, HOME), o
    aviso de "ligou" (DragonLigou, BOOT_COMPLETED e QUICKBOOT_POWERON) e o
    <queries> das telas iniciais (Android 11+).

  - o jogo SÓ na memória interna (installLocation internalOnly): nunca vai
    para um pendrive ou cartão, de onde sumiria.

Sem plugin. Duas permissões, que o Android não pergunta na instalação: a
RECEIVE_BOOT_COMPLETED (dada sozinha) e a SYSTEM_ALERT_WINDOW ("Sobrepor a
outros apps": no Android 10+ é o que deixa o aviso de "ligou" abrir o
jogo; o jogo pede, ou o PREPARAR_TV.bat permite pelo adb). O jogo usa só a
placa Zero Delay.

    python3 -I tools/android/modelo_android.py <android_release.apk oficial> <apktool.jar>

Com o modelo assim, o próprio Godot exporta o APK pronto: o GERAR_APK_AGORA.bat
(Windows) e o montar_apk.sh (Linux) só juntam o oficial com os extras
(tools/android/remendo_apk.jar), exportam e assinam - sem Gradle, sem apktool
e sem aapt2 na hora de gerar. Rode de novo quando mudar a TelaCheia
(tools/android/TelaCheia/construir.sh), o manifesto ou o tema.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

AQUI = os.path.dirname(os.path.abspath(__file__))
P = os.path.dirname(os.path.dirname(AQUI))
SAIDA = os.path.join(P, "android", "modelo_android", "extras.zip")
ATIVIDADE = "com.lazersport.dragonbowling.TelaCheia"
INICIO = "com.lazersport.dragonbowling.DragonInicioAtivo"
LIGOU = "com.lazersport.dragonbowling.DragonLigou"
PERMISSAO_LIGOU = "android.permission.RECEIVE_BOOT_COMPLETED"
# Android 10+: o aviso de "ligou" só abre o jogo com "Sobrepor a outros apps"
PERMISSAO_SOBREPOR = "android.permission.SYSTEM_ALERT_WINDOW"


def trocar_uma(texto, velho, novo, nome):
    assert texto.count(velho) == 1, "modelo inesperado: " + nome
    return texto.replace(velho, novo)


def injetar(manifesto):
    s = open(manifesto, encoding="utf-8").read()
    assert ATIVIDADE not in s, "manifesto já injetado"
    s = trocar_uma(s, 'android:name="com.godot.game.GodotApp"', 'android:name="%s"' % ATIVIDADE, "atividade GodotApp")
    assert "android.permission" not in s.replace('android:permission="android.permission.DUMP"', ""), \
        "o modelo oficial passou a pedir permissão"
    gl = '<uses-feature android:glEsVersion="0x00020000" android:required="true"/>'
    # TV Box: nada de tela de toque nem do modo leanback obrigatórios; a
    # permissão do aviso de "ligou" e (Android 11+) enxergar as outras telas
    # iniciais da TV
    s = trocar_uma(s, gl, gl + '''
    <uses-feature android:name="android.hardware.touchscreen" android:required="false"/>
    <uses-feature android:name="android.software.leanback" android:required="false"/>
    <uses-permission android:name="%s"/>
    <uses-permission android:name="%s"/>
    <queries>
        <intent>
            <action android:name="android.intent.action.MAIN"/>
            <category android:name="android.intent.category.HOME"/>
        </intent>
    </queries>''' % (PERMISSAO_LIGOU, PERMISSAO_SOBREPOR), "glEsVersion")
    # o jogo SÓ na memória interna: nunca vai para um pendrive ou cartão
    # (formatado como memória da TV) - tirado o pendrive, o jogo sumiria
    s = trocar_uma(s, 'android:installLocation="auto"', 'android:installLocation="internalOnly"', "installLocation")
    # o jogo na lista de apps da TV
    a = '<category android:name="android.intent.category.LAUNCHER"/>'
    s = trocar_uma(s, a, a + '''
                <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>''', "categoria LAUNCHER")
    # O JOGO ABRE SOZINHO AO LIGAR (o método do Strike Kids): a tela inicial
    # invisível que traz o jogo e o aviso de "ligou"
    s = trocar_uma(s, "    </application>", '''        <activity android:excludeFromRecents="true" android:exported="true" android:name="%s" android:noHistory="true" android:stateNotNeeded="true" android:theme="@android:style/Theme.Translucent.NoTitleBar">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.HOME"/>
                <category android:name="android.intent.category.DEFAULT"/>
            </intent-filter>
        </activity>
        <receiver android:exported="true" android:name="%s">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>''' % (INICIO, LIGOU), "fim do application")
    open(manifesto, "w", encoding="utf-8").write(s)


def tema_de_tela_cheia(dec):
    """O tema principal (o que a TelaCheia usa) e o da abertura em tela
    cheia, inclusive na área de overscan da TV (a moldura preta que algumas
    TV Boxes deixam em volta da imagem)."""
    p = os.path.join(dec, "res", "values", "styles.xml")
    s = open(p, encoding="utf-8").read()
    s = trocar_uma(s, '<style name="GodotAppMainTheme" parent="@android:style/Theme.Black.NoTitleBar" />',
                   '''<style name="GodotAppMainTheme" parent="@android:style/Theme.Black.NoTitleBar.Fullscreen">
        <item name="android:windowOverscan">true</item>
        <item name="android:windowBackground">@android:color/black</item>
    </style>''', "GodotAppMainTheme")
    s = trocar_uma(s, '''<style name="GodotAppSplashTheme" parent="@android:style/Theme.Black.NoTitleBar.Fullscreen">
        <item name="android:windowBackground">@drawable/splash_drawable</item>''',
                   '''<style name="GodotAppSplashTheme" parent="@android:style/Theme.Black.NoTitleBar.Fullscreen">
        <item name="android:windowBackground">@drawable/splash_drawable</item>
        <item name="android:windowOverscan">true</item>''', "GodotAppSplashTheme")
    open(p, "w", encoding="utf-8").write(s)
    p = os.path.join(dec, "res", "values-v28", "styles.xml")
    if os.path.exists(p):
        s = open(p, encoding="utf-8").read()
        s = trocar_uma(s, '<item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>',
                       '<item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>\n'
                       '        <item name="android:windowOverscan">true</item>', "GodotAppSplashTheme (v28)")
        open(p, "w", encoding="utf-8").write(s)


def entra_nos_extras(nome):
    return nome.startswith("res/") or nome in ("resources.arsc", "AndroidManifest.xml", "classes2.dex")


def main():
    if len(sys.argv) != 3:
        sys.exit("uso: modelo_android.py <android_release.apk oficial> <apktool.jar>")
    oficial, apktool = sys.argv[1], sys.argv[2]
    dex = os.path.join(AQUI, "TelaCheia", "classes2.dex")
    assert os.path.exists(dex), "falta %s (rode tools/android/TelaCheia/construir.sh)" % dex
    t = tempfile.mkdtemp(prefix="modelo_android_")
    try:
        def apk(*args):
            subprocess.run(["java", "-jar", apktool] + list(args), check=True)
        apk("d", "-s", "-f", "-p", os.path.join(t, "fw"), "-o", os.path.join(t, "dec"), oficial)
        dec = os.path.join(t, "dec")
        # o apktool decodifica res/drawable-hdpi-v4/x.png em res/drawable-hdpi/
        # e o aapt2 remontaria sem o "-v4": o Godot não acharia os ícones e a
        # abertura para trocar pelos do jogo. Cada arquivo volta para a pasta
        # com o nome do oficial.
        oficiais = [i.filename for i in zipfile.ZipFile(oficial).infolist() if i.filename.startswith("res/")]
        for n in oficiais:
            _, d, f = n.split("/", 2)
            d0 = re.sub(r"-v\d+$", "", d)
            origem = os.path.join(dec, "res", d0, f)
            if d0 != d and os.path.exists(origem) and not os.path.exists(os.path.join(dec, "res", d, f)):
                os.makedirs(os.path.join(dec, "res", d), exist_ok=True)
                os.rename(origem, os.path.join(dec, "res", d, f))
        for d in os.listdir(os.path.join(dec, "res")):
            if not os.listdir(os.path.join(dec, "res", d)):
                os.rmdir(os.path.join(dec, "res", d))
        injetar(os.path.join(dec, "AndroidManifest.xml"))
        tema_de_tela_cheia(dec)
        shutil.copy(dex, dec)
        montado = os.path.join(t, "modelo.apk")
        apk("b", "-p", os.path.join(t, "fw"), dec, "-o", montado)

        zo = zipfile.ZipFile(oficial)
        zm = zipfile.ZipFile(montado)
        nomes_o = {i.filename for i in zo.infolist()}
        nomes_m = {i.filename for i in zm.infolist()}
        # (o que não é recurso, o remendo copia do oficial: bibliotecas,
        # classes.dex, META-INF...) os nomes que o Godot troca na exportação
        # (ícones e abertura) continuam lá
        sumiu = sorted(n for n in nomes_o if n.startswith("res/") and n not in nomes_m)
        assert not sumiu, "recursos do oficial com outro nome no modelo: %s" % sumiu[:10]
        assert "classes2.dex" in nomes_m, "o modelo montado ficou sem o classes2.dex"
        os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
        n = 0
        with zipfile.ZipFile(SAIDA + ".parcial", "w") as zs:
            for i in zm.infolist():
                if not entra_nos_extras(i.filename):
                    continue
                novo = zipfile.ZipInfo(i.filename, date_time=(2026, 1, 1, 0, 0, 0))
                novo.compress_type = i.compress_type
                novo.external_attr = 0o644 << 16
                zs.writestr(novo, zm.read(i.filename))
                n += 1
        os.replace(SAIDA + ".parcial", SAIDA)
        print("ok: %s (%d arquivos, %d bytes)" % (os.path.relpath(SAIDA, P), n, os.path.getsize(SAIDA)))
    finally:
        shutil.rmtree(t, ignore_errors=True)


if __name__ == "__main__":
    main()
