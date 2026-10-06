"""Troca, dentro de android/plugins/DragonUsbSerial-release.aar, a classe do
plugin (a antiga em Kotlin) pela versao em Java de java/ (sem o crash nativo
do USB ao fechar a porta - ver o comentario no GodotAndroidPlugin.java).

    python tools/dragon_usb_plugin_g3/trocar_plugin_java.py ANDROID_JAR GODOT_LIB_JAR

ANDROID_JAR: android.jar do SDK (qualquer API >= 16).
GODOT_LIB_JAR: classes.jar de dentro do godot-lib.release.aar do Godot 3.6.2.
stubs/ tem so as assinaturas de usb-serial-for-android 3.11.0 para compilar;
a biblioteca de verdade entra no APK pela dependencia do .gdap.
"""
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

AQUI = Path(__file__).resolve().parent
AAR = AQUI.parents[1] / "android" / "plugins" / "DragonUsbSerial-release.aar"
PACOTE = "com/lazersport/dragon/usbserial/GodotAndroidPlugin"


def main(android_jar: str, godot_jar: str) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        stubs_out, out = tmp / "stubs", tmp / "out"
        stubs_out.mkdir()
        out.mkdir()
        subprocess.run(["javac", "--release", "8", "-nowarn", "-d", str(stubs_out), "-cp", android_jar]
                       + [str(p) for p in (AQUI / "stubs").rglob("*.java")], check=True)
        subprocess.run(["javac", "--release", "8", "-Xlint:-options", "-d", str(out),
                        "-cp", f"{android_jar}{';' if sys.platform == 'win32' else ':'}{godot_jar}"
                        f"{';' if sys.platform == 'win32' else ':'}{stubs_out}"]
                       + [str(p) for p in (AQUI / "java").rglob("*.java")], check=True)
        novas = {p.relative_to(out).as_posix(): p.read_bytes() for p in out.rglob("*.class")}
        with zipfile.ZipFile(AAR) as z:
            itens = {i.filename: z.read(i.filename) for i in z.infolist()}
        antigo = tmp / "classes_antigo.jar"
        antigo.write_bytes(itens["classes.jar"])
        novo = tmp / "classes.jar"
        with zipfile.ZipFile(antigo) as zi, zipfile.ZipFile(novo, "w", zipfile.ZIP_DEFLATED) as zo:
            for i in zi.infolist():
                if i.filename.startswith(PACOTE):
                    continue          # a classe Kotlin e as internas dela
                zo.writestr(i, zi.read(i.filename))
            for nome, dados in sorted(novas.items()):
                zo.writestr(nome, dados)
        itens["classes.jar"] = novo.read_bytes()
        with zipfile.ZipFile(AAR, "w", zipfile.ZIP_DEFLATED) as z:
            for nome, dados in itens.items():
                z.writestr(nome, dados)
    print("plugin Java no", AAR, ":", ", ".join(sorted(novas)))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
