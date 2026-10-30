# Confere o APK pronto da TV Box (Dragon Bowling, Godot 3.6.3, OpenGL ES 2.0)
# feito pelo montar_apk.sh: assinatura (e se é a chave do projeto), manifesto
# (pacote, só as permissões de abrir ao ligar, só na memória interna,
# recursos opcionais, a atividade de tela cheia na lista de apps da TV, a
# tela inicial e o aviso de "ligou" do método do Strike Kids), as duas ABIs
# do Godot, o projeto em assets/, o classes2.dex com a TelaCheia e o
# InicioDaTv e o tema de tela cheia.
# Precisa do androguard (python do venv):
#   python -I conferir_apk.py <apk> [--certificado <sha256>]
# Sai com código 1 se algo falhar.
import hashlib
import os
import sys

from loguru import logger

logger.remove()
from androguard.core.apk import APK  # noqa: E402
from androguard.core.dex import DEX  # noqa: E402

ARGS = sys.argv[1:]
if not ARGS or ARGS[0].startswith('--'):
    sys.exit('uso: conferir_apk.py <apk> [--certificado <sha256>]')
CAMINHO = ARGS[0]
CERTIFICADO = ARGS[ARGS.index('--certificado') + 1].lower().replace(':', '') if '--certificado' in ARGS else ''

NS = '{http://schemas.android.com/apk/res/android}'
PACOTE = 'com.lazersport.dragonbowling.s905l'
ATIVIDADE = 'com.lazersport.dragonbowling.TelaCheia'
INICIO = 'com.lazersport.dragonbowling.DragonInicioAtivo'
LIGOU = 'com.lazersport.dragonbowling.DragonLigou'
PERMISSAO_LIGOU = 'android.permission.RECEIVE_BOOT_COMPLETED'
PERMISSAO_SOBREPOR = 'android.permission.SYSTEM_ALERT_WINDOW'
ABIS = ['arm64-v8a', 'armeabi-v7a']
CATEGORIAS = ['android.intent.category.LAUNCHER', 'android.intent.category.LEANBACK_LAUNCHER']

falhas = []


def checar(ok, texto):
    print(('ok     ' if ok else 'FALHA  ') + texto)
    if not ok:
        falhas.append(texto)


a = APK(CAMINHO)
m = a.get_android_manifest_xml()
app = m.find('application')
res = a.get_android_resources()

print('== APK', CAMINHO)
print('pacote:', a.get_package(), '| versão:', a.get_androidversion_name(), '| código:', a.get_androidversion_code())
print('minSdk:', a.get_min_sdk_version(), '| targetSdk:', a.get_target_sdk_version(), '| atividade principal:', a.get_main_activity())
checar(a.get_package() == PACOTE, 'pacote ' + PACOTE)
checar(int(a.get_min_sdk_version() or 99) <= 25, 'instala no Android 7.1 (minSdk %s)' % a.get_min_sdk_version())

# assinatura
v = (a.is_signed_v1(), a.is_signed_v2(), a.is_signed_v3())
checar(v[1] or v[2], 'assinado (v1/v2/v3: %s/%s/%s)' % v)
if CERTIFICADO:
    certs = {hashlib.sha256(c.dump()).hexdigest() for c in a.get_certificates()}
    checar(CERTIFICADO in certs, 'assinado com a chave do projeto (sha256 %s...)' % CERTIFICADO[:16])

