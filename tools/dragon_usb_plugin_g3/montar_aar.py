"""Monta android/plugins/DragonUsbSerial-release.aar (plugin v1 do Godot 3.6).

    python tools/dragon_usb_plugin_g3/montar_aar.py ANDROID_JAR

O plugin USB do Dragon Bowling (Arduino dos LEDs) foi escrito para o
Godot 4 (tools/dragon_usb_plugin, Kotlin). A classe compilada serve igual
no Godot 3.6 — o construtor GodotPlugin(Godot) e o @UsedByGodot são os
mesmos —; muda só o registro (org.godotengine.plugin.v1 no manifesto e o
.gdap). Aqui o .aar do Godot 4 é reempacotado assim, e ganha a atividade
que faz o Android lembrar a permissão do Arduino ("Usar por padrão").

ANDROID_JAR: android.jar do SDK (ou android-all 7.1) para compilar a
atividade. O .aar pronto já vem no projeto.
"""
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parents[1]
ORIGEM = RAIZ / "addons" / "DragonUsbSerial" / "bin" / "release" / "plugin-release.aar"
SAIDA = RAIZ / "android" / "plugins" / "DragonUsbSerial-release.aar"
MANIFESTO = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.lazersport.dragon.usbserial">
    <uses-sdk android:minSdkVersion="19" />
    <uses-feature android:name="android.hardware.usb.host" android:required="false" />
    <application>
        <activity
            android:name="com.lazersport.dragon.usbserial.UsbAttachActivity"
            android:exported="true"
            android:excludeFromRecents="true"
            android:noHistory="true"
            android:theme="@android:style/Theme.Translucent.NoTitleBar">
            <intent-filter>
                <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
            </intent-filter>
            <meta-data
                android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"
                android:resource="@xml/dragon_usb_devices" />
        </activity>
        <meta-data
            android:name="org.godotengine.plugin.v1.DragonUsbSerial"
            android:value="com.lazersport.dragon.usbserial.GodotAndroidPlugin" />
    </application>
</manifest>
"""


def main():
    android_jar = sys.argv[1]
    with tempfile.TemporaryDirectory() as t:
        t = Path(t)
        with zipfile.ZipFile(ORIGEM) as z:
            (t / "velho.jar").write_bytes(z.read("classes.jar"))
        (t / "out").mkdir()
        subprocess.check_call(["javac", "--release", "8", "-nowarn", "-cp", android_jar,
                               "-d", str(t / "out"), str(AQUI / "UsbAttachActivity.java")])
        with zipfile.ZipFile(t / "classes.jar", "w", zipfile.ZIP_DEFLATED) as j:
            with zipfile.ZipFile(t / "velho.jar") as v:
                for item in v.infolist():
                    if not item.is_dir():
                        j.writestr(item.filename, v.read(item.filename))
            for f in sorted((t / "out").rglob("*.class")):
                j.write(f, f.relative_to(t / "out").as_posix())
        SAIDA.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(SAIDA, "w", zipfile.ZIP_DEFLATED) as a:
            a.writestr("AndroidManifest.xml", MANIFESTO)
            a.write(t / "classes.jar", "classes.jar")
            a.writestr("R.txt", "int xml dragon_usb_devices 0x0\n")
            a.write(AQUI / "dragon_usb_devices.xml", "res/xml/dragon_usb_devices.xml")
    print("ok", SAIDA)


if __name__ == "__main__":
    main()
