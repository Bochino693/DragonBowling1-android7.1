extends Node

## TUDO PRONTO ANTES DA PRIMEIRA IMAGEM DO JOGO.
##
## Roda uma vez, quando o aplicativo abre, enquanto a TV Box ainda mostra a
## imagem de inicialização (o Godot só troca essa imagem pela primeira
## imagem do jogo depois que os autoloads e a abertura estão montados): o
## que demora acontece aqui, parado, e não no meio de uma animação.
##
## 1. CARREGA E GUARDA (GameConfig.precarregados) o menu, a pista, os sons,
##    a máscara e o brilho (shader) da pista. Antes a abertura e o menu os
##    carregavam aos pedaços enquanto animavam - na Mali-450, cada imagem
##    grande carregada era um tranco na tela.
## 2. DESENHA UMA VEZ CADA LETRA de cada fonte do jogo (fonte + tamanho +
##    contorno), numa folha que nunca aparece. No Godot 3 cada letra nova é
##    desenhada na hora em que aparece e a imagem de letras inteira (até
##    1024 x 1024) vai de novo para a placa de vídeo: "STRIKE!", "PRA
##    FORA!", o placar e o resultado travavam a TV Box na primeira vez.
##    Antes isso era feito no menu, uma letra por quadro - o menu ficava
##    engasgando por alguns segundos depois de ligar.
##
## A lista de letras sai do medidor (.teste/medir.gd com LETRAS=1): cada
## texto que aparece em cada tela, com o tamanho e o contorno dele. Letra
## que não estiver aqui ainda aparece certa - só é preparada na hora.

const ARCADE := "res://fonts/arcade_impact.ttf"
const PAINEL := "res://fonts/painel_arcade.ttf"
const TEXTO := "res://fonts/padrao_opensans.ttf"

const RECURSOS := [
	"res://scene/Main Menu.tscn",
	"res://scene/game.tscn",
	"res://scripts/demo.gd",
	"res://sprites/logoofi.png",
	"res://sprites/pista_mascara.png",
	"res://shaders/brilho_pista.shader",
	"res://songs/pinos_queda.wav", "res://songs/song_ini.wav", "res://songs/song-1.ogg",
	"res://songs/end-game.wav", "res://songs/coin.wav", "res://songs/erro.wav",
	"res://songs/spare.wav", "res://songs/strike-1.wav", "res://songs/strike-2.wav",
	"res://songs/strike-3.wav", "res://songs/bola-roll_.wav",
]

const DIGITOS := "0123456789"

## [fonte, tamanho, contorno (o do Godot 4: espessura total), texto]
const LETRAS := [
	# abertura (o contorno do GAMES é ajustado em _contorno_do_games)
	[ARCADE, 120, 22, "GAMES"],
	# avisos da jogada e do round
	[ARCADE, 108, 14, "STRIKE!"],
	[ARCADE, 88, 14, "PRA FORA! SPARE! ACERTO!"],
	[ARCADE, 78, 14, "PLAYER ROUND • " + DIGITOS],
	# fim de jogo
	[ARCADE, 52, 14, "RESULTADO FINAL"],
	[ARCADE, 48, 14, "RESULTADO FINAL PLAYER 12 VENCEU! EMPATE ENTRE NOVO RECORDE"],
	[ARCADE, 48, 10, "FIM DE JOGO"],
	[ARCADE, 46, 14, "🤝🏆 EMPATE ENTRE PLAYERS PLAYER 12 VENCEU! NOVO RECORDE"],
	# modal de jogadores, placar e fim de jogo
	[PAINEL, 82, 14, "1 PLAYER 2 PLAYERS"],
	[PAINEL, 54, 8, DIGITOS],
	[PAINEL, 48, 8, DIGITOS],
	[PAINEL, 44, 6, DIGITOS],
	[PAINEL, 42, 6, DIGITOS],
	[PAINEL, 40, 0, "🎳"],
	[PAINEL, 30, 8, "PLAY"],
	[PAINEL, 27, 6, " /|ABDEILNOPRSUY" + DIGITOS],
	[PAINEL, 25, 8, " CDEGIJLMNOS◆"],
	[PAINEL, 25, 6, " %.:ACDEFIKLMNOPRSTUÉÊ" + DIGITOS],
	[PAINEL, 24, 6, " :ACDEIKLMNOPRSTYÇ•" + DIGITOS],
	[PAINEL, 22, 6, " !.ACDEFILMNOPRSTYacdegilnoprsuyº×✅🎮" + DIGITOS],
	[PAINEL, 20, 4, DIGITOS],
	[PAINEL, 18, 6, " AEILOPRTVY" + DIGITOS],
	[PAINEL, 18, 4, " /AEINRSTVadegijlmoprstuvz▼" + DIGITOS],
	[PAINEL, 17, 6, " ADIMNOPS◆"],
	[PAINEL, 17, 4, " ACDEMOPSÉÍ"],
	[PAINEL, 15, 4, " ACDFKMORÃÇ—"],
	[PAINEL, 14, 4, " ABCDELNORSTUÍ"],
	[PAINEL, 13, 4, " 12AELPRVYZ•★"],
	# placar, aviso de inatividade e avisos do menu
	[TEXTO, 44, 6, "🎳"],
	[TEXTO, 34, 6, " ?AEGLMTUÉÍ👀"],
	[TEXTO, 30, 6, " :ADEMNORT" + DIGITOS],
	[TEXTO, 30, 0, " .ADEGIMNORST🎳🏆"],
	[TEXTO, 26, 6, "SV"],
	[TEXTO, 24, 6, DIGITOS],
	[TEXTO, 24, 4, " ARSTacdegijnoprtu"],
	[TEXTO, 16, 4, " ADLNORTU"],
	[TEXTO, 15, 4, " ABDENORSU"],
]


func _ready() -> void:
	var inicio = OS.get_ticks_msec()
	_carregar()
	var meio = OS.get_ticks_msec()
	_aquecer_letras()
	print("PREPARO: recursos %d ms, letras %d ms" % [meio - inicio, OS.get_ticks_msec() - meio])


func _carregar() -> void:
	for caminho in RECURSOS:
		if GameConfig.precarregados.has(caminho) or not ResourceLoader.exists(caminho):
			continue
		var r = load(caminho)
		if r != null:
			GameConfig.precarregados[caminho] = r


func _aquecer_letras() -> void:
	var folha = VisualServer.canvas_item_create()
	for item in LETRAS:
		var dados = Compat.dados_da_fonte(item[0])
		if dados == null:
			continue
		var contorno: int = item[2]
		if item[3] == "GAMES":
			contorno = _contorno_do_games(item[1], contorno)
		var f: DynamicFont = Compat.fonte_para(dados, item[1], contorno)
		# Contorno de todas as letras, depois as letras (o mesmo que um
		# Label faz): cada imagem de letras vai uma vez para a placa.
		f.draw(folha, Vector2(0, f.get_ascent()), item[3], Color(1, 1, 1), -1, Color(0, 0, 0))
		VisualServer.canvas_item_clear(folha)
	VisualServer.free_rid(folha)


## O mesmo ajuste da abertura: com a fonte no limite de tamanho, o contorno
## encolhe na mesma proporção (ver abertura.gd, _criar_letras).
func _contorno_do_games(tamanho: int, contorno: int) -> int:
	var k = float(tamanho) / float(Compat.tamanho_efetivo(tamanho))
	return int(round(contorno / k))
