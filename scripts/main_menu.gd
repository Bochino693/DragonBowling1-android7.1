extends Node2D

var card_player_1: Panel = null
var card_player_2: Panel = null
var lbl_player_1: Label = null
var lbl_player_2: Label = null


const LED_ATIVO: bool = true
const LED_COM: String = "COM4"
var _led_pronto: bool = false


onready var start_button = $"Button Manager/start_button"

const CENA_DO_JOGO = "res://scene/game.tscn"
## CARREGADOS EM SEGUNDO PLANO enquanto o menu está na tela: na hora do
## START a pista já está pronta na memória e monta sem engasgo.
const PRECARGA := [
	"res://scene/game.tscn",
	"res://songs/pinos_queda.wav", "res://songs/song_ini.wav", "res://songs/song-1.ogg",
	"res://songs/end-game.wav", "res://songs/coin.wav", "res://songs/erro.wav",
	"res://songs/spare.wav", "res://songs/strike-1.wav", "res://songs/strike-2.wav",
	"res://songs/strike-3.wav", "res://songs/bola-roll_.wav",
	"res://fonts/arcade_impact.ttf", "res://fonts/painel_arcade.ttf",
	"res://sprites/pista_mascara.png",
	# (O logo NÃO entra aqui: o menu o carrega na hora, e pedir com load()
	# algo que está na fila de fundo faz a tela esperar a fila inteira.)
]
const SHADER_DA_PISTA := preload("res://shaders/brilho_pista.shader")
var _precarga_pendente: Array = []
const CENA_DEMO = "res://scene/demo.tscn"
const TEMPO_ESPERA = 2.0
const TEMPO_ATE_DEMO = 80.0
const CAMINHO_LOGO = "res://sprites/logoofi.png"
const CENA_TESTE = "res://scene/configuracao_tvbox.tscn"
const ACAO_ENTRAR_TESTE = "input_teste"

const CAMINHO_SOM_COIN = "res://songs/coin.wav"
var som_coin: AudioStream = null
var audio_coin_player: AudioStreamPlayer = null
var lbl_creditos: Label = null


var seletor_jogadores_ativo: bool = false
var pulsos_start: int = 0
var tempo_selecao_jogadores: float = 3.0
var timer_selecao_jogadores: float = 0.0

var layer_selecao_jogadores: CanvasLayer = null
var painel_selecao_jogadores: Panel = null
var txt_titulo_selecao: Label = null
var txt_modo_selecao: Label = null
var txt_instrucao_selecao: Label = null
var txt_timer_selecao: Label = null
var barra_timer_selecao: ColorRect = null


const FONTE_MODAL_1 := "res://fonts/painel_arcade.ttf"
const FONTE_MODAL_2 := "res://fonts/arcade_impact.ttf"
const FONTE_MODAL_3 := "res://fonts/titan.ttf"

var fonte_modal_atual: String = FONTE_MODAL_1


# MÚSICA HARD CODED NA MAIN
const CAMINHO_MUSICA = "res://songs/song.ogg"
const OFFSET_INICIAL_MUSICA = 3.0

# SOM DO BOTÃO
const CAMINHO_SOM_BOTAO = "res://songs/coin.wav"
const VOLUME_SOM_BOTAO_DB = -2.0

var pode_iniciar: bool = true
var escala_original: Vector2 = Vector2.ONE
var tween_idle: SceneTreeTween = null

var fundo_sprite: Sprite = null
var fundo_animado: AnimatedSprite = null
var logo_sprite: Sprite = null

var tempo_sem_interacao: float = 0.0
var demo_ativa_transicao: bool = false

var audio_player: AudioStreamPlayer = null
var musica_menu: AudioStream = null

var audio_click_player: AudioStreamPlayer = null
var som_botao: AudioStream = null
var fim_panel_glow: ColorRect
var fim_panel_borda: ColorRect
var fim_linha_topo: ColorRect
var fim_linha_base: ColorRect



func _enter_tree() -> void:
	_forcar_ocultar_cursor()

	_configurar_audio()
	_tocar_musica_menu()


func _ready() -> void:
	_forcar_ocultar_cursor()
	_iniciar_precarga()
	_preparar_modal_escondido()
	
	_configurar_led()
	call_deferred("_enviar_led", "MENU")

	fundo_sprite = _resolver_sprite_fundo()
	fundo_animado = _resolver_sprite_animado_fundo()

	if start_button == null:
		push_error("ERRO: start_button não encontrado em 'Button Manager/start_button'")
		return

	print("Botão encontrado: ", start_button.name)

	_configurar_botao()
	_criar_logo_empresa()

	yield(get_tree(), "idle_frame")

	escala_original = start_button.rect_scale
	_ajustar_layout()
	_iniciar_animacao_logo()
	_iniciar_animacao_idle()
	_resetar_timer_demo()
	# Veio da demo pelo START: já abre a escolha de 1 ou 2 jogadores.
	if ArcadeControls.abrir_selecao_de_jogadores:
		ArcadeControls.abrir_selecao_de_jogadores = false
		_registrar_pulso_start()

	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.is_connected("size_changed", self, "_on_viewport_size_changed"):
		viewport.connect("size_changed", self, "_on_viewport_size_changed")

	# O START da arcade vem exclusivamente da ação input_start.
	if start_button.is_connected("pressed", self, "_on_start_button_pressed"):
		start_button.disconnect("pressed", self, "_on_start_button_pressed")
	start_button.focus_mode = Control.FOCUS_NONE


func _iniciar_precarga() -> void:
	for caminho in PRECARGA:
		if GameConfig.precarregados.has(caminho) or not ResourceLoader.exists(caminho):
			continue
		if Compat.pedir_carga(caminho) == OK:
			_precarga_pendente.append(caminho)


## Compila o shader do brilho da pista já no menu, num pontinho quase
## invisível no canto: compilar na primeira imagem da pista engasgava.
## A máscara vem da carga em segundo plano (pedir com load() enquanto ela
## ainda carregava fazia a tela esperar a pista inteira carregar).
func _aquecer_shader_da_pista(mascara: Texture) -> void:
	if mascara == null:
		return
	var ponto := Sprite.new()
	ponto.texture = mascara
	ponto.centered = false
	ponto.scale = Vector2(0.004, 0.004)
	ponto.modulate = Color(1, 1, 1, 0.02)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_DA_PISTA
	mat.set_shader_param("mascara", mascara)
	ponto.material = mat
	add_child(ponto)


