#!/bin/bash
# APK pronto da TV Box (Dragon Bowling, Godot 3.6.3, OpenGL ES 2.0, Mali-450)
# - o mesmo caminho do GERAR_APK_AGORA.bat (Windows), sem Gradle:
#   bash tools/android/montar_apk.sh [saida.apk] [nome_da_versao]
# (sem saída: APK-Pronto/DragonBowling_Mali450.apk; sem versão: a do preset)
# 1. copia para uma pasta de trabalho SÓ os arquivos do jogo
#    (tools/android/arquivos_do_jogo.txt); na cópia, o preset sai sem Gradle,
#    sem assinar e sem plugins, e a imagem de abertura girada como a tela;
# 2. monta o MODELO Android do Dragon Bowling: o oficial do Godot 3.6.3 +
#    android/modelo_android/extras.zip (tools/android/remendo_apk.jar) - a
#    atividade de tela cheia, o tema de tela cheia e a TV Box no manifesto;
# 3. exporta o preset "Android" com o Godot 3.6.3 headless (modelo legado,
#    SEM assinar), com uma configuração do editor só dele;
# 4. assina com a chave do projeto (uber-apk-signer);
# 5. confere (conferir_apk.py, com o androguard).
# Se mudar a TelaCheia, o manifesto ou o tema: bash tools/android/TelaCheia/construir.sh
# e python3 -I tools/android/modelo_android.py <android_release.apk> <apktool.jar>.
#
# Variáveis (todas com padrão; as ferramentas ficam em FERRAMENTAS, por
# padrão ~/ferramentas_godot3):
#   GODOT3    Godot 3.6.3 headless (Godot_v3.6.3-stable_linux_headless.64)
#   MODELOS   modelos de exportação 3.6.3 (~/.local/share/godot/templates/3.6.3.stable)
#   UBER_JAR  uber-apk-signer 1.3
#   PY        python com o androguard (para conferir; sem ele, só avisa)
#   TRAB      pasta de trabalho (apagada a cada vez)
#   GIRO      1 (topo do jogo na esquerda do HDMI), -1 (na direita) ou 0;
#             sem ele vale o dragon/tela/giro do project.godot
set -e
FERRAMENTAS=${FERRAMENTAS:-$HOME/ferramentas_godot3}
AQUI=$(cd "$(dirname "$0")" && pwd)
P=$(cd "$AQUI/../.." && pwd)
SAIDA=$(realpath -m "${1:-$P/APK-Pronto/DragonBowling_Mali450.apk}")
NOME_VERSAO=${2:-}
GODOT3=${GODOT3:-$FERRAMENTAS/Godot_v3.6.3-stable_linux_headless.64}
MODELOS=${MODELOS:-$HOME/.local/share/godot/templates/3.6.3.stable}
UBER_JAR=${UBER_JAR:-$FERRAMENTAS/uber-apk-signer-1.3.0.jar}
PY=${PY:-$FERRAMENTAS/venv_apk/bin/python}
TRAB=${TRAB:-${TMPDIR:-/tmp}/dragonbowling_apk}
CHAVE=$AQUI/dragonbowling.keystore

for f in "$GODOT3" "$MODELOS/android_release.apk" "$UBER_JAR" "$CHAVE" "$AQUI/arquivos_do_jogo.txt" \
  "$AQUI/remendo_apk.jar" "$P/android/modelo_android/extras.zip"; do
  [ -f "$f" ] || { echo "falta: $f" >&2; exit 1; }
