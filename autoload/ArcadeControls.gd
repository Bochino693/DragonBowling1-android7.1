extends Node

## OS COMANDOS DO JOGO VÊM DA PLACA ZERO DELAY.
##
## Sem mapeamento gravado, vale o Input Map do projeto: as teclas da Zero
## Delay no modo teclado (1/Espaço = STR, A = quadrado, S = X, D = bolinha,
## F = triângulo, G = R1, 5 = SELECT) e os índices de joystick do Godot 3
## (quadrado 2, X 0, bolinha 1, triângulo 3, R1 5, R2 7, SELECT 10,
## START 11). As ações "ui_*" do Godot (ENTER, setas, botão 0) são desligadas.
##
## AS TECLAS DA PLACA (build 8):
##   START ........ começa / escolhe 1 ou 2 jogadores
##   QUADRADO ..... jogada esquerda
##   X ............ meio esquerdo
##   BOLINHA ...... strike (centro)
##   TRIÂNGULO .... meio direito
##   R1 e R2 ...... jogadas extremas
##   SELECT ....... CONFIGURAÇÃO — e mais nada abre a configuração
## A configuração abre pelo SELECT na abertura, no menu e na demo (nunca no
## meio de uma partida) e, dentro dela, o SELECT fecha sem mudar nada.
##
## POR QUE O R2 SAIU DA CONFIGURAÇÃO. Até a build 6 o R2 da placa nem
## chegava ao jogo (o mapa padrão do Android o descartava). A build 7 passou
## a entregar o R2 — e ele caiu direto na configuração, que desde a build 3
## estava ligada a ele: a jogada da bola abria a configuração na abertura.
##
## MAPEAMENTO GRAVADO NA TV BOX. Na tela de CONFIGURAÇÃO o jogo pede um
## botão de cada vez, na sequência, e grava em user://controles_zero_delay.cfg.
## A placa vale do jeito que ela se apresentar ao Android: como joystick
## (botão) ou, no modo teclado, como tecla.

const ARQUIVO := "user://controles_zero_delay.cfg"
## Formato do arquivo gravado. Até a build 7 o passo "SELECT" era o crédito
## e o último passo (R2) era a configuração; da build 8 em diante o SELECT
## é a configuração e o último passo é o R2 (jogada extrema).
const VERSAO_DO_ARQUIVO := 2

## A sequência do assistente: ação, nome na tela.
const SEQUENCIA: Array = [
	["input_start", "STR  ·  START"],
	["input_z", "QUADRADO  ·  JOGADA ESQUERDA"],
	["input_x", "X  ·  MEIO ESQUERDO"],
	["input_c", "BOLINHA  ·  STRIKE (CENTRO)"],
	["input_v", "TRIÂNGULO  ·  MEIO DIREITO"],
	["input_b", "R1  ·  JOGADAS EXTREMAS"],
	["input_teste", "SELECT  ·  CONFIGURAÇÃO"],
	["input_b2", "R2  ·  JOGADAS EXTREMAS"],
]
## Os primeiros são obrigatórios; SELECT e R2 podem ser pulados (valem os
## de fábrica).
const OBRIGATORIOS := 6

const JOGADAS := {
	"input_z": "Z",
	"input_x": "X",
	"input_c": "C",
	"input_v": "V",
	"input_b": "B",
	"input_b2": "B",
}

const CENA_CONFIGURACAO := "res://scene/configuracao_tvbox.tscn"
const CENA_MENU := "res://scene/Main Menu.tscn"
const CENA_ABERTURA := "res://scene/abertura.tscn"

var mapeamento_gravado := false
## Os botões de fábrica do SELECT (configuração), guardados na partida do
## jogo: voltam sozinhos se um mapeamento gravado deixar a ação vazia.
var _select_de_fabrica: Array = []

## Proteção de clique (ver eh_da_placa).
const INTERVALO_MINIMO_MS := 120
var _abaixados = {}
var _ultimo_clique = {}
var _evento_visto: InputEvent = null
var _veredito_visto := false


## Pedido da demo: o menu abre já perguntando 1 ou 2 jogadores.
var abrir_selecao_de_jogadores := false