## O MODAL DE JOGADORES E AS LETRAS DA PARTIDA FICAM PRONTOS NO MENU.
##
## Montar o modal na hora do START (40 e tantos painéis) e desenhar pela
## primeira vez as letras grandes com contorno ("1 PLAYER", "STRIKE!",
## "ROUND 2"...) era o que travava a TV Box na hora H. O modal é montado
## escondido logo que o menu assenta, e cada letra de cada tamanho é
## desenhada uma vez, quase invisível, UMA POR QUADRO, enquanto o menu está
## parado — sem nenhum quadro pesado. O cache fica na fonte (GameConfig
## guarda as fontes durante o jogo todo).
const ESPERA_PARA_PREPARAR := 0.8
const LETRAS_DA_PARTIDA := [
	# [tamanho, contorno, texto] da fonte arcade — as medidas de game.gd
	[108, 14, "STRIKE!"],
	[88, 14, "ACERTO!SPAREPRAFO"],
	[78, 14, "PLAYER•ROUND0123456789"],
	[52, 14, "RESULTADOFINALVENCEU!"],
	[48, 14, "RESULTADOFINALVENCEU!EMPATPLYR12"],
	[46, 14, "NOVORECORDEVENCEU!EMPAT12"],
]

func _preparar_modal_escondido() -> void:
	var _g3_estado = null
	yield(get_tree().create_timer(ESPERA_PARA_PREPARAR), "timeout")
	if not is_inside_tree() or not pode_iniciar or seletor_jogadores_ativo or layer_selecao_jogadores != null:
		return
	_criar_overlay_selecao_jogadores()
	layer_selecao_jogadores.visible = false
	# As letras dos dois estados do modal (1 e 2 jogadores).
	var combos: Array = []
	for pulsos in [1, 2]:
		pulsos_start = pulsos
		timer_selecao_jogadores = tempo_selecao_jogadores
		_atualizar_texto_selecao_jogadores()
		combos.append_array(_combos_de_letras(layer_selecao_jogadores))
	pulsos_start = 0
	var arcade = load("res://fonts/arcade_impact.ttf") if ResourceLoader.exists("res://fonts/arcade_impact.ttf") else null
	if arcade != null:
		for item in LETRAS_DA_PARTIDA:
			combos.append([arcade, item[0], item[1], item[2]])
	_g3_estado = _aquecer_letras(combos)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")


func _combos_de_letras(raiz: Node) -> Array:
	var r: Array = []
	for l in Compat.filhos_do_tipo(raiz, "Label"):
		var lbl = l as Label
		var e = Compat.estilo_de(lbl)
		r.append([e[0], e[1], e[2], lbl.text])
	return r


func _aquecer_letras(combos: Array) -> void:
	var camada := CanvasLayer.new()
	camada.layer = -50
	add_child(camada)
	var sonda := Label.new()
	sonda.rect_position = Vector2(20, 20)
	sonda.modulate.a = 0.01
	sonda.add_color_override("font_outline_modulate", Color(0.01, 0.01, 0.02))
	sonda.add_color_override("font_color_shadow", Color(0, 0, 0, 0.70))
	sonda.add_constant_override("shadow_offset_x", 5)
	sonda.add_constant_override("shadow_offset_y", 5)
	camada.add_child(sonda)
	var feitos = {}
	for c in combos:
		var fonte = c[0]
		if fonte == null:
			continue
		Compat.fonte(sonda, fonte)
		Compat.tamanho(sonda, int(c[1]))
		Compat.contorno(sonda, int(c[2]))
		for ch in String(c[3]):
			if ch == " ":
				continue
			var chave = "%d|%d|%d|%s" % [fonte.get_instance_id(), int(c[1]), int(c[2]), ch]
			if feitos.has(chave):
				continue
			feitos[chave] = true
			sonda.text = ch
			yield(get_tree(), "idle_frame")
			if not is_inside_tree() or not pode_iniciar:
				if is_instance_valid(camada):
					camada.queue_free()
				return
	camada.queue_free()


func _mostrar_overlay_selecao() -> void:
	if layer_selecao_jogadores == null or not is_instance_valid(layer_selecao_jogadores):
		_criar_overlay_selecao_jogadores()
	layer_selecao_jogadores.visible = true


func _colher_precarga() -> void:
	for i in range(_precarga_pendente.size() - 1, -1, -1):
		var caminho: String = _precarga_pendente[i]
		var estado = Compat.estado_carga(caminho)
		if estado == Compat.CARGA_EM_ANDAMENTO:
			continue
		if estado == Compat.CARGA_PRONTA:
			GameConfig.precarregados[caminho] = Compat.pegar_carga(caminho)
			if caminho == "res://sprites/pista_mascara.png":
				_aquecer_shader_da_pista(GameConfig.precarregados[caminho] as Texture)
		_precarga_pendente.remove(i)


func _process(delta: float) -> void:
	if not _precarga_pendente.empty():
		_colher_precarga()
	if seletor_jogadores_ativo:
		timer_selecao_jogadores -= delta
		_atualizar_texto_selecao_jogadores()

	if seletor_jogadores_ativo and timer_selecao_jogadores <= 0.0 and pulsos_start < 2:
		_confirmar_quantidade_jogadores()
	
	if not pode_iniciar:
		return

	if demo_ativa_transicao:
		return

	tempo_sem_interacao += delta

	if tempo_sem_interacao >= TEMPO_ATE_DEMO:
		print("TEMPO DE INATIVIDADE ATINGIDO. INDO PARA DEMO...")
		_iniciar_demo()



func _registrar_pulso_start() -> void:
	if not pode_iniciar:
		return

	_resetar_timer_demo()

	if not seletor_jogadores_ativo:
		seletor_jogadores_ativo = true
		pulsos_start = 1
		timer_selecao_jogadores = tempo_selecao_jogadores
		_enviar_led("BLUE")
		_tocar_som_coin()
		_mostrar_overlay_selecao()
		_atualizar_texto_selecao_jogadores()
		return

	if pulsos_start < 2:
		pulsos_start = 2
		timer_selecao_jogadores = 0.35
		_enviar_led("RED")
		_tocar_som_coin()
		_atualizar_texto_selecao_jogadores()

		if card_player_2 != null:
			var tw = create_tween()
			tw.tween_property(card_player_2, "rect_scale", Vector2(1.22, 1.22), 0.16)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(card_player_2, "rect_scale", Vector2(1.08, 1.08), 0.18)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		yield(get_tree().create_timer(0.35), "timeout")

		if seletor_jogadores_ativo and pulsos_start >= 2:
			_confirmar_quantidade_jogadores()