done
[ "$(cat "$MODELOS/version.txt")" = "3.6.3.stable" ] || { echo "os modelos em $MODELOS não são do Godot 3.6.3" >&2; exit 1; }
case "$TRAB" in /|"$HOME"|"$P"|"$P"/*) echo "TRAB perigoso: $TRAB" >&2; exit 1 ;; esac
# num clone do git, a lista do jogo tem de estar em dia
if [ -d "$P/.git" ]; then
  python3 -I "$AQUI/lista_do_jogo.py" --conferir
fi
rm -rf "$TRAB"
mkdir -p "$TRAB/projeto" "$TRAB/saida" "$(dirname "$SAIDA")"

echo "== 1. projeto"
NOME_VERSAO="$NOME_VERSAO" GIRO="${GIRO:-}" python3 -I - "$P" "$AQUI/arquivos_do_jogo.txt" "$TRAB/projeto" <<'PY'
import os, re, shutil, sys
origem, lista, destino = sys.argv[1:4]
nomes = [l.strip() for l in open(lista, encoding='utf-8') if l.strip()]
faltam = [n for n in nomes if not os.path.isfile(os.path.join(origem, n))]
assert not faltam, 'faltam arquivos do jogo: %s' % faltam[:10]
for n in nomes:
    os.makedirs(os.path.dirname(os.path.join(destino, n)) or destino, exist_ok=True)
    shutil.copy2(os.path.join(origem, n), os.path.join(destino, n))
os.chdir(destino)
p = 'export_presets.cfg'
s = open(p, encoding='utf-8').read()
i = s.index('name="Android"')
j = s.find('\n[preset.', s.index('.options]', i))
j = len(s) if j < 0 else j
b = s[i:j]
# o APK sai do Godot sem Gradle, sem assinar e sem plugins; a tela cheia e
# a TV Box vêm no modelo do Dragon Bowling
b = re.sub(r'(?m)^custom_build/use_custom_build=.*$', 'custom_build/use_custom_build=false', b)
b = re.sub(r'(?m)^package/signed=.*$', 'package/signed=false', b)
# (o min/target SDK só valem com o Gradle; sem ele o Godot recusa exportar)
b = re.sub(r'(?m)^custom_build/(min_sdk|target_sdk)=.*$', r'custom_build/\1=""', b)
b = re.sub(r'(?m)^(plugins/[A-Za-z0-9_]+)=.*$', r'\1=false', b)
if os.environ['NOME_VERSAO']:
    b = re.sub(r'(?m)^version/name=.*$', 'version/name="%s"' % os.environ['NOME_VERSAO'], b)
# a imagem de abertura girada como a tela do jogo (dragon/tela/giro) entra
# no APK; as outras duas, não
p2 = 'project.godot'
c = open(p2, encoding='utf-8').read()
giro = os.environ['GIRO'] or (re.search(r'(?m)^tela/giro=(-?\d+)', c) or [None, '1'])[1]
assert giro in ('1', '-1', '0'), 'GIRO: 1, -1 ou 0'
c, n = re.subn(r'(?m)^tela/giro=.*$', 'tela/giro=' + giro, c)
assert n == 1, 'dragon/tela/giro'
nome = {'1': '1', '-1': 'm1', '0': '0'}[giro]
c, n = re.subn(r'(?m)^boot_splash/image=.*$', 'boot_splash/image="res://sprites/marca/splash_giro_%s.png"' % nome, c)
assert n == 1, 'boot_splash/image'
open(p2, 'w', encoding='utf-8').write(c)
m = re.search(r'(?m)^exclude_filter="([^"]*)"', s[:i] + b)
filtro = [f for f in m.group(1).split(',') if f and not f.startswith('sprites/marca/splash_giro_')]
filtro += ['sprites/marca/splash_giro_%s.png' % x for x in ('0', '1', 'm1') if x != nome]
s = s[:i] + b + s[j:]
s = s[:m.start(1)] + ','.join(filtro) + s[m.end(1):]
open(p, 'w', encoding='utf-8').write(s)
print('preparado: %d arquivos do jogo (versão: %s, giro: %s)' % (len(nomes), os.environ['NOME_VERSAO'] or 'a do preset', giro))
PY
grep -n "^version/\|^package/signed\|^custom_build/use_custom_build\|^exclude_filter" "$TRAB/projeto/export_presets.cfg"

echo "== 2. modelo Android do Dragon Bowling"
CASA=$TRAB/godot
mkdir -p "$CASA/data/godot/templates/3.6.3.stable"
echo "3.6.3.stable" > "$CASA/data/godot/templates/3.6.3.stable/version.txt"
java -jar "$AQUI/remendo_apk.jar" "$MODELOS/android_release.apk" "$P/android/modelo_android/extras.zip" \
  "$CASA/data/godot/templates/3.6.3.stable/android_release.apk" 2>&1 | grep -v JAVA_TOOL_OPTIONS

echo "== 3. exportar (Godot 3.6.3)"
# Configuração do editor só desta exportação (XDG_*: não mexe na do usuário
# nem atrapalha outro Godot aberto). O Godot 3 recusa exportar para Android
# sem: keystore de depuração, pasta do Java (bin/java) e um SDK do Android com
# platform-tools/adb e build-tools/*/apksigner - mesmo exportando SEM assinar.
# O SDK aqui é de mentira (nada é baixado): o adb só responde "nenhum
# aparelho" e o apksigner nunca é chamado (package/signed=false).
SDK=$TRAB/sdk_falso
mkdir -p "$CASA/config/godot" "$CASA/cache" "$SDK/platform-tools" "$SDK/build-tools/falso"
cat > "$SDK/platform-tools/adb" <<'SH'
#!/bin/sh
# adb de mentira (o editor pergunta pelos aparelhos de tempos em tempos)
echo "List of devices attached"
exit 0
SH
cat > "$SDK/build-tools/falso/apksigner" <<'SH'
#!/bin/sh
# apksigner de mentira: o APK sai do Godot sem assinar; o montar_apk.sh assina
echo "apksigner falso: exporte com package/signed=false (o montar_apk.sh assina)" >&2
exit 1
SH
chmod +x "$SDK/platform-tools/adb" "$SDK/build-tools/falso/apksigner"
JAVA_DIR=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}
cat > "$CASA/config/godot/editor_settings-3.tres" <<TRES
[gd_resource type="EditorSettings" format=2]

