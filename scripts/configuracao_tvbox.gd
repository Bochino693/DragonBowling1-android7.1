extends Control

## CONFIGURAÇÃO DOS BOTÕES DA ZERO DELAY — um botão de cada vez, na
## sequência da máquina. O que for apertado aqui é gravado na TV Box e
## passa a valer no jogo inteiro (ArcadeControls).
##
## A placa é aceita do jeito que o Android entregar: botão de joystick ou,
## em placas genéricas no modo teclado, tecla. A linha "SINAL RECEBIDO"
## mostra na hora o que chegou — é o diagnóstico da placa.
## Se ninguém apertar nada por 20 segundos, volta ao menu sem mudar nada.

const MENU := "res://scene/Main Menu.tscn"
const FONTE := "res://fonts/painel_arcade.ttf"
const ESPERA_MAXIMA_MS := 20000
## Depois dos botões obrigatórios, SELECT e R2 são pulados sozinhos.
## O SELECT (botão de configuração) FECHA esta tela sem mudar nada — menos
## no passo em que ele mesmo está sendo gravado.
const PULAR_OPCIONAL_MS := 4000

var _passo := 0
var _botoes = {}
var _segurando := ""
var _ultimo_toque_ms := 0
var _terminado := false

var _pedido: Label
var _dica: Label
var _sinal: Label
var _linhas: Array = []
var _rodape: Label