func _criar_overlay_selecao_jogadores() -> void:
	if layer_selecao_jogadores != null:
		layer_selecao_jogadores.queue_free()

	layer_selecao_jogadores = CanvasLayer.new()
	layer_selecao_jogadores.layer = 1000
	add_child(layer_selecao_jogadores)

	var tela: Vector2 = Tela.retangulo().size

	var fundo := TextureRect.new()
	if ResourceLoader.exists("res://sprites/bg_players_select.png"):
		fundo.texture = load("res://sprites/bg_players_select.png")
	fundo.expand = true
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	Tela.cobrir_auto(fundo)
	fundo.modulate = Color(1, 1, 1, 0.82)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_selecao_jogadores.add_child(fundo)

	var dark := ColorRect.new()
	dark.color = Color(0.0, 0.0, 0.0, 0.48)
	Tela.cobrir_auto(dark)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_selecao_jogadores.add_child(dark)

	var faixa := ColorRect.new()
	faixa.color = Color(0.0, 0.70, 1.0, 0.07)
	faixa.rect_position = Vector2(0, tela.y * 0.5 - 330)
	faixa.rect_size = Vector2(tela.x, 660)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_selecao_jogadores.add_child(faixa)

	var glow_modal := Panel.new()
	glow_modal.rect_size = Vector2(900, 760)
	glow_modal.rect_position = Vector2(
		(tela.x - glow_modal.rect_size.x) * 0.5,
		(tela.y - glow_modal.rect_size.y) * 0.5
	)
	glow_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_selecao_jogadores.add_child(glow_modal)

	var glow_s := StyleBoxFlat.new()
	glow_s.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	glow_s.border_color = Color(0.0, 0.78, 1.0, 0.65)
	glow_s.border_width_left = 4
	glow_s.border_width_top = 4
	glow_s.border_width_right = 4
	glow_s.border_width_bottom = 4
	glow_s.corner_radius_top_left = 52
	glow_s.corner_radius_top_right = 52
	glow_s.corner_radius_bottom_left = 52
	glow_s.corner_radius_bottom_right = 52
	glow_s.shadow_color = Color(0.0, 0.78, 1.0, 0.62)
	glow_s.shadow_size = 58
	glow_modal.add_stylebox_override("panel", glow_s)

	painel_selecao_jogadores = Panel.new()
	painel_selecao_jogadores.rect_size = Vector2(820, 680)
	painel_selecao_jogadores.rect_position = Vector2(
		(tela.x - painel_selecao_jogadores.rect_size.x) * 0.5,
		(tela.y - painel_selecao_jogadores.rect_size.y) * 0.5
	)
	painel_selecao_jogadores.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_selecao_jogadores.add_child(painel_selecao_jogadores)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.018, 0.055, 0.97)
	style.border_color = Color(0.18, 0.82, 1.0, 1.0)
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	style.corner_radius_top_left = 40
	style.corner_radius_top_right = 40
	style.corner_radius_bottom_left = 40
	style.corner_radius_bottom_right = 40
	style.shadow_color = Color(0.10, 0.55, 1.0, 0.55)
	style.shadow_size = 36
	painel_selecao_jogadores.add_stylebox_override("panel", style)

	var brilho_topo := ColorRect.new()
	brilho_topo.rect_position = Vector2(28, 18)
	brilho_topo.rect_size = Vector2(764, 22)
	brilho_topo.color = Color(0.30, 0.85, 1.0, 0.18)
	brilho_topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_selecao_jogadores.add_child(brilho_topo)

	var linha_topo := ColorRect.new()
	linha_topo.rect_position = Vector2(60, 58)
	linha_topo.rect_size = Vector2(700, 3)
	linha_topo.color = Color(0.18, 0.82, 1.0, 0.55)
	linha_topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_selecao_jogadores.add_child(linha_topo)

	txt_titulo_selecao = Label.new()
	txt_titulo_selecao.rect_position = Vector2(30, 18)
	txt_titulo_selecao.rect_size = Vector2(760, 52)
	txt_titulo_selecao.text = "◆  SELECIONE O MODO DE JOGO  ◆"
	txt_titulo_selecao.align = Label.ALIGN_CENTER
	txt_titulo_selecao.valign = Label.VALIGN_CENTER
	Compat.tamanho(txt_titulo_selecao, 27)
	txt_titulo_selecao.add_color_override("font_color", Color(0.55, 0.92, 1.0))
	txt_titulo_selecao.add_color_override("font_outline_modulate", Color.black)
	Compat.contorno(txt_titulo_selecao, 7)
	painel_selecao_jogadores.add_child(txt_titulo_selecao)

	var bloco_modo := Panel.new()
	bloco_modo.rect_position = Vector2(40, 104)
	bloco_modo.rect_size = Vector2(740, 158)
	bloco_modo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bloco_s := StyleBoxFlat.new()
	bloco_s.bg_color = Color(0.005, 0.012, 0.040, 0.95)
	bloco_s.border_color = Color(1.0, 0.82, 0.14, 0.78)
	bloco_s.border_width_left = 3
	bloco_s.border_width_top = 3
	bloco_s.border_width_right = 3
	bloco_s.border_width_bottom = 3
	bloco_s.corner_radius_top_left = 24
	bloco_s.corner_radius_top_right = 24
	bloco_s.corner_radius_bottom_left = 24
	bloco_s.corner_radius_bottom_right = 24
	bloco_s.shadow_color = Color(1.0, 0.82, 0.14, 0.30)
	bloco_s.shadow_size = 18
	bloco_modo.add_stylebox_override("panel", bloco_s)
	painel_selecao_jogadores.add_child(bloco_modo)

	txt_modo_selecao = Label.new()
	txt_modo_selecao.rect_position = Vector2(0, 0)
	txt_modo_selecao.rect_size = Vector2(740, 158)
	txt_modo_selecao.align = Label.ALIGN_CENTER
	txt_modo_selecao.valign = Label.VALIGN_CENTER
	Compat.tamanho(txt_modo_selecao, 88)
	txt_modo_selecao.add_color_override("font_color", Color(1.0, 0.88, 0.18))
	txt_modo_selecao.add_color_override("font_outline_modulate", Color.black)
	Compat.contorno(txt_modo_selecao, 14)
	bloco_modo.add_child(txt_modo_selecao)

	var linha_meio := ColorRect.new()
	linha_meio.rect_position = Vector2(60, 300)
	linha_meio.rect_size = Vector2(700, 2)
	linha_meio.color = Color(0.18, 0.82, 1.0, 0.30)
	linha_meio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_selecao_jogadores.add_child(linha_meio)

	var bloco_instrucao := Control.new()
	bloco_instrucao.rect_position = Vector2(54, 328)
	bloco_instrucao.rect_size = Vector2(712, 124)
	bloco_instrucao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_selecao_jogadores.add_child(bloco_instrucao)

	var card_w := 324.0
	var card_h := 112.0
	var gap := 64.0
	var total_w = card_w * 2.0 + gap
	var start_x = (bloco_instrucao.rect_size.x - total_w) * 0.5

	var bloco_1p := Panel.new()
	bloco_1p.rect_position = Vector2(start_x, 0)
	bloco_1p.rect_size = Vector2(card_w, card_h)
	bloco_1p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_player_1 = bloco_1p
	var s1p := StyleBoxFlat.new()
	s1p.bg_color = Color(0.02, 0.16, 0.45, 0.88)
	s1p.border_color = Color(0.15, 0.65, 1.0, 1.0)
	s1p.border_width_left = 3
	s1p.border_width_top = 3
	s1p.border_width_right = 3
	s1p.border_width_bottom = 3
	s1p.corner_radius_top_left = 20
	s1p.corner_radius_top_right = 20
	s1p.corner_radius_bottom_left = 20
	s1p.corner_radius_bottom_right = 20
	s1p.shadow_color = Color(0.10, 0.55, 1.0, 0.55)
	s1p.shadow_size = 22
	bloco_1p.add_stylebox_override("panel", s1p)
	bloco_instrucao.add_child(bloco_1p)

	var lbl_1p := Label.new()
	lbl_1p.rect_position = Vector2(0, 8)
	lbl_1p.rect_size = Vector2(card_w, 46)
	lbl_1p.text = "🎮  1 × START"
	lbl_1p.align = Label.ALIGN_CENTER
	lbl_1p.valign = Label.VALIGN_CENTER
	Compat.tamanho(lbl_1p, 25)
	lbl_1p.add_color_override("font_color", Color(0.60, 0.92, 1.0))
	lbl_1p.add_color_override("font_outline_modulate", Color.black)
	Compat.contorno(lbl_1p, 5)
	bloco_1p.add_child(lbl_1p)
	

	var lbl_1p_sub := Label.new()
	lbl_1p_sub.rect_position = Vector2(0, 58)
	lbl_1p_sub.rect_size = Vector2(card_w, 42)
	lbl_1p_sub.text = "PLAYER 1"
	lbl_1p_sub.align = Label.ALIGN_CENTER
	lbl_1p_sub.valign = Label.VALIGN_CENTER
	Compat.tamanho(lbl_1p_sub, 25)
	lbl_1p_sub.add_color_override("font_color", Color.white)
	lbl_1p_sub.add_color_override("font_outline_modulate", Color.black)
	Compat.contorno(lbl_1p_sub, 5)
	bloco_1p.add_child(lbl_1p_sub)
	lbl_player_1 = lbl_1p_sub

	var lbl_vs := Label.new()
	lbl_vs.rect_position = Vector2(start_x + card_w, 0)
	lbl_vs.rect_size = Vector2(gap, card_h)
	lbl_vs.text = "VS"
	lbl_vs.align = Label.ALIGN_CENTER
	lbl_vs.valign = Label.VALIGN_CENTER
	Compat.tamanho(lbl_vs, 26)
	lbl_vs.add_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55))
	lbl_vs.add_color_override("font_outline_modulate", Color.black)
	Compat.contorno(lbl_vs, 5)
	bloco_instrucao.add_child(lbl_vs)

	var bloco_2p := Panel.new()
	bloco_2p.rect_position = Vector2(start_x + card_w + gap, 0)
	bloco_2p.rect_size = Vector2(card_w, card_h)
	bloco_2p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_player_2 = bloco_2p
	var s2p := StyleBoxFlat.new()
	s2p.bg_color = Color(0.45, 0.02, 0.04, 0.88)
	s2p.border_color = Color(1.0, 0.16, 0.12, 1.0)
	s2p.border_width_left = 3
	s2p.border_width_top = 3
	s2p.border_width_right = 3
	s2p.border_width_bottom = 3
	s2p.corner_radius_top_left = 20
	s2p.corner_radius_top_right = 20
	s2p.corner_radius_bottom_left = 20
	s2p.corner_radius_bottom_right = 20
	s2p.shadow_color = Color(1.0, 0.10, 0.08, 0.55)
	s2p.shadow_size = 22
	bloco_2p.add_stylebox_override("panel", s2p)
	bloco_instrucao.add_child(bloco_2p)

	var lbl_2p := Label.new()
	lbl_2p.rect_position = Vector2(0, 8)
	lbl_2p.rect_size = Vector2(card_w, 46)
	lbl_2p.text = "🎮🎮  2 × START"
	lbl_2p.align = Label.ALIGN_CENTER
	lbl_2p.valign = Label.VALIGN_CENTER
	Compat.tamanho(lbl_2p, 25)
	lbl_2p.add_color_override("font_color", Color(1.0, 0.62, 0.58))
	lbl_2p.add_color_override("font_outline_modulate", Color.black)
	Compat.contorno(lbl_2p, 5)
	bloco_2p.add_child(lbl_2p)
	card_player_2 = bloco_2p

	var lbl_2p_sub := Label.new()
	lbl_2p_sub.rect_position = Vector2(0, 58)
	lbl_2p_sub.rect_size = Vector2(card_w, 42)
	lbl_2p_sub.text = "PLAYER 2"
	lbl_2p_sub.align = Label.ALIGN_CENTER
	lbl_2p_sub.valign = Label.VALIGN_CENTER
	Compat.tamanho(lbl_2p_sub, 25)
	lbl_2p_sub.add_color_override("font_color", Color.white)
	lbl_2p_sub.add_color_override("font_outline_modulate", Color.black)
	Compat.contorno(lbl_2p_sub, 5)
	bloco_2p.add_child(lbl_2p_sub)

	txt_timer_selecao = Label.new()
	txt_timer_selecao.rect_position = Vector2(40, 492)
	txt_timer_selecao.rect_size = Vector2(740, 44)
	txt_timer_selecao.align = Label.ALIGN_CENTER
	txt_timer_selecao.valign = Label.VALIGN_CENTER
	Compat.tamanho(txt_timer_selecao, 24)
	txt_timer_selecao.add_color_override("font_color", Color(0.80, 1.0, 0.85))
	txt_timer_selecao.add_color_override("font_outline_modulate", Color.black)
	Compat.contorno(txt_timer_selecao, 5)
	painel_selecao_jogadores.add_child(txt_timer_selecao)

	txt_instrucao_selecao = Label.new()
	txt_instrucao_selecao.rect_position = Vector2(40, 542)
	txt_instrucao_selecao.rect_size = Vector2(740, 36)
	txt_instrucao_selecao.text = ""
	txt_instrucao_selecao.align = Label.ALIGN_CENTER
	txt_instrucao_selecao.valign = Label.VALIGN_CENTER
	Compat.tamanho(txt_instrucao_selecao, 20)
	txt_instrucao_selecao.add_color_override("font_color", Color.white * Color(1, 1, 1, 0.58))
	txt_instrucao_selecao.add_color_override("font_outline_modulate", Color.black)
	Compat.contorno(txt_instrucao_selecao, 4)
	painel_selecao_jogadores.add_child(txt_instrucao_selecao)

	var barra_bg := Panel.new()
	barra_bg.rect_position = Vector2(80, 610)
	barra_bg.rect_size = Vector2(660, 16)
	barra_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var barra_bg_s := StyleBoxFlat.new()
	barra_bg_s.bg_color = Color(1, 1, 1, 0.10)
	barra_bg_s.corner_radius_top_left = 8
	barra_bg_s.corner_radius_top_right = 8
	barra_bg_s.corner_radius_bottom_left = 8
	barra_bg_s.corner_radius_bottom_right = 8
	barra_bg.add_stylebox_override("panel", barra_bg_s)
	painel_selecao_jogadores.add_child(barra_bg)

	barra_timer_selecao = ColorRect.new()
	barra_timer_selecao.rect_position = Vector2(80, 610)
	barra_timer_selecao.rect_size = Vector2(660, 16)
	barra_timer_selecao.color = Color(0.18, 0.82, 1.0, 1.0)
	painel_selecao_jogadores.add_child(barra_timer_selecao)

	var linha_base := ColorRect.new()
	linha_base.rect_position = Vector2(80, 638)
	linha_base.rect_size = Vector2(660, 2)
	linha_base.color = Color(1.0, 0.82, 0.14, 0.30)
	linha_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_selecao_jogadores.add_child(linha_base)

	painel_selecao_jogadores.rect_scale = Vector2(0.94, 0.94)
	painel_selecao_jogadores.modulate.a = 0.0
	glow_modal.rect_scale = Vector2(0.94, 0.94)
	glow_modal.modulate.a = 0.0
	
	_aplicar_estado_cards_players()
	_aplicar_fonte_modal(txt_titulo_selecao, 25, Color(0.55, 0.92, 1.0), 7)
	_aplicar_fonte_modal(txt_modo_selecao, 82, Color(0.10, 0.75, 1.0), 14)
	_aplicar_fonte_modal(lbl_1p, 22, Color(0.60, 0.92, 1.0), 5)
	_aplicar_fonte_modal(lbl_1p_sub, 18, Color.white, 5)
	_aplicar_fonte_modal(lbl_2p, 22, Color(1.0, 0.62, 0.58), 5)
	_aplicar_fonte_modal(lbl_2p_sub, 18, Color.white, 5)
	_aplicar_fonte_modal(txt_timer_selecao, 22, Color(0.80, 1.0, 0.85), 5)
	_aplicar_fonte_modal(txt_instrucao_selecao, 18, Color.white * Color(1, 1, 1, 0.58), 4)

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(painel_selecao_jogadores, "rect_scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(painel_selecao_jogadores, "modulate:a", 1.0, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(glow_modal, "rect_scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(glow_modal, "modulate:a", 1.0, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)



func _aplicar_estado_cards_players() -> void:
	if card_player_1 != null:
		var s1 := StyleBoxFlat.new()
		s1.bg_color = Color(0.02, 0.22, 0.62, 0.96)
		s1.border_color = Color(0.10, 0.75, 1.0, 1.0)
		s1.border_width_left = 4
		s1.border_width_top = 4
		s1.border_width_right = 4
		s1.border_width_bottom = 4
		s1.corner_radius_top_left = 20
		s1.corner_radius_top_right = 20
		s1.corner_radius_bottom_left = 20
		s1.corner_radius_bottom_right = 20
		s1.shadow_color = Color(0.10, 0.75, 1.0, 0.85)
		s1.shadow_size = 34
		card_player_1.add_stylebox_override("panel", s1)

		var tw1 = create_tween()
		tw1.tween_property(card_player_1, "rect_scale", Vector2(1.04, 1.04), 0.18)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if lbl_player_1 != null:
		lbl_player_1.text = "PLAYER 1 ATIVO"
		_aplicar_fonte_modal(lbl_player_1, 18, Color(0.75, 0.96, 1.0), 5)

	if card_player_2 != null:
		var s2 := StyleBoxFlat.new()

		if pulsos_start >= 2:
			s2.bg_color = Color(0.62, 0.02, 0.04, 0.96)
			s2.border_color = Color(1.0, 0.12, 0.10, 1.0)
			s2.shadow_color = Color(1.0, 0.06, 0.04, 0.90)
			s2.shadow_size = 38

			if lbl_player_2 != null:
				lbl_player_2.text = "PLAYER 2 ATIVO"
				_aplicar_fonte_modal(lbl_player_2, 18, Color(1.0, 0.72, 0.68), 5)

			var tw2 = create_tween()
			tw2.tween_property(card_player_2, "rect_scale", Vector2(1.08, 1.08), 0.22)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			s2.bg_color = Color(0.14, 0.02, 0.03, 0.48)
			s2.border_color = Color(1.0, 0.16, 0.12, 0.36)
			s2.shadow_color = Color(1.0, 0.10, 0.08, 0.12)
			s2.shadow_size = 10

			if lbl_player_2 != null:
				lbl_player_2.text = "AGUARDANDO 2º START"
				_aplicar_fonte_modal(lbl_player_2, 16, Color(1, 1, 1, 0.48), 4)

			var tw3 = create_tween()
			tw3.tween_property(card_player_2, "rect_scale", Vector2(0.96, 0.96), 0.22)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		s2.border_width_left = 4
		s2.border_width_top = 4
		s2.border_width_right = 4
		s2.border_width_bottom = 4
		s2.corner_radius_top_left = 20
		s2.corner_radius_top_right = 20
		s2.corner_radius_bottom_left = 20
		s2.corner_radius_bottom_right = 20
		card_player_2.add_stylebox_override("panel", s2)



func _atualizar_texto_selecao_jogadores() -> void:
	if txt_modo_selecao == null:
		return

	var segundos: int = max(0, int(ceil(timer_selecao_jogadores)))

	_aplicar_estado_cards_players()

	if pulsos_start >= 2:
		txt_modo_selecao.text = "2 PLAYERS"
		txt_modo_selecao.add_color_override("font_color", Color(1.0, 0.16, 0.12))

		if txt_timer_selecao != null:
			txt_timer_selecao.text = "✅  2 PLAYERS CONFIRMADO!  Iniciando..."
			txt_timer_selecao.add_color_override("font_color", Color(1.0, 0.42, 0.36))

		if txt_instrucao_selecao != null:
			txt_instrucao_selecao.text = ""

		if barra_timer_selecao != null:
			barra_timer_selecao.color = Color(1.0, 0.12, 0.10, 1.0)

	else:
		txt_modo_selecao.text = "1 PLAYER"
		txt_modo_selecao.add_color_override("font_color", Color(0.10, 0.75, 1.0))

		if txt_timer_selecao != null:
			txt_timer_selecao.text = "Aguardando 2º START para 2 Players...  %d" % segundos
			txt_timer_selecao.add_color_override("font_color", Color(0.60, 0.92, 1.0))

		if txt_instrucao_selecao != null:
			txt_instrucao_selecao.text = "▼  aperte START mais uma vez para jogar em dupla  ▼"

		if barra_timer_selecao != null:
			barra_timer_selecao.color = Color(0.10, 0.75, 1.0, 1.0)

	if barra_timer_selecao != null:
		var pct: float = clamp(timer_selecao_jogadores / tempo_selecao_jogadores, 0.0, 1.0)
		barra_timer_selecao.rect_size.x = 660.0 * pct



func _confirmar_quantidade_jogadores() -> void:
	if not seletor_jogadores_ativo:
		return

	seletor_jogadores_ativo = false

	var jogadores_escolhidos: int = 1
	if pulsos_start >= 2:
		jogadores_escolhidos = 2

	if has_node("/root/GameConfig"):
		get_node("/root/GameConfig").jogadores = jogadores_escolhidos

	if layer_selecao_jogadores != null:
		layer_selecao_jogadores.queue_free()
		
	card_player_1 = null
	card_player_2 = null
	lbl_player_1 = null
	lbl_player_2 = null

	layer_selecao_jogadores = null
	painel_selecao_jogadores = null
	txt_titulo_selecao = null
	txt_modo_selecao = null
	txt_instrucao_selecao = null
	txt_timer_selecao = null
	barra_timer_selecao = null

	_iniciar_jogo()



func _ir_para_teste() -> void:
	if not pode_iniciar:
		return

	pode_iniciar = false
	demo_ativa_transicao = false

	_parar_musica_menu()

	var erro: int = get_tree().change_scene(CENA_TESTE)

	if erro != OK:
		push_error("Erro ao carregar cena de teste: " + CENA_TESTE)
		pode_iniciar = true
		_tocar_musica_menu()


func _input(event: InputEvent) -> void:
	if not pode_iniciar:
		return

	if demo_ativa_transicao:
		return

	if _evento_conta_como_interacao(event):
		_resetar_timer_demo()


func _unhandled_input(event: InputEvent) -> void:
	if not pode_iniciar:
		return

	if demo_ativa_transicao:
		return

	if ArcadeControls.eh_config(event):
		print("TESTE VIA ACTION input_teste")
		_resetar_timer_demo()
		_ir_para_teste()
		return

	if ArcadeControls.eh_start(event):
		print("START VIA ACTION")
		_resetar_timer_demo()
		_registrar_pulso_start()
		return

	if ArcadeControls.sem_funcao(event):
		_mostrar_aviso_sem_funcao(event)


## Um botão da placa que não faz nada: avisa na tela qual foi e como
## configurar — o operador não fica apertando no escuro.
var _aviso_sem_funcao: Label = null
var _tween_aviso: SceneTreeTween = null

func _mostrar_aviso_sem_funcao(event: InputEvent) -> void:
	if _aviso_sem_funcao == null:
		var camada := CanvasLayer.new()
		camada.layer = 900
		add_child(camada)
		_aviso_sem_funcao = Label.new()
		_aviso_sem_funcao.rect_position = Vector2(40, Tela.TAMANHO.y - 260)
		_aviso_sem_funcao.rect_size = Vector2(Tela.TAMANHO.x - 80, 120)
		_aviso_sem_funcao.align = Label.ALIGN_CENTER
		_aviso_sem_funcao.valign = Label.VALIGN_CENTER
		_aviso_sem_funcao.autowrap = true
		_aplicar_fonte_modal(_aviso_sem_funcao, 30, Color(1.0, 0.86, 0.2), 8)
		camada.add_child(_aviso_sem_funcao)
	var codigo = ArcadeControls.codigo_do_evento(event)
	_aviso_sem_funcao.text = "%s SEM FUNÇÃO\nSEGURE QUALQUER BOTÃO DA PLACA 10 s PARA CONFIGURAR" % ArcadeControls.texto_do_codigo(codigo)
	_aviso_sem_funcao.modulate.a = 1.0
	if _tween_aviso != null:
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(3.0)
	_tween_aviso.tween_property(_aviso_sem_funcao, "modulate:a", 0.0, 0.5)




func _evento_conta_como_interacao(event: InputEvent) -> bool:
	# Só a placa Zero Delay conta; teclado e controle remoto não.
	return ArcadeControls.eh_atividade(event)


func _resetar_timer_demo() -> void:
	tempo_sem_interacao = 0.0


func _on_viewport_size_changed() -> void:
	_ajustar_layout()


func _resolver_sprite_fundo():
	var candidatos = [
		"Sprite2D",
		"Sprite",
		"Background",
		"BG",
		"Fundo",
		"pista",
		"Pista"
	]

	for nome in candidatos:
		var n = get_node_or_null(nome)
		if n is Sprite:
			return n

	return _procurar_sprite_recursivo(self)


func _resolver_sprite_animado_fundo():
	var candidatos = [
		"AnimatedSprite2D",
		"BackgroundAnimated",
		"BGAnimated",
		"FundoAnimado"
	]

	for nome in candidatos:
		var n = get_node_or_null(nome)
		if n is AnimatedSprite:
			return n

	return _procurar_sprite_animado_recursivo(self)


func _procurar_sprite_recursivo(root):
	for child in root.get_children():
		if child is Sprite:
			return child

		var achado = _procurar_sprite_recursivo(child)
		if achado != null:
			return achado

	return null


func _procurar_sprite_animado_recursivo(root):
	for child in root.get_children():
		if child is AnimatedSprite:
			return child

		var achado = _procurar_sprite_animado_recursivo(child)
		if achado != null:
			return achado

	return null


func _ajustar_layout() -> void:
	_ajustar_fundo()
	_ajustar_rodape()


func _ajustar_fundo() -> void:
	var tela: Vector2 = Tela.retangulo().size
	if tela.x <= 0.0 or tela.y <= 0.0:
		return

	var margem_cover: float = 1.003
	var offset_fino: Vector2 = Vector2(0.0, -6.0)

	if fundo_sprite != null and fundo_sprite.texture != null:
		var tex_size: Vector2 = fundo_sprite.texture.get_size()
		if tex_size.x <= 0.0 or tex_size.y <= 0.0:
			return

		var escala_base: float = max(tela.x / tex_size.x, tela.y / tex_size.y)
		var escala: float = escala_base * margem_cover

		fundo_sprite.centered = true
		fundo_sprite.position = tela * 0.5 + offset_fino
		fundo_sprite.scale = Vector2.ONE * escala
		return

	if fundo_animado != null and fundo_animado.frames != null:
		var anim: String = fundo_animado.animation
		if anim != String(""):
			var frame_tex: Texture = fundo_animado.frames.get_frame(anim, 0)
			if frame_tex != null:
				var tex_size_anim: Vector2 = frame_tex.get_size()
				if tex_size_anim.x <= 0.0 or tex_size_anim.y <= 0.0:
					return

				var escala_base_anim: float = max(tela.x / tex_size_anim.x, tela.y / tex_size_anim.y)
				var escala_anim: float = escala_base_anim * margem_cover

				fundo_animado.centered = true
				fundo_animado.position = tela * 0.5 + offset_fino
				fundo_animado.scale = Vector2.ONE * escala_anim


func _criar_logo_empresa() -> void:
	if logo_sprite != null:
		return

	if not ResourceLoader.exists(CAMINHO_LOGO):
		push_warning("Logo não encontrada em: " + CAMINHO_LOGO)
		return

	var textura_logo: Texture = load(CAMINHO_LOGO)
	if textura_logo == null:
		push_warning("Não foi possível carregar a logo.")
		return

	logo_sprite = Sprite.new()
	logo_sprite.name = "LogoEmpresa"
	logo_sprite.texture = textura_logo
	logo_sprite.centered = true
	Compat.z(logo_sprite, 300)
	add_child(logo_sprite)


func _aplicar_fonte_modal(lbl: Label, tamanho: int, cor: Color, outline: int = 5) -> void:
	if lbl == null:
		return

	if ResourceLoader.exists(fonte_modal_atual):
		Compat.fonte(lbl, load(fonte_modal_atual))

	Compat.tamanho(lbl, tamanho)
	lbl.add_color_override("font_color", cor)
	lbl.add_color_override("font_outline_modulate", Color.black)
	Compat.contorno(lbl, outline)
	lbl.add_color_override("font_color_shadow", Color(0, 0, 0, 0.55))
	lbl.add_constant_override("shadow_offset_x", 3)
	lbl.add_constant_override("shadow_offset_y", 3)



func _iniciar_animacao_logo() -> void:
	if logo_sprite == null:
		return

	if not logo_sprite.has_meta("escala_base_logo"):
		return

	var escala_base: Vector2 = logo_sprite.get_meta("escala_base_logo") as Vector2

	var tween_logo: SceneTreeTween = create_tween()
	tween_logo.set_loops()
	tween_logo.tween_property(logo_sprite, Compat.prop(logo_sprite, "scale"), escala_base * 1.04, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_logo.tween_property(logo_sprite, Compat.prop(logo_sprite, "scale"), escala_base, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _ajustar_rodape() -> void:
	var tela: Vector2 = Tela.retangulo().size
	if tela.x <= 0.0 or tela.y <= 0.0:
		return

	var y_rodape: float = tela.y - 78.0

	if start_button != null:
		var tam: Vector2 = start_button.rect_size
		if tam.x <= 1.0 or tam.y <= 1.0:
			tam = start_button.get_combined_minimum_size()

		start_button.rect_position = Vector2(
			(tela.x - tam.x) * 0.5,
			y_rodape - tam.y * 0.5
		)

	if logo_sprite != null and logo_sprite.texture != null:
		var tex_size: Vector2 = logo_sprite.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var altura_alvo: float = 150.0
			var escala_logo: float = altura_alvo / tex_size.y
			var escala_base_logo: Vector2 = Vector2.ONE * escala_logo

			if not logo_sprite.has_meta("escala_base_logo"):
				logo_sprite.set_meta("escala_base_logo", escala_base_logo)
				logo_sprite.scale = escala_base_logo
			else:
				logo_sprite.set_meta("escala_base_logo", escala_base_logo)

		logo_sprite.position = Vector2(125.0, y_rodape - 2.0)


func _configurar_botao() -> void:
	start_button.text = "START"
	start_button.rect_min_size = Vector2(300.0, 85.0)
	start_button.rect_size = start_button.rect_min_size

	start_button.focus_mode = Control.FOCUS_NONE

	# BLOQUEIA CLIQUE DO MOUSE NO BOTÃO
	start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	start_button.disabled = false

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.50, 1.00, 1.0)
	normal.corner_radius_top_left = 20
	normal.corner_radius_top_right = 20
	normal.corner_radius_bottom_left = 20
	normal.corner_radius_bottom_right = 20
	normal.border_width_left = 4
	normal.border_width_top = 4
	normal.border_width_right = 4
	normal.border_width_bottom = 4
	normal.border_color = Color.white
	normal.shadow_color = Color(0, 0, 0, 0.28)
	normal.shadow_size = 8

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.20, 0.65, 1.00, 1.0)
	hover.corner_radius_top_left = 20
	hover.corner_radius_top_right = 20
	hover.corner_radius_bottom_left = 20
	hover.corner_radius_bottom_right = 20
	hover.border_width_left = 4
	hover.border_width_top = 4
	hover.border_width_right = 4
	hover.border_width_bottom = 4
	hover.border_color = Color(1.0, 0.95, 0.5, 1.0)
	hover.shadow_color = Color(0, 0, 0, 0.35)
	hover.shadow_size = 10

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.05, 0.35, 0.80, 1.0)
	pressed.corner_radius_top_left = 20
	pressed.corner_radius_top_right = 20
	pressed.corner_radius_bottom_left = 20
	pressed.corner_radius_bottom_right = 20
	pressed.border_width_left = 4
	pressed.border_width_top = 4
	pressed.border_width_right = 4
	pressed.border_width_bottom = 4
	pressed.border_color = Color.white
	pressed.shadow_color = Color(0, 0, 0, 0.20)
	pressed.shadow_size = 5

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.10, 0.50, 1.00, 1.0)
	disabled.corner_radius_top_left = 20
	disabled.corner_radius_top_right = 20
	disabled.corner_radius_bottom_left = 20
	disabled.corner_radius_bottom_right = 20
	disabled.border_width_left = 4
	disabled.border_width_top = 4
	disabled.border_width_right = 4
	disabled.border_width_bottom = 4
	disabled.border_color = Color.white
	disabled.shadow_color = Color(0, 0, 0, 0.20)
	disabled.shadow_size = 5

	start_button.add_stylebox_override("normal", normal)
	start_button.add_stylebox_override("hover", hover)
	start_button.add_stylebox_override("pressed", pressed)
	start_button.add_stylebox_override("disabled", disabled)

	start_button.add_color_override("font_color", Color.white)
	start_button.add_color_override("font_color_hover", Color.white)
	start_button.add_color_override("font_color_pressed", Color.white)
	start_button.add_color_override("font_color_disabled", Color.white)
	Compat.tamanho(start_button, 30)