[resource]
export/android/java_sdk_path = "$JAVA_DIR"
export/android/android_sdk_path = "$SDK"
export/android/debug_keystore = "$CHAVE"
export/android/debug_keystore_user = "dragonbowling"
export/android/debug_keystore_pass = "dragonbowling"
export/android/shutdown_adb_on_exit = false
TRES
cd "$TRAB/projeto"
XDG_CONFIG_HOME="$CASA/config" XDG_DATA_HOME="$CASA/data" XDG_CACHE_HOME="$CASA/cache" \
  timeout 2400 "$GODOT3" --no-window --audio-driver Dummy --path . --export "Android" "$TRAB/saida/sem_assinatura.apk" \
  > "$TRAB/export.log" 2>&1 || true
# (inofensivos: o "free a NULL RID" é do Godot sem tela; o "Cannot open file
# 'res://.import/..." é da 1a importação, quando o Godot procura as
# dependências de cada som antes de criá-lo)
grep -E "ERROR|WARNING|export:" "$TRAB/export.log" | grep -v -e "free a NULL RID" -e "Cannot open file 'res://.import/" \
  -e "at: get_dependencies (core/io/resource_format_binary.cpp" | tail -15 || true
if [ ! -s "$TRAB/saida/sem_assinatura.apk" ]; then
  echo "a exportação falhou (log: $TRAB/export.log)" >&2
  tail -40 "$TRAB/export.log" >&2
  exit 1
fi
ls -la "$TRAB/saida/sem_assinatura.apk"

echo "== 4. assinar"
mkdir -p "$TRAB/assinado"
java -jar "$UBER_JAR" -a "$TRAB/saida/sem_assinatura.apk" -o "$TRAB/assinado" --ks "$CHAVE" --ksAlias dragonbowling \
  --ksPass dragonbowling --ksKeyPass dragonbowling 2>&1 | grep -E "verified|success|error|ERROR|Subject" || true
cp "$TRAB/assinado/sem_assinatura-aligned-signed.apk" "$SAIDA"
ls -la "$SAIDA"

echo "== 5. conferir"
if [ -x "$PY" ] && "$PY" -I -c "import androguard" 2>/dev/null; then
  CERT=$(keytool -exportcert -alias dragonbowling -keystore "$CHAVE" -storepass dragonbowling 2>/dev/null | sha256sum | cut -d' ' -f1)
  "$PY" -I "$AQUI/conferir_apk.py" "$SAIDA" --certificado "$CERT"
else
  echo "aviso: sem python com androguard ($PY): APK não conferido"
fi
echo MONTAR_OK