# só as permissões de abrir ao ligar (nenhuma é perguntada na instalação):
# o aviso de "ligou" e, no Android 10+, o "Sobrepor a outros apps" que
# deixa esse aviso abrir o jogo. O jogo usa só a placa Zero Delay
perms = sorted(a.get_permissions())
print('permissões:', perms)
checar(perms == sorted([PERMISSAO_LIGOU, PERMISSAO_SOBREPOR]), 'só RECEIVE_BOOT_COMPLETED e SYSTEM_ALERT_WINDOW')
# o jogo SÓ na memória interna (nunca num pendrive ou cartão, de onde sumiria)
local = m.get(NS + 'installLocation')
checar(local in ('1', 'internalOnly'), 'só na memória interna (installLocation = %s)' % local)
feats = {(f.get(NS + 'name'), f.get(NS + 'required')) for f in m.findall('uses-feature')}
gles = [f.get(NS + 'glEsVersion') for f in m.findall('uses-feature') if f.get(NS + 'glEsVersion')]
print('uses-feature:', sorted(str(f) for f in feats), '| glEsVersion:', gles)
checar(gles in (['0x00020000'], ['0x20000'], ['131072']), 'OpenGL ES 2.0 (glEsVersion 0x00020000)')
for nome in ['android.hardware.touchscreen', 'android.software.leanback']:
    checar((nome, 'false') in feats, 'uses-feature %s opcional' % nome)
checar(not any(n and 'usb' in n for n, _ in feats), 'sem USB (nenhum plugin)')

# as duas ABIs do Godot (TV Box de 32 e de 64 bits) e o projeto em assets/
arquivos = a.get_files()
print('abis:', sorted({f.split('/')[1] for f in arquivos if f.startswith('lib/')}))
for abi in ABIS:
    checar('lib/%s/libgodot_android.so' % abi in arquivos, 'lib/%s/libgodot_android.so' % abi)
checar('assets/project.binary' in arquivos, 'projeto exportado (assets/project.binary)')
importados = [f for f in arquivos if f.startswith('assets/.import/')]
checar(len(importados) >= 30, 'arquivos do jogo importados no APK: %d' % len(importados))
# e todos os sons da lista do jogo (a conta acima não pega uns poucos a menos)
lista = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'arquivos_do_jogo.txt')
sons_da_lista = [n for n in open(lista, encoding='utf-8').read().splitlines() if n.startswith('songs/') and n.endswith(('.wav', '.ogg'))]
sons = [f for f in importados if f.endswith(('.sample', '.oggstr'))]
checar(len(sons) >= len(sons_da_lista), 'sons do jogo no APK: %d de %d' % (len(sons), len(sons_da_lista)))
for f in ('assets/autoload/Preparo.gdc', 'assets/scripts/game.gdc', 'assets/fonts/emoji_do_jogo.ttf'):
    checar(f in arquivos, f)
checar(not any(f.startswith(('assets/tools/', 'assets/docs/', 'assets/addons/', 'assets/arduino/', 'assets/.teste/'))
               for f in arquivos), 'sem ferramentas, documentos, Arduino ou testes dentro do APK')

# plugins: nenhum
meta = {md.get(NS + 'name'): md.get(NS + 'value') for md in app.findall('meta-data')}
checar(not any(k.startswith('org.godotengine.plugin.') for k in meta), 'nenhum plugin do Godot no manifesto')

# atividades: a TelaCheia no lugar da GodotApp
atividades = {act.get(NS + 'name'): act for act in app.findall('activity')}
print('atividades:', sorted(atividades))
checar('com.godot.game.GodotApp' not in atividades, 'sem a com.godot.game.GodotApp do modelo')
principal = atividades.get(ATIVIDADE)
checar(principal is not None, 'atividade ' + ATIVIDADE)
if principal is not None:
    cats = [c.get(NS + 'name') for f in principal.findall('intent-filter') for c in f.findall('category')]
    print('TelaCheia: screenOrientation =', principal.get(NS + 'screenOrientation'), '| tema =',
          principal.get(NS + 'theme'), '| categorias:', cats)
    for c in CATEGORIAS:
        checar(c in cats, 'TelaCheia com %s' % c.split('.')[-1])
    # a tela inicial é a DragonInicioAtivo: um "Dragon Bowling" só na escolha
    checar('android.intent.category.HOME' not in cats, 'TelaCheia sem HOME (a tela inicial é a %s)' % INICIO.split('.')[-1])
checar(a.get_main_activity() == ATIVIDADE, 'a TelaCheia é a que abre o jogo')