func _on_start_button_pressed() -> void:
	print("BOTÃO CLICADO")
	_resetar_timer_demo()
	_registrar_pulso_start()


func _iniciar_animacao_idle() -> void:
	if start_button == null:
		return

	if tween_idle:
		tween_idle.kill()

	tween_idle = create_tween()
	tween_idle.set_loops()
	tween_idle.tween_property(start_button, Compat.prop(start_button, "scale"), escala_original * 1.04, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_idle.tween_property(start_button, Compat.prop(start_button, "scale"), escala_original, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animacao_click() -> void:
	if start_button == null:
		return

	if tween_idle:
		tween_idle.kill()

	start_button.rect_scale = escala_original
	start_button.modulate = Color(1, 1, 1, 1)

	var tween: SceneTreeTween = create_tween()

	tween.tween_property(start_button, Compat.prop(start_button, "scale"), escala_original * 0.92, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(start_button, Compat.prop(start_button, "scale"), escala_original * 1.08, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(start_button, Compat.prop(start_button, "scale"), escala_original, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.parallel().tween_property(start_button, "modulate", Color(1.0, 0.98, 0.75, 1.0), 0.12)
	tween.parallel().tween_property(start_button, "modulate", Color(1, 1, 1, 1), 0.12).set_delay(0.12)
	tween.parallel().tween_property(start_button, "modulate", Color(1.0, 0.98, 0.75, 1.0), 0.12).set_delay(0.24)
	tween.parallel().tween_property(start_button, "modulate", Color(1, 1, 1, 1), 0.12).set_delay(0.36)


func _configurar_audio() -> void:
	if audio_player == null:
		audio_player = get_node_or_null("MenuMusic") as AudioStreamPlayer
		if audio_player == null:
			audio_player = AudioStreamPlayer.new()
			audio_player.name = "MenuMusic"
			add_child(audio_player)

		audio_player.bus = "Master"
		audio_player.autoplay = false
		audio_player.volume_db = -4.0

		if ResourceLoader.exists(CAMINHO_MUSICA):
			musica_menu = load(CAMINHO_MUSICA)
			audio_player.stream = musica_menu
		else:
			push_warning("Música não encontrada em: " + CAMINHO_MUSICA)

	if audio_click_player == null:
		audio_click_player = get_node_or_null("ButtonClick") as AudioStreamPlayer
		if audio_click_player == null:
			audio_click_player = AudioStreamPlayer.new()
			audio_click_player.name = "ButtonClick"
			add_child(audio_click_player)

		audio_click_player.bus = "Master"
		audio_click_player.autoplay = false
		audio_click_player.volume_db = VOLUME_SOM_BOTAO_DB

		if ResourceLoader.exists(CAMINHO_SOM_BOTAO):
			som_botao = load(CAMINHO_SOM_BOTAO)
			audio_click_player.stream = som_botao
		else:
			push_warning("Som do botão não encontrado em: " + CAMINHO_SOM_BOTAO)
			
	if audio_coin_player == null:
		audio_coin_player = AudioStreamPlayer.new()
		audio_coin_player.name = "CoinPlayer"
		audio_coin_player.bus = "Master"
		audio_coin_player.volume_db = -2.0
		add_child(audio_coin_player)

		if ResourceLoader.exists(CAMINHO_SOM_COIN):
			som_coin = load(CAMINHO_SOM_COIN)
			audio_coin_player.stream = som_coin
		else:
			push_warning("Som coin não encontrado em: " + CAMINHO_SOM_COIN)		


func _tocar_som_coin() -> void:
	if audio_coin_player == null:
		return
	if audio_coin_player.stream == null:
		return

	audio_coin_player.stop()
	audio_coin_player.play()
	

func _tocar_musica_menu() -> void:
	if audio_player == null:
		return

	if audio_player.stream == null:
		return

	if not audio_player.playing:
		audio_player.play(OFFSET_INICIAL_MUSICA)


func _parar_musica_menu() -> void:
	if audio_player != null and audio_player.playing:
		audio_player.stop()


func _tocar_som_botao() -> void:
	if audio_click_player == null:
		return
	if audio_click_player.stream == null:
		return

	audio_click_player.volume_db = VOLUME_SOM_BOTAO_DB
	audio_click_player.stop()
	audio_click_player.play()



func _iniciar_jogo() -> void:
	var _g3_estado = null
	if not pode_iniciar:
		return

	pode_iniciar = false
	demo_ativa_transicao = false

	# Só aqui toca o coin e muda o texto
	_tocar_som_coin()

	if start_button != null:
		start_button.text = "STARTING..."
		_animacao_click()

	yield(get_tree().create_timer(0.12), "timeout")

	if start_button != null:
		start_button.disabled = true

	# A pista vem da carga em segundo plano. Se ainda não terminou, espera
	# quadro a quadro (o menu continua animando) em vez de travar a tela
	# esperando o carregamento.
	while CENA_DO_JOGO in _precarga_pendente \
			and Compat.estado_carga(CENA_DO_JOGO) == Compat.CARGA_EM_ANDAMENTO:
		yield(get_tree(), "idle_frame")
	var recurso: PackedScene = GameConfig.precarregados.get(CENA_DO_JOGO) as PackedScene
	if recurso == null:
		if CENA_DO_JOGO in _precarga_pendente:
			recurso = Compat.pegar_carga(CENA_DO_JOGO) as PackedScene
			_precarga_pendente.erase(CENA_DO_JOGO)
		else:
			recurso = load(CENA_DO_JOGO) as PackedScene
	if recurso == null:
		push_error("Erro ao carregar cena: " + CENA_DO_JOGO)
		pode_iniciar = true

		if start_button != null:
			start_button.disabled = false
			start_button.text = "START"
			start_button.rect_scale = escala_original
			start_button.modulate = Color.white
			_iniciar_animacao_idle()

		_tocar_musica_menu()
		_resetar_timer_demo()
		return

	_parar_musica_menu()
	# O menu escurece rápido, a pista monta por baixo do véu e aparece com
	# a animação de montagem dela: sem tela de carregamento, sem tela cinza.
	var arvore = get_tree()
	_g3_estado = Cortina.fechar(arvore)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")
	var pista: Node = recurso.instance()
	arvore.root.add_child(pista)
	arvore.current_scene = pista
	queue_free()
	Cortina.abrir(arvore)



func _iniciar_demo() -> void:
	var _g3_estado = null
	if demo_ativa_transicao:
		return

	if not pode_iniciar:
		return

	demo_ativa_transicao = true
	pode_iniciar = false

	if start_button != null:
		start_button.disabled = true
		start_button.text = "DEMO MODE"

	_parar_musica_menu()

	_g3_estado = Cortina.fechar(get_tree())
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")
	var erro: int = get_tree().change_scene(CENA_DEMO)
	Cortina.abrir(get_tree())

	if erro != OK:
		push_error("Erro ao carregar cena de demo: " + CENA_DEMO)
		demo_ativa_transicao = false
		pode_iniciar = true

		if start_button != null:
			start_button.disabled = false
			start_button.text = "START"

		_tocar_musica_menu()
		_resetar_timer_demo()




func _forcar_ocultar_cursor() -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_HIDDEN:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _configurar_led() -> void:
	_led_pronto = false

	if not LED_ATIVO:
		return

	_led_pronto = true
	print("LED MAIN pronto:", LED_COM)


func _enviar_led(evento: String) -> void:
	if not LED_ATIVO or not _led_pronto:
		return

	evento = evento.strip_edges().to_upper()

	match evento:
		"MENU", "BLUE", "RED", "IDLE", "NORMAL", "STRIKE", "SPARE", "MISS", "OFF":
			pass
		_:
			return
	if OS.get_name() == "Android":
		ArduinoBridge.send_led(evento)
		return

	var ps = "$p=New-Object System.IO.Ports.SerialPort('%s',9600,'None',8,1);" % LED_COM
	ps += "$p.DtrEnable=$false;$p.RtsEnable=$false;"
	ps += "$p.Open();$p.WriteLine('%s');Start-Sleep -m 35;$p.Close()" % evento

	OS.execute("powershell", ["-NoProfile", "-WindowStyle", "Hidden", "-Command", ps], false)
	print("LED MAIN:", evento)
