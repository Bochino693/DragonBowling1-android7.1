#!/bin/bash
# Refaz tools/android/TelaCheia/classes2.dex: a atividade de tela cheia do
# Dragon Bowling (com.lazersport.dragonbowling.TelaCheia) para o APK legado
# do Godot 3.6.3 - sem Gradle. Depois refaça o modelo Android:
#   bash tools/android/TelaCheia/construir.sh
#   python3 -I tools/android/modelo_android.py <android_release.apk> <apktool.jar>
# Precisa de: JDK (javac), os modelos de exportação do Godot 3.6.3 instalados
# e o dalvik-dx 9.0.0_r3 (Maven Central) em DX_JAR (por padrão em
# FERRAMENTAS, ~/ferramentas_godot3, como no montar_apk.sh).
set -e
AQUI=$(cd "$(dirname "$0")" && pwd)
. "$AQUI/../preparar_classes.sh"
FERRAMENTAS=${FERRAMENTAS:-$HOME/ferramentas_godot3}
DX_JAR=${DX_JAR:-$FERRAMENTAS/dalvik-dx-9.0.0_r3.jar}
[ -f "$DX_JAR" ] || { echo "falta: $DX_JAR (dalvik-dx 9.0.0_r3)" >&2; exit 1; }
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/esqueleto" "$T/classes"
# o androidx só para compilar (não entra no dex)
javac --release 8 -Xlint:all -Xlint:-options -encoding UTF-8 -cp "$CLASSES" -d "$T/esqueleto" \
  "$AQUI"/../stubs/androidx/fragment/app/*.java 2>&1 | grep -v JAVA_TOOL_OPTIONS || true
# Java 8: o dx não lê classes mais novas
javac --release 8 -Xlint:all -Xlint:-options -encoding UTF-8 -cp "$CLASSES:$T/esqueleto" \
  -d "$T/classes" "$AQUI"/src/com/lazersport/dragonbowling/*.java 2>&1 | grep -v JAVA_TOOL_OPTIONS || true
ls "$T"/classes/com/lazersport/dragonbowling/TelaCheia.class > /dev/null
# minSdk 21, o mesmo do modelo do Godot 3.6.3
java -cp "$DX_JAR" com.android.dx.command.Main --dex --min-sdk-version=21 --output="$T/classes2.dex" \
  "$T/classes" 2>&1 | grep -v JAVA_TOOL_OPTIONS || true
[ -s "$T/classes2.dex" ] || { echo "o dx não gerou o classes2.dex" >&2; exit 1; }
cp "$T/classes2.dex" "$AQUI/classes2.dex"
echo "ok: tools/android/TelaCheia/classes2.dex ($(stat -c %s "$AQUI/classes2.dex") bytes)"
echo "agora: python3 -I tools/android/modelo_android.py <android_release.apk> <apktool.jar>"