## Teclas do controle remoto da TV Box: nunca viram jogada.
const TECLAS_DO_CONTROLE_REMOTO := [
	KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER,
	KEY_ESCAPE, KEY_BACK, KEY_MENU, KEY_VOLUMEUP, KEY_VOLUMEDOWN,
	KEY_VOLUMEMUTE, KEY_HOMEPAGE, KEY_TAB, KEY_SPACE,
]


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_liberar_todos_os_botoes()
	if not Input.is_connected("joy_connection_changed", self, "_on_joy_connection_changed"):
		Input.connect("joy_connection_changed", self, "_on_joy_connection_changed")
	_desligar_acoes_de_interface()
	_select_de_fabrica = InputMap.get_action_list("input_teste").duplicate()
	_carregar()
	_sem_conflito_na_configuracao()


## "VOLTAR" DO ANDROID NÃO FECHA O JOGO.
##
## No Android, um botão de joystick que o jogo não usa vira, por padrão do
## sistema, a tecla VOLTAR. O Godot vem de fábrica fechando o aplicativo
## no VOLTAR: `application/config/quit_on_go_back=false` (project.godot)
## desliga o fechamento; aqui o pedido é só ignorado.
func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		print("ArcadeControls: VOLTAR do Android ignorado (o jogo não fecha).")


## R1 QUE NÃO CHEGAVA NO JOGO.
##
## No Android o Godot passa todo joystick desconhecido (a Zero Delay é um)
## pelo mapa "Default Android Gamepad", que só conhece A/B/X/Y, L1/R1,
## SELECT/START e L3/R3. Qualquer outro botão (L2/R2 como tecla, GUIDE, C,
## Z, BUTTON_1..16 de placa genérica, direcional como tecla) era JOGADO
## FORA antes de chegar ao script — por isso o R1 não fazia nada, nem dava
## para gravá-lo na configuração.
##
## Aqui cada joystick ganha um mapa COMPLETO: os botões de sempre ficam com
## o mesmo número (nada do que já estava gravado muda) e os que eram
## descartados passam a chegar (GUIDE, MISC, PADDLE...). Esses não têm
## outra função: na partida valem como R1 (tecla_jogada) e no assistente
## podem ser gravados em qualquer passo.
const MAPA_COMPLETO_ANDROID := "leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:a4,righttrigger:a5,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,a:b0,b:b1,x:b2,y:b3,back:b4,guide:b5,start:b6,leftstick:b7,rightstick:b8,leftshoulder:b9,rightshoulder:b10,dpup:b11,dpdown:b12,dpleft:b13,dpright:b14,lefttrigger:b15,righttrigger:b16,misc1:b17,paddle1:b18,misc1:b19,paddle2:b20,paddle3:b21,paddle4:b22,touchpad:b23,misc1:b24,misc1:b25,misc1:b26,misc1:b27,misc1:b28,misc1:b29,misc1:b30,misc1:b31,misc1:b32,misc1:b33,misc1:b34,misc1:b35,platform:Android"

func _liberar_todos_os_botoes() -> void:
	if OS.get_name() != "Android":
		return
	for id in Input.get_connected_joypads():
		_liberar_botoes_do_joystick(id)


func _liberar_botoes_do_joystick(id: int) -> void:
	var guid = Input.get_joy_guid(id)
	if guid == "" or "," in guid:
		return
	Input.add_joy_mapping("%s,Zero Delay,%s" % [guid, MAPA_COMPLETO_ANDROID], true)


func _on_joy_connection_changed(id: int, conectado: bool) -> void:
	if conectado and OS.get_name() == "Android":
		_liberar_botoes_do_joystick(id)


## As ações "ui_*" vêm de fábrica ligadas a ENTER, espaço, setas e ao
## botão 0 de qualquer joystick. Sem elas, nenhum botão aciona a
## interface por baixo do jogo.
func _desligar_acoes_de_interface() -> void:
	for acao in InputMap.get_actions():
		if String(acao).begins_with("ui_"):
			InputMap.action_erase_events(acao)


