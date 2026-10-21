# Parte comum para COMPILAR o Java do APK (". preparar_classes.sh", depois de
# definir AQUI): deixa em $CACHE (tools/android/.cache, fora do git) as
# classes só para compilar - no aparelho valem as da TV Box e as do APK - e
# põe o classpath em $CLASSES.
#  - android-all.jar: classes do Android 10, do Maven Central, conferido pelo
#    SHA-1 publicado lá (ou ANDROID_ALL=jar já baixado);
#  - godot3-classes.jar: classes do Godot 3.6.3 (FullScreenGodotApp etc.),
#    tiradas do android_source.zip dos modelos de exportação.
ANDROID_ALL_URL=https://repo1.maven.org/maven2/org/robolectric/android-all/10-robolectric-5803371/android-all-10-robolectric-5803371.jar
ANDROID_ALL_SHA1=873cbe64a7ac6fc2f9f5e2f6a24967fcc7a28ff8
CACHE=${CACHE:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/.cache}
MODELOS=${MODELOS:-$HOME/.local/share/godot/templates/3.6.3.stable}
mkdir -p "$CACHE"
# (130 MB que não vão para o git)
[ -f "$CACHE/.gitignore" ] || printf '*\n' > "$CACHE/.gitignore"

if [ ! -f "$CACHE/android-all.jar" ]; then
  if [ -n "${ANDROID_ALL:-}" ] && [ -f "$ANDROID_ALL" ]; then
    cp "$ANDROID_ALL" "$CACHE/android-all.jar.tmp"
  else
    curl -sSfL -o "$CACHE/android-all.jar.tmp" "$ANDROID_ALL_URL"
  fi
  if [ "$(sha1sum "$CACHE/android-all.jar.tmp" | cut -d' ' -f1)" != "$ANDROID_ALL_SHA1" ]; then
    rm -f "$CACHE/android-all.jar.tmp"
    echo "erro: android-all.jar com SHA-1 diferente do Maven Central" >&2
    exit 1
  fi
  mv "$CACHE/android-all.jar.tmp" "$CACHE/android-all.jar"
fi

if [ ! -f "$CACHE/godot3-classes.jar" ]; then
  if [ "$(cat "$MODELOS/version.txt" 2>/dev/null)" != "3.6.3.stable" ]; then
    echo "erro: modelos de exportação do Godot 3.6.3 não encontrados em $MODELOS (use MODELOS=pasta)" >&2
    exit 1
  fi
  # extraído numa pasta só dele; daqui só sai o classes.jar
  T3=$(mktemp -d)
  unzip -q -o "$MODELOS/android_source.zip" libs/release/godot-lib.release.aar -d "$T3"
  unzip -q -o "$T3/libs/release/godot-lib.release.aar" classes.jar -d "$T3"
  mv "$T3/classes.jar" "$CACHE/godot3-classes.jar"
  rm -rf "$T3"
fi

CLASSES="$CACHE/android-all.jar:$CACHE/godot3-classes.jar"