# O JOGO ABRE SOZINHO AO LIGAR (o método do Strike Kids): a tela inicial
inicio = atividades.get(INICIO)
checar(inicio is not None, 'atividade da tela inicial ' + INICIO)
if inicio is not None:
    filtros = [([a_.get(NS + 'name') for a_ in f.findall('action')], [c.get(NS + 'name') for c in f.findall('category')])
               for f in inicio.findall('intent-filter')]
    print('   exported=%s noHistory=%s filtros=%s' % (inicio.get(NS + 'exported'), inicio.get(NS + 'noHistory'), filtros))
    checar(any('android.intent.action.MAIN' in acs and 'android.intent.category.HOME' in cs
               and 'android.intent.category.DEFAULT' in cs for acs, cs in filtros), '   MAIN + HOME + DEFAULT')
    checar(inicio.get(NS + 'exported') == 'true', '   exported')
casas = [c.get(NS + 'name') for q in m.findall('queries') for i in q.findall('intent') for c in i.findall('category')]
checar('android.intent.category.HOME' in casas, '<queries> das telas iniciais (Android 11+)')
# e o aviso de "ligou" (na tomada)
ligou = [r for r in app.findall('receiver') if r.get(NS + 'name') == LIGOU]
acoes_ligou = [a_.get(NS + 'name') for r in ligou for f in r.findall('intent-filter') for a_ in f.findall('action')]
checar('android.intent.action.BOOT_COMPLETED' in acoes_ligou and 'android.intent.action.QUICKBOOT_POWERON' in acoes_ligou,
       'DragonLigou com BOOT_COMPLETED e QUICKBOOT_POWERON (%s)' % acoes_ligou)

# o tema de tela cheia (o que a TelaCheia procura pelo nome)
pk = res.get_packages_names()[0]
estilos = res.get_public_resources(pk).decode('utf-8', 'replace')
checar(pk == 'com.godot.game', 'recursos no pacote com.godot.game (%s)' % pk)
checar('name="GodotAppMainTheme"' in estilos, 'tema GodotAppMainTheme no APK')

# dex: o Godot no classes.dex, a TelaCheia no classes2.dex
print('dex:', sorted(n for n in arquivos if n.endswith('.dex')))
d1 = DEX(a.get_file('classes.dex'))
nomes1 = {c.get_name() for c in d1.get_classes()}
checar('Lorg/godotengine/godot/FullScreenGodotApp;' in nomes1, 'classes.dex tem a FullScreenGodotApp do Godot')
checar('classes2.dex' in arquivos, 'classes2.dex no APK')
d2 = DEX(a.get_file('classes2.dex'))
classes2 = {c.get_name(): c for c in d2.get_classes()}
print('classes2:', sorted(classes2))
tela = classes2.get('Lcom/lazersport/dragonbowling/TelaCheia;')
checar(tela is not None, 'classes2.dex tem a TelaCheia')
if tela is not None:
    checar(tela.get_superclassname() == 'Lorg/godotengine/godot/FullScreenGodotApp;', 'TelaCheia estende FullScreenGodotApp')
    metodos = {mt.get_name() for mt in tela.get_methods()}
    for nome in ('onCreate', 'onResume', 'onWindowFocusChanged', 'onActivityResult'):
        checar(nome in metodos, '   TelaCheia.%s' % nome)
for nome in ('DragonInicioAtivo', 'DragonLigou', 'InicioDaTv'):
    checar('Lcom/lazersport/dragonbowling/%s;' % nome in classes2, 'classes2.dex tem a ' + nome)
checar(not any(k.startswith('Landroidx/') for k in classes2), 'classes2.dex sem androidx (o esqueleto não vazou)')
outros = [n for n in arquivos if n.endswith('.dex') and n not in ('classes.dex', 'classes2.dex')]
todos = set(nomes1) | set(classes2)
for n in outros:
    todos |= {c.get_name() for c in DEX(a.get_file(n)).get_classes()}
checar(not any(k.startswith('Lcom/lazersport/dragon/usbserial/') for k in todos), 'sem o plugin USB antigo')

print('CONFERIDO: ' + ('OK' if not falhas else 'FALHOU (%d)' % len(falhas)))
sys.exit(1 if falhas else 0)