## Um código por ação: >= 0 é botão de joystick; "tecla:<código>" é tecla.
func _carregar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) != OK:
		return
	var botoes = {}
	var antigo = int(cfg.get_value("formato", "versao", 1)) < VERSAO_DO_ARQUIVO
	for item in SEQUENCIA:
		var acao: String = item[0]
		if cfg.has_section_key("botoes", acao):
			botoes[acao] = cfg.get_value("botoes", acao)
	if antigo:
		# ARQUIVO ATÉ A BUILD 7: o passo "input_teste" era o R2 (configuração)
		# e o SELECT ficava em "input_credit". O SELECT passa a ser o botão
		# da configuração; o R2 volta a ser jogada (o de fábrica).
		botoes.erase("input_teste")
		botoes.erase("input_b2")
		if cfg.has_section_key("botoes", "input_credit"):
			botoes["input_teste"] = cfg.get_value("botoes", "input_credit")
	if not botoes.empty():
		_aplicar(botoes)
		mapeamento_gravado = true


func gravar(botoes: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("formato", "versao", VERSAO_DO_ARQUIVO)
	for acao in botoes:
		cfg.set_value("botoes", acao, botoes[acao])
	cfg.save(ARQUIVO)
	_aplicar(botoes)
	_sem_conflito_na_configuracao()
	mapeamento_gravado = true


func _aplicar(botoes: Dictionary) -> void:
	for acao in botoes:
		var codigo = botoes[acao]
		if not InputMap.has_action(acao):
			InputMap.add_action(acao, 0.2)
		InputMap.action_erase_events(acao)
		var texto = str(codigo)
		if texto.begins_with("tecla:"):
			var tecla = int(texto.substr(6))
			var ev := InputEventKey.new()
			# Godot 3: a tecla vai pelo código LÓGICO (scancode). No Android o
			# Godot 3 nem sempre preenche o código físico, e aí uma tecla
			# gravada como física nunca bateria.
			ev.scancode = tecla
			InputMap.action_add_event(acao, ev)
		else:
			var ev := InputEventJoypadButton.new()
			ev.device = -1
			ev.button_index = int(texto.trim_prefix("botao:"))
			InputMap.action_add_event(acao, ev)


## NENHUM BOTÃO DE JOGADA ABRE A CONFIGURAÇÃO.
##
## Um botão podia valer ao mesmo tempo como jogada e como configuração (o
## mesmo número gravado em dois passos, ou o de fábrica de um batendo com o
## gravado de outro): apertar a jogada abria a configuração. Aqui a
## configuração perde todo botão que for do START ou de uma jogada. O
## SELECT de fábrica (botão 10 e tecla 5) vale SEMPRE, junto com o gravado
## — menos se ele mesmo tiver sido gravado como jogada.
func _sem_conflito_na_configuracao() -> void:
	for ev in InputMap.get_action_list("input_teste"):
		if _evento_de_outra_acao(ev):
			InputMap.action_erase_event("input_teste", ev)
	for ev in _select_de_fabrica:
		if not _evento_de_outra_acao(ev) and not InputMap.action_has_event("input_teste", ev):
			InputMap.action_add_event("input_teste", ev)


func _evento_de_outra_acao(ev: InputEvent) -> bool:
	for item in SEQUENCIA:
		var acao: String = item[0]
		if acao != "input_teste" and InputMap.has_action(acao) and InputMap.event_is_action(ev, acao):
			return true
	return false


## Código gravável de um evento: "botao:N" (joystick) ou "tecla:N";
## vazio se o evento não é botão nem tecla.
static func codigo_do_evento(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return "botao:%d" % int(event.button_index)
	if event is InputEventKey:
		var k = event as InputEventKey
		var fisica = int(k.scancode) if k.scancode != 0 else int(k.physical_scancode)
		if fisica != 0:
			return "tecla:%d" % fisica
	return ""


static func texto_do_codigo(codigo: String) -> String:
	if codigo.begins_with("tecla:"):
		return "TECLA %s" % OS.get_scancode_string(int(codigo.substr(6)))
	return "BOTÃO %d" % int(codigo.trim_prefix("botao:"))


func texto_de(acao: String) -> String:
	var partes: PoolStringArray = []
	for ev in InputMap.get_action_list(acao):
		if ev is InputEventJoypadButton:
			partes.append("BOTÃO %d" % int(ev.button_index))
		elif ev is InputEventKey:
			partes.append("TECLA %s" % OS.get_scancode_string(ev.scancode if ev.scancode != 0 else ev.physical_scancode))
	return " / ".join(partes) if not partes.empty() else "-"


## É um botão da placa? A Zero Delay chega como joystick OU, no modo
## teclado, como teclas (1 = STR, A S D F G = jogadas, 5, 9...). Tecla só
## vale se estiver ligada a uma ação do jogo: as do controle remoto (setas,
## OK, voltar) não estão, então não fazem nada.
##
## CADA APERTO É UM CLIQUE. Um botão só vale de novo depois de ser SOLTO:
## segurar o START (ou qualquer botão/sensor) não repete o comando — nem a
## repetição automática do teclado, nem uma placa que reenvia o "apertado"
## sem soltar. Um repique do contato (apertar de novo em menos de
## INTERVALO_MINIMO_MS) também não conta.
func eh_da_placa(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if not (event is InputEventJoypadButton or event is InputEventKey):
		return false
	# O mesmo evento passa por vários nós (menu, jogo, este): decide uma vez.
	if event == _evento_visto:
		return _veredito_visto
	var codigo = codigo_do_evento(event)
	var valido := true
	if event.is_pressed():
		var agora = Time.get_ticks_msec()
		if _abaixados.has(codigo):
			valido = false   # ainda segurado: não é um clique novo
		elif agora - int(_ultimo_clique.get(codigo, -100000)) < INTERVALO_MINIMO_MS:
			valido = false   # repique do contato
		_abaixados[codigo] = true
		if valido:
			_ultimo_clique[codigo] = agora
	else:
		_abaixados.erase(codigo)
	_evento_visto = event
	_veredito_visto = valido
	return valido


## A tecla/botão apertado não faz nada no jogo (serve para avisar o
## operador de que a configuração precisa ser feita).
func sem_funcao(event: InputEvent) -> bool:
	if not eh_da_placa(event) or not event.is_pressed():
		return false
	for item in SEQUENCIA:
		if event.is_action(item[0]):
			return false
	return true


func eh_start(event: InputEvent) -> bool:
	return eh_da_placa(event) and event.is_action_pressed("input_start")


## O SELECT (configuração). Um botão do START ou de jogada nunca conta,
## mesmo que algum mapeamento antigo o tenha posto aqui também.
func eh_config(event: InputEvent) -> bool:
	if not (eh_da_placa(event) and event.is_action_pressed("input_teste")):
		return false
	if event.is_action("input_start"):
		return false
	for acao in JOGADAS:
		if event.is_action(acao):
			return false
	return true


func tecla_jogada(event: InputEvent) -> String:
	if not eh_da_placa(event):
		return ""
	for acao in JOGADAS:
		if event.is_action_pressed(acao):
			return JOGADAS[acao]
	# R1 QUALQUER QUE SEJA O NÚMERO: na partida, um botão da placa que não
	# é START, crédito, teste nem outra jogada é a jogada lateral (B).
	if event.is_pressed() and _sem_acao_da_placa(event):
		return "B"
	return ""


func _sem_acao_da_placa(event: InputEvent) -> bool:
	if event is InputEventKey:
		var k = event as InputEventKey
		var codigo = k.scancode if k.scancode != 0 else k.physical_scancode
		if codigo == 0 or codigo in TECLAS_DO_CONTROLE_REMOTO:
			return false
	elif not event is InputEventJoypadButton:
		return false
	for item in SEQUENCIA:
		if event.is_action(item[0]):
			return false
	return true


## Qualquer botão da placa conta como "alguém está jogando".
func eh_atividade(event: InputEvent) -> bool:
	return eh_da_placa(event) and event.is_pressed()


# ----------------------------------------------------- abertura
## SELECT NA ABERTURA: a abertura não tem controle próprio; daqui já vai
## direto para a configuração (menu e demo tratam o SELECT neles; a partida
## ignora). Nenhum outro botão abre a configuração — nem segurar botão.
func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventKey):
		return
	if event.is_echo():
		return
	# Registra aperto/soltura de todo botão, mesmo quando a cena atual não
	# pergunta nada (abertura, transição): senão um botão solto nessa hora
	# ficaria "segurado" e o próximo clique dele seria ignorado.
	eh_da_placa(event)
	if not eh_config(event):
		return
	var atual = get_tree().current_scene
	if atual != null and atual.filename == CENA_ABERTURA:
		get_tree().set_input_as_handled()
		get_tree().call_deferred("change_scene", CENA_CONFIGURACAO)