func _ready() -> void:
	Tela.cobrir(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fonte = load(FONTE) if ResourceLoader.exists(FONTE) else null

	var fundo := ColorRect.new()
	fundo.color = Color(0.015, 0.025, 0.05)
	Tela.cobrir_auto(fundo)
	add_child(fundo)

	_rotulo(fonte, "CONFIGURAR BOTÕES DA PLACA", Vector2(0, 120), 44, Color(0.55, 0.92, 1.0))
	_pedido = _rotulo(fonte, "", Vector2(0, 250), 64, Color(1.0, 0.86, 0.2))
	_dica = _rotulo(fonte, "APERTE O BOTÃO DA MÁQUINA", Vector2(0, 350), 30, Color(1, 1, 1, 0.75))
	_sinal = _rotulo(fonte, "SINAL RECEBIDO: nenhum ainda", Vector2(0, 410), 26, Color(0.55, 0.92, 1.0, 0.8))

	var y := 500.0
	for item in ArcadeControls.SEQUENCIA:
		_linhas.append(_rotulo(fonte, "", Vector2(0, y), 32, Color(1, 1, 1, 0.55)))
		y += 78.0

	_rodape = _rotulo(fonte, "", Vector2(0, 1380), 24, Color(1, 1, 1, 0.5))
	_medidor_de_tela(fonte)
	_ultimo_toque_ms = Time.get_ticks_msec()
	_atualizar()


## MEDIDOR DA TELA CHEIA. A moldura verde fica EXATAMENTE na borda da
## imagem do jogo. Se na TV aparecer preto POR FORA da moldura, a borda
## vem da TV Box (ajuste de posição/zoom da tela) ou da TV, não do jogo.
## A linha de baixo mostra o tamanho que o Android entrega ao jogo e o da
## tela inteira: iguais = o jogo já ocupa tudo o que o Android deixa.
func _medidor_de_tela(fonte: Font) -> void:
	var cor := Color(0.2, 1.0, 0.35)
	var g := 6.0
	var t: Vector2 = Tela.TAMANHO
	for r in [Rect2(0, 0, t.x, g), Rect2(0, t.y - g, t.x, g), Rect2(0, 0, g, t.y), Rect2(t.x - g, 0, g, t.y)]:
		var faixa := ColorRect.new()
		faixa.color = cor
		faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		faixa.rect_position = r.position
		faixa.rect_size = r.size
		add_child(faixa)
	var area: Rect2 = OS.get_window_safe_area()
	var texto = "TELA: JOGO %dx%d  ·  ANDROID %dx%d" % [OS.window_size.x, OS.window_size.y, area.size.x, area.size.y]
	_rotulo(fonte, texto, Vector2(0, 1440), 22, Color(0.55, 1.0, 0.65, 0.85))


func _rotulo(fonte: Font, texto: String, pos: Vector2, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.rect_position = pos
	l.rect_size = Vector2(Tela.TAMANHO.x, tamanho * 1.6)
	l.align = Label.ALIGN_CENTER
	l.valign = Label.VALIGN_CENTER
	if fonte != null:
		Compat.fonte(l, fonte)
	Compat.tamanho(l, tamanho)
	l.add_color_override("font_color", cor)
	l.add_color_override("font_outline_modulate", Color.black)
	Compat.contorno(l, 8)
	add_child(l)
	return l


func _atualizar() -> void:
	var total = ArcadeControls.SEQUENCIA.size()
	if _passo < total:
		_pedido.text = str(ArcadeControls.SEQUENCIA[_passo][1]).get_slice("  ·  ", 0)
		if _passo >= ArcadeControls.OBRIGATORIOS:
			var falta: int = max(0, int(ceil((PULAR_OPCIONAL_MS - (Time.get_ticks_msec() - _ultimo_toque_ms)) / 1000.0)))
			_dica.text = "APERTE, OU AGUARDE %d s PARA PULAR" % falta
	for i in total:
		var acao: String = ArcadeControls.SEQUENCIA[i][0]
		var nome: String = ArcadeControls.SEQUENCIA[i][1]
		var linha = _linhas[i]
		if _botoes.has(acao):
			linha.text = "✔  %s   →   %s" % [nome, ArcadeControls.texto_do_codigo(_botoes[acao])]
			linha.add_color_override("font_color", Color(0.35, 1.0, 0.55))
		elif i == _passo:
			linha.text = "▶  %s" % nome
			linha.add_color_override("font_color", Color(1.0, 0.86, 0.2))
		else:
			linha.text = "%s   (atual: %s)" % [nome, ArcadeControls.texto_de(acao)]
			linha.add_color_override("font_color", Color(1, 1, 1, 0.45))
	var restante: int = max(0, int(ceil((ESPERA_MAXIMA_MS - (Time.get_ticks_msec() - _ultimo_toque_ms)) / 1000.0)))
	_rodape.text = "SEM TOQUE, VOLTA AO MENU SEM ALTERAR EM %d s" % restante


func _process(_delta: float) -> void:
	if _terminado:
		return
	if _passo >= ArcadeControls.OBRIGATORIOS and _segurando == "" \
			and Time.get_ticks_msec() - _ultimo_toque_ms > PULAR_OPCIONAL_MS:
		_concluir()
		return
	if Time.get_ticks_msec() - _ultimo_toque_ms > ESPERA_MAXIMA_MS:
		_terminado = true
		get_tree().call_deferred("change_scene", MENU)
		return
	_atualizar()


func _input(event: InputEvent) -> void:
	# Mantém em dia a proteção de clique (esta tela segura o evento para si).
	ArcadeControls.eh_da_placa(event)
	get_viewport().set_input_as_handled()
	if _terminado or event.is_echo():
		return
	var codigo = ArcadeControls.codigo_do_evento(event)
	if codigo == "":
		return
	if not event.is_pressed():
		if codigo == _segurando:
			_segurando = ""
		return
	# SELECT fecha a configuração sem mudar nada (menos no passo do próprio
	# SELECT, em que o aperto é o que está sendo gravado).
	var passo_atual = ArcadeControls.SEQUENCIA[_passo][0] if _passo < ArcadeControls.SEQUENCIA.size() else ""
	if passo_atual != "input_teste" and _segurando == "" and not codigo in _botoes.values() \
			and ArcadeControls.eh_config(event):
		_terminado = true
		_pedido.text = "FECHADO"
		_dica.text = "NADA FOI ALTERADO"
		get_tree().call_deferred("change_scene", MENU)
		return
	_ultimo_toque_ms = Time.get_ticks_msec()
	var aparelho = Input.get_joy_name(event.device) if event is InputEventJoypadButton else "placa no modo teclado"
	_sinal.text = "SINAL RECEBIDO: %s  ·  %s" % [ArcadeControls.texto_do_codigo(codigo), aparelho]
	if _segurando != "":
		return
	if codigo in _botoes.values():
		_dica.text = "ESTE BOTÃO JÁ FOI USADO — APERTE OUTRO"
		return
	_segurando = codigo
	_botoes[ArcadeControls.SEQUENCIA[_passo][0]] = codigo
	_passo += 1
	_dica.text = "APERTE O BOTÃO DA MÁQUINA"
	_atualizar()
	if _passo >= ArcadeControls.SEQUENCIA.size():
		_concluir()


func _concluir() -> void:
	_terminado = true
	ArcadeControls.gravar(_botoes)
	_pedido.text = "PRONTO!"
	_dica.text = "GRAVADO. PARA REFAZER: APERTE SELECT NA ABERTURA OU NO MENU"
	yield(get_tree().create_timer(1.6), "timeout")
	get_tree().change_scene(MENU)
