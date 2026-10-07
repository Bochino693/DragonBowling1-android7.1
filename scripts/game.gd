extends Node2D

var bloquear_spare_pos_lateral_c: bool = false
var lateral_anterior_para_c: String = ""

var tecla_anterior_no_round: String = ""
var bloquear_spare_pos_c: bool = false

var contador_strikes_jogador_1: int = 0
var contador_strikes_jogador_2: int = 0

var quantidade_jogadores: int = 1
var jogador_atual: int = 1
var round_base_por_jogador: int = 3

var historico_jogador_1: Array = []
var historico_jogador_2: Array = []

const FONTE_ARCADE_PATH := "res://fonts/arcade_impact.ttf"
const TAM_AVISO_PADRAO := 88
const TAM_AVISO_STRIKE := 108
const TAM_ROUND_AVISO := 78

var tween_placar_player_vez: SceneTreeTween = null
var ultimo_player_animado_placar: int = -1

const FONTE_PAINEL_PATH := "res://fonts/painel_arcade.ttf"
const CAMINHO_MASCARA_PISTA := "res://sprites/pista_mascara.png"
const CAMINHO_SHADER_PISTA := "res://shaders/brilho_pista.shader"

var hud_score_player_1_nome: Label = null
var hud_score_player_1_valor: Label = null
var hud_score_player_2_nome: Label = null
var hud_score_player_2_valor: Label = null


# Adicione junto às outras variáveis no topo do arquivo
var pinos_protegidos_sobreviventes: Array = []

var final_card_p1: Panel = null
var final_card_p2: Panel = null
var final_card_single: Panel = null

var final_p1_titulo: Label = null
var final_p1_stats: Label = null
var final_p1_badge: Label = null

var final_p2_titulo: Label = null
var final_p2_stats: Label = null
var final_p2_badge: Label = null

var final_single_titulo: Label = null
var final_single_stats: Label = null

export var volume_audio_roll_db: float = 3.0
export var pino_scene: PackedScene
export(String, FILE, "*.tscn") var cena_main_path: String = "res://scene/Main Menu.tscn"
export var tempo_tela_final: float = 17.0
export var audio_resultado_normal: AudioStream
export var audio_resultado_strike: AudioStream
export var audio_resultado_spare: AudioStream
export var audio_resultado_miss: AudioStream
export var pitch_song_ini: float = 1.18
export var pitch_song_play: float = 1.00
const COR_STRIKE := Color(1.0, 0.50, 0.08)
const COR_SPARE  := Color(1.0, 0.78, 0.22)  # mesma cor
const COR_MISS   := Color(1.0, 0.25, 0.22)   # vermelho
var fim_panel_glow: ColorRect
var fim_panel_borda: ColorRect
var fim_linha_topo: ColorRect
var fim_linha_base: ColorRect

const COR_BG_PANEL      := Color(0.012, 0.020, 0.042, 0.97)
const COR_BORDA_CYAN    := Color(0.15, 0.75, 1.00, 0.70)
const COR_BORDA_YELLOW  := Color(1.00, 0.82, 0.14, 0.75)
const COR_BORDA_GREEN   := Color(0.20, 1.00, 0.20, 0.85)
const COR_BORDA_PURPLE  := Color(0.75, 0.20, 1.00, 0.70)
const COR_GLOW_CYAN     := Color(0.15, 0.75, 1.00, 0.08)
const COR_GLOW_YELLOW   := Color(1.00, 0.82, 0.14, 0.08)
const COR_GLOW_GREEN    := Color(0.20, 1.00, 0.20, 0.10)
const COR_GLOW_PURPLE   := Color(0.75, 0.20, 1.00, 0.08)
const COR_TEXTO_CYAN    := Color(0.55, 0.92, 1.00)
const COR_TEXTO_YELLOW  := Color(1.00, 0.90, 0.20)
const COR_TEXTO_GREEN   := Color(0.22, 1.00, 0.22)
const COR_TEXTO_ORANGE  := Color(1.00, 0.65, 0.10)
const COR_TEXTO_PURPLE  := Color(0.90, 0.40, 1.00)
const COR_TEXTO_BRANCO  := Color(0.92, 0.97, 1.00)
const COR_TEXTO_BLUE    := Color(0.18, 0.48, 1.00)  # ← ADICIONAR esta linha

# ── CONFIGURAÇÃO LED ────────────────────────────────────────────
const LED_ATIVO: bool = true
const LED_COM: String = "COM4"
var _led_pronto: bool = false




func _configurar_led() -> void:
	_led_pronto = false

	if not LED_ATIVO:
		return

	_led_pronto = true
	print("LED: liberado sem travar início:", LED_COM)


func _enviar_led(evento: String) -> void:
	if not LED_ATIVO or not _led_pronto:
		return

	evento = evento.strip_edges().to_upper()

	match evento:
		"MISS", "STRIKE", "SPARE", "NORMAL", "IDLE", "OFF":
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

	print("LED_EVENTO:", evento)



var hud_score_card: Panel = null
var hud_score_titulo: Label = null
var hud_score_em_pe: Label = null
var hud_score_caidos: Label = null
var hud_score_linha: ColorRect = null


var hud_score_total_derrubados: Label = null

var hud_fundo_moderno: Panel = null
var hud_status_card: Panel = null
var hud_status_inner: Panel = null

var overlay_transicao_inicio: CanvasLayer = null
var cortina_inicio: ColorRect = null

var fundo_shader_material: ShaderMaterial = null
var _fundo_efeito_ativo: bool = false

export var animar_brilhos_fundo: bool = true
export var intensidade_brilho_fundo: float = 0.55
export var velocidade_brilho_fundo: float = 1.2
export var limite_brilho_fundo: float = 0.55


export var audio_strike_1: AudioStream
export var audio_strike_2: AudioStream
export var audio_strike_3: AudioStream
export var volume_strike_progressivo_db: float = 1.5

const CAMINHO_AUDIO_STRIKE_1: String = "res://songs/strike-1.wav"
const CAMINHO_AUDIO_STRIKE_2: String = "res://songs/strike-2.wav"
const CAMINHO_AUDIO_STRIKE_3: String = "res://songs/strike-3.wav"

export var audio_end_game: AudioStream
export var volume_end_game_db: float = 0.0
const CAMINHO_AUDIO_END_GAME: String = "res://songs/end-game.wav"

export var audio_coin: AudioStream
export var volume_coin_db: float = 3.0
const CAMINHO_AUDIO_COIN: String = "res://songs/coin.wav"

var final_intro_em_andamento: bool = false
var reinicio_com_credito_em_andamento: bool = false

export var audio_musica_final: AudioStream
export var volume_musica_final_db: float = -2.0

const CAMINHO_MUSICA_FINAL: String = "res://songs/song-1.ogg"

export var audio_fora: AudioStream
export var volume_fora_db: float = 0.0
const CAMINHO_AUDIO_FORA: String = ""
export var volume_resultado_normal_db: float = 0.0
export var volume_resultado_strike_db: float = 1.5
export var volume_resultado_spare_db: float = 0.5
export var volume_resultado_miss_db: float = 0.0
export var audio_impacto_pino: AudioStream
export var volume_impacto_pino_db: float = 3.0
export var max_players_impacto: int = 12
export var atraso_entre_impactos_min: float = 0.018
export var atraso_entre_impactos_max: float = 0.042
export var prolongar_resultado_normal: bool = true
export var prolongar_resultado_strike: bool = true
export var prolongar_resultado_spare: bool = false
export var prolongar_resultado_miss: bool = false
export var duracao_min_resultado_normal: float = 1.45
export var duracao_min_resultado_strike: float = 2.40
export var duracao_min_resultado_spare: float = 1.10
export var duracao_min_resultado_miss: float = 0.80
export var sobreposicao_replay_resultado: float = 0.18

export var audio_song_play: AudioStream
export var volume_song_play_db: float = 0.0
export var prolongar_song_play: bool = true
export var duracao_min_song_play: float = 2.20

export var audio_song_ini: AudioStream
export var volume_song_ini_db: float = 6.0
export var prolongar_song_ini: bool = true
export var duracao_min_song_ini: float = 1.60

const CAMINHO_AUDIO_SONG_PLAY: String = "res://songs/bola-roll_.wav"
const CAMINHO_AUDIO_SONG_INI: String = "res://songs/song_ini.wav"
export var audio_erro_repeticao: AudioStream
export var volume_erro_repeticao_db: float = 0.0
const CAMINHO_AUDIO_ERRO_REPETICAO: String = "res://songs/erro.wav"

### CONFIG CENTRAL DE ÁUDIO DAS JOGADAS ###
# IMPACTO FÍSICO DE PINO: use um som curto e seco. Não reaproveita mais o som de resultado.
export var cortar_resultado_anterior_ao_iniciar_nova_jogada: bool = true
export var usar_fallback_impacto_curto: bool = false
export var tocar_impacto_pinos: bool = true
export var impacto_min_pinos_para_tocar: int = 1
export var fade_out_roll_antes_resultado: float = 0.22

# JOGADAS NORMAIS POR GRUPO DE TECLA
# Z/B = bordas / 1 pino
export var audio_jogada_borda: AudioStream
export var volume_jogada_borda_db: float = 0.0
export var prolongar_jogada_borda: bool = true
export var duracao_min_jogada_borda: float = 1.60

# X/V = laterais médias
export var audio_jogada_lateral: AudioStream
export var volume_jogada_lateral_db: float = 0.0
export var prolongar_jogada_lateral: bool = true
export var duracao_min_jogada_lateral: float = 2.20

# C = jogada central normal (quando não vira strike/spare/miss)
export var audio_jogada_centro: AudioStream
export var volume_jogada_centro_db: float = 0.0
export var prolongar_jogada_centro: bool = true
export var duracao_min_jogada_centro: float = 1.45
export var offset_inicio_jogada_z: float = 5.0
export var offset_inicio_jogada_x: float = 0.0
export var offset_inicio_jogada_c: float = 0.0
export var offset_inicio_jogada_v: float = 3.0
export var offset_inicio_jogada_b: float = 5.0
const CAMINHO_MUSICA_MENU_FINAL: String = "res://songs/song-1.ogg"
const OFFSET_INICIAL_MUSICA_FINAL: float = 0.0
const VOLUME_MUSICA_MENU_FINAL_DB: float = -4.0

const MAX_AUDIO_PLAYERS_PADRAO: int = 8
const INTERVALO_UPDATE_HOVER: float = 0.033
const INTERVALO_UPDATE_HUD: float = 0.050

var pool_audio_fx: Array = []
var pool_audio_roll: Array = []
var pool_audio_resultado: Array = []

var tempo_hover_acc: float = 0.0
var tempo_hud_acc: float = 0.0
var hud_sujo: bool = true
var hover_sujo: bool = true

const CENA_TESTE: String = "res://scene/configuracao_tvbox.tscn"

var audio_menu_final_player: AudioStreamPlayer = null
var musica_menu_final: AudioStream = null

var retorno_em_andamento: bool = false
var strike_assist_ativo: bool = false
var hud_root: CanvasLayer = null
var hud_panel: ColorRect = null
var top_panel: ColorRect = null
var status_panel: ColorRect = null
var mapa_panel: ColorRect = null
var transicao_round_em_andamento: bool = false
var fundo_fullscreen: Sprite = null

var mapa_header_linha: ColorRect = null
var mapa_footer_linha: ColorRect = null
var mapa_subtitulo: Label = null
var mapa_container: Control = null

var pista_root: Node2D = null
var pista_sprite: Sprite = null
var pista_animada: AnimatedSprite = null
var parallax_bg: ParallaxBackground = null

var painel_play: Panel = null
var titulo_play: Label = null
var subtitulo_play: Label = null
var bolas_tentativa: Array = []
var faixas_decorativas_play: Array = []

var pins: Array = []
var pins_container: Node = null
var placar: Label = null
var mapa_label: Label = null
var status_label: Label = null
var round_label: Label = null
var banner_label: Label = null
var final_logo: TextureRect = null

var processando_impacto: bool = false
var aguardando_fim_bola: bool = false
var intro_em_andamento: bool = true
var aceitando_input: bool = false
## Jogada acionada enquanto a pista ainda não aceitava (ver _input).
var _jogada_pendente: String = ""
var _jogada_pendente_ms: int = 0
const VALIDADE_JOGADA_PENDENTE_MS := 10000
## Esperas entre jogadas (antes: 1,65 / 2,30 / 2,10 / 0,45 / 2,00 s).
const ESPERA_FISICA_S := 1.2
const ESPERA_STRIKE_S := 1.8
const ESPERA_ROUND_FECHADO_S := 1.6
const ESPERA_PROXIMA_TENTATIVA_S := 0.3
const ESPERA_FIM_DE_ROUND_S := 1.5
const MESMA_BOLA_MS := 1200
var _ultima_jogada_ms: int = -100000
var contador_strike_assist_c: int = 0

onready var bola: Node = get_node_or_null("Bola")
onready var camera_jogo: Camera2D = get_node_or_null("Camera2D") as Camera2D

var jogando_trajeto: bool = false
var camera_base_zoom: Vector2 = Vector2.ONE
var camera_base_offset: Vector2 = Vector2.ZERO
var camera_base_pos: Vector2 = Vector2.ZERO

var camera_zoom_jogada: float = 0.972
var camera_zoom_idle: Vector2 = Vector2.ONE
var camera_focus_offset_jogada: Vector2 = Vector2(0, -18)

var multiplicador_pinos: float = 1.02
var centro_pista_x: float = 512.0

var ultima_tecla_jogada: String = ""

var total_rounds: int = 3
var round_atual: int = 1
var tentativa_atual: int = 1
var max_tentativas: int = 3

var pinos_derrubados_no_round: int = 0
var pinos_antes_da_jogada: int = 10
var jogo_finalizado: bool = false

var historico_rounds: Array = []

var resultado_audio_tocado_na_jogada: bool = false
var players_impacto_ativos: Array = []
var player_resultado_atual: AudioStreamPlayer = null
var player_inicio_jogada_atual: AudioStreamPlayer = null
var inicio_audio_tocado_na_jogada: bool = false
var token_jogada_atual: int = 0

var overlay_final: CanvasLayer = null
var final_bg: ColorRect = null
var final_panel: Panel = null
var final_titulo: Label = null
var final_stats: Label = null
var final_recorde: Label = null
var final_timer: Label = null
var final_start: Label = null
var final_start_botao: Button = null
var final_start_glow: ColorRect = null
var final_start_linha: ColorRect = null
var final_start_tween_idle: SceneTreeTween = null

var tela_final_ativa: bool = false
var tempo_restante_tela_final: float = 0.0
var anim_tela_final_t: float = 0.0

var contador_strikes_no_jogo: int = 0

var mapa_titulo_label: Label = null
var mapa_pinos_visuais: Dictionary = {}

var overlay_inatividade: CanvasLayer = null
var modal_inatividade_bg: ColorRect = null
var modal_inatividade_panel: Panel = null
var modal_inatividade_titulo: Label = null
var modal_inatividade_texto: Label = null
var modal_inatividade_timer: Label = null

var tempo_sem_atividade: float = 0.0
var limite_inatividade_segundos: float = 60.0
var countdown_inatividade: float = 0.0
var modal_inatividade_ativo: bool = false
var aceitando_input_antes_modal_inatividade: bool = false



var perfis_fisicos = {
	"Z": {
		"alvos_preferidos": [7, 4, 2],
		"bias_x": -1.0,
		"energia": 0.92,
		"spread_lateral": 0.42,
		"propagacao": 0.44,
		"limite": 2
	},
	"X": {
		"alvos_preferidos": [2, 4, 5, 7, 8],
		"bias_x": -0.55,
		"energia": 1.05,
		"spread_lateral": 0.70,
		"propagacao": 0.78,
		"limite": 6
	},
	"C": {
		"alvos_preferidos": [1, 5, 2, 3, 8, 9],
		"bias_x": 0.0,
		"energia": 1.18,
		"spread_lateral": 0.95,
		"propagacao": 0.90,
		"limite": 10
	},
	"V": {
		"alvos_preferidos": [3, 6, 5, 9, 10],
		"bias_x": 0.55,
		"energia": 1.05,
		"spread_lateral": 0.70,
		"propagacao": 0.78,
		"limite": 6
	},
	"B": {
		"alvos_preferidos": [10, 6, 3],
		"bias_x": 1.0,
		"energia": 0.92,
		"spread_lateral": 0.42,
		"propagacao": 0.44,
		"limite": 2
	}
}

var config_jogadas: Dictionary = {
	"Z": {"dir": Vector2(-0.74, -1.0), "forca": 0.96, "spin": -0.10},
	"X": {"dir": Vector2(-0.48, -1.0), "forca": 1.08, "spin": -0.04},
	"C": {"dir": Vector2( 0.00, -1.0), "forca": 1.08, "spin":  0.00},
	"V": {"dir": Vector2( 0.48, -1.0), "forca": 1.08, "spin":  0.04},
	"B": {"dir": Vector2( 0.74, -1.0), "forca": 0.96, "spin":  0.10}
}

const ACOES_JOGO: Dictionary = {
	"input_z": "Z",
	"input_x": "X",
	"input_c": "C",
	"input_v": "V",
	"input_b": "B"
}

const ACAO_RESTART: String = "input_start"

var vizinhos_pinos: Dictionary = {
	1: [2, 3, 5],
	2: [1, 3, 4, 5],
	3: [1, 2, 5, 6],
	4: [2, 5, 7, 8],
	5: [1, 2, 3, 4, 6, 8, 9],
	6: [3, 5, 9, 10],
	7: [4, 8],
	8: [4, 5, 7, 9],
	9: [5, 6, 8, 10],
	10: [6, 9]
}



func _ready() -> void:
	var _g3_estado = null
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	randomize()

	# Não deixa o Godot desenhar a cena desmontada.
	visible = false
	modulate = Color(1, 1, 1, 1)

	_configurar_led()

	if audio_impacto_pino == null and ResourceLoader.exists("res://songs/pinos_queda.wav"):
		audio_impacto_pino = load("res://songs/pinos_queda.wav")

	if audio_song_ini == null and ResourceLoader.exists("res://songs/song_ini.wav"):
		audio_song_ini = load("res://songs/song_ini.wav")

	if audio_musica_final == null and ResourceLoader.exists(CAMINHO_MUSICA_FINAL):
		audio_musica_final = load(CAMINHO_MUSICA_FINAL)

	if audio_end_game == null and ResourceLoader.exists(CAMINHO_AUDIO_END_GAME):
		audio_end_game = load(CAMINHO_AUDIO_END_GAME)

	if audio_coin == null and ResourceLoader.exists(CAMINHO_AUDIO_COIN):
		audio_coin = load(CAMINHO_AUDIO_COIN)

	if audio_erro_repeticao == null and ResourceLoader.exists(CAMINHO_AUDIO_ERRO_REPETICAO):
		audio_erro_repeticao = load(CAMINHO_AUDIO_ERRO_REPETICAO)

	if audio_strike_1 == null and ResourceLoader.exists(CAMINHO_AUDIO_STRIKE_1):
		audio_strike_1 = load(CAMINHO_AUDIO_STRIKE_1)

	if audio_strike_2 == null and ResourceLoader.exists(CAMINHO_AUDIO_STRIKE_2):
		audio_strike_2 = load(CAMINHO_AUDIO_STRIKE_2)

	if audio_strike_3 == null and ResourceLoader.exists(CAMINHO_AUDIO_STRIKE_3):
		audio_strike_3 = load(CAMINHO_AUDIO_STRIKE_3)

	parallax_bg = resolver_no("ParallaxBackground") as ParallaxBackground
	pista_root = resolver_no("pista") as Node2D
	pista_sprite = resolver_no("Sprite") as Sprite
	pista_animada = resolver_no("AnimatedSprite2D") as AnimatedSprite

	hud_root = resolver_no("Hud") as CanvasLayer
	hud_panel = resolver_no("HudPanel") as ColorRect
	top_panel = resolver_no("TopPanel") as ColorRect
	status_panel = resolver_no("StatusPanel") as ColorRect
	mapa_panel = resolver_no("MapaPanel") as ColorRect

	pins_container = resolver_no("Pins")
	placar = resolver_no("Placar") as Label
	mapa_label = resolver_no("MapaLabel") as Label
	status_label = resolver_no("StatusLabel") as Label
	if status_label != null:
		status_label.visible = false
	round_label = resolver_no("RoundLabel") as Label
	banner_label = resolver_no("BannerLabel") as Label

	fundo_fullscreen = pista_sprite

	if pins_container == null:
		push_error("Não foi possível localizar o nó Pins.")
		return

	if placar == null:
		push_error("Não foi possível localizar o nó Placar.")
		return

	if mapa_label == null:
		push_error("Não foi possível localizar o nó MapaLabel.")
		return

	if pino_scene == null:
		push_error("pino_scene está vazio.")
		return

	ajustar_fundo_fullscreen()
	alinhar_camera_sem_mexer_na_pista()
	camera_zoom_idle = camera_base_zoom
	if not get_viewport().is_connected("size_changed", self, "_on_viewport_size_changed"):
		get_viewport().connect("size_changed", self, "_on_viewport_size_changed")

	_configurar_shader_brilho_fundo()
	_inicializar_pools_de_audio()
	_carregar_config_jogadores()

	configurar_hud()
	# A tela de FIM DE JOGO e o aviso de inatividade só aparecem minutos
	# depois: são montados nos quadros seguintes (ver
	# _montar_telas_de_espera), e a pista abre mais rápido na TV Box.
	call_deferred("_montar_telas_de_espera")

	if bola != null:
		if bola.has_signal("impacto_no_deck") and not bola.is_connected("impacto_no_deck", self, "_on_bola_impacto_no_deck"):
			bola.connect("impacto_no_deck", self, "_on_bola_impacto_no_deck")

		if bola.has_signal("jogada_finalizada") and not bola.is_connected("jogada_finalizada", self, "_on_bola_jogada_finalizada"):
			bola.connect("jogada_finalizada", self, "_on_bola_jogada_finalizada")

	iniciar_jogo(false)

	ajustar_fundo_fullscreen()
	alinhar_camera_sem_mexer_na_pista()
	_reaplicar_layout_leve()

	preparar_intro_visual()

	# Agora sim libera a imagem já posicionada.
	visible = true

	call_deferred("_enviar_led", "IDLE")
	_g3_estado = animar_intro_partida()
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")



## Monta a tela final e o aviso de inatividade UM POR QUADRO, depois que a
## pista já apareceu. Tudo que usa esses painéis confere se já existem.
func _montar_telas_de_espera() -> void:
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	if not is_inside_tree():
		return
	if overlay_final == null:
		criar_tela_final()
	yield(get_tree(), "idle_frame")
	if not is_inside_tree():
		return
	if overlay_inatividade == null:
		criar_modal_inatividade()
	_reaplicar_layout_leve()


func _configurar_shader_brilho_fundo() -> void:
	# O brilho das canaletas e do dourado roda também na TV Box: as
	# máscaras (onde fica cada coisa na imagem) vêm prontas numa textura
	# pequena (tools/gerar_mascara_pista.py), e o shader só anima a luz.
	if not animar_brilhos_fundo:
		return
	if fundo_fullscreen == null or not is_instance_valid(fundo_fullscreen):
		return
	if fundo_fullscreen.texture == null:
		return
	if not ResourceLoader.exists(CAMINHO_MASCARA_PISTA):
		return

	var shader: Shader = load(CAMINHO_SHADER_PISTA)

	fundo_shader_material = ShaderMaterial.new()
	fundo_shader_material.shader = shader
	fundo_shader_material.set_shader_param("intensidade", intensidade_brilho_fundo)
	fundo_shader_material.set_shader_param("velocidade", velocidade_brilho_fundo)
	fundo_shader_material.set_shader_param("mascara", load(CAMINHO_MASCARA_PISTA))
	fundo_shader_material.set_shader_param("cor_canaleta", Vector3(0.0, 0.95, 1.0))
	fundo_shader_material.set_shader_param("erro_forca", 0.0)

	fundo_fullscreen.material = fundo_shader_material



func _efeito_canaleta_erro(duracao: float = 2.2) -> void:
	if fundo_shader_material == null:
		return
	if _fundo_efeito_ativo:
		return

	_fundo_efeito_ativo = true

	var vel_original: float = velocidade_brilho_fundo
	var intensidade_original: float = intensidade_brilho_fundo

	# vermelho puro, sem azul/cyan misturando
	fundo_shader_material.set_shader_param("cor_canaleta", Vector3(1.0, 0.0, 0.0))
	fundo_shader_material.set_shader_param("erro_forca", 1.0)
	fundo_shader_material.set_shader_param("velocidade", vel_original * 2.2)
	fundo_shader_material.set_shader_param("intensidade", max(intensidade_original, 0.75))

	yield(get_tree().create_timer(duracao), "timeout")

	var passos: int = 18
	for i in range(passos):
		var t: float = float(i + 1) / float(passos)
		var erro: float = lerp(1.0, 0.0, t)
		var vel: float = lerp(vel_original * 2.2, vel_original, t)

		fundo_shader_material.set_shader_param("erro_forca", erro)
		fundo_shader_material.set_shader_param("velocidade", vel)

		yield(get_tree().create_timer(0.04), "timeout")

	fundo_shader_material.set_shader_param("erro_forca", 0.0)
	fundo_shader_material.set_shader_param("velocidade", vel_original)
	fundo_shader_material.set_shader_param("intensidade", intensidade_original)
	fundo_shader_material.set_shader_param("cor_canaleta", Vector3(0.0, 0.95, 1.0))

	_fundo_efeito_ativo = false


func _efeito_canaleta_strike(duracao: float = 2.0) -> void:
	if fundo_shader_material == null or _fundo_efeito_ativo:
		return
	_fundo_efeito_ativo = true
	fundo_shader_material.set_shader_param("erro_forca", 0.0)

	# Apenas acelera as canaletas, mantém cyan
	var vel_original = velocidade_brilho_fundo
	fundo_shader_material.set_shader_param("velocidade", vel_original * 3.5)

	yield(get_tree().create_timer(duracao), "timeout")

	# Desacelera gradualmente
	var passos := 15
	for i in range(passos):
		var t = float(i + 1) / float(passos)
		var vel: float = lerp(vel_original * 3.5, vel_original, t)
		fundo_shader_material.set_shader_param("velocidade", vel)
		yield(get_tree().create_timer(0.05), "timeout")

	fundo_shader_material.set_shader_param("velocidade", vel_original)
	_fundo_efeito_ativo = false


func _efeito_frenesi_fundo(duracao: float = 1.8) -> void:
	if fundo_shader_material == null:
		return

	var tw_in = create_tween()
	tw_in.tween_method(self, "_definir_frenesi", 0.0, 1.0, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	yield(tw_in, "finished")

	yield(get_tree().create_timer(duracao * 0.4), "timeout")

	var tw_out = create_tween()
	tw_out.tween_method(self, "_definir_frenesi", 1.0, 0.0, duracao * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	yield(tw_out, "finished")




func _definir_frenesi(v: float) -> void:
	if fundo_shader_material != null:
		fundo_shader_material.set_shader_param("frenesi", v)


func _on_viewport_size_changed() -> void:
	call_deferred("alinhar_camera_sem_mexer_na_pista")
	call_deferred("_reaplicar_layout_leve")




# SUBSTITUA a função _forcar_pino_fundo_xv por esta:
func _forcar_pino_fundo_xv(ponto_impacto: Vector2) -> void:
	if ultima_tecla_jogada != "X" and ultima_tecla_jogada != "V":
		return

	var alvo_fundo: int = 8
	var anim: String = "down_rt"

	if ultima_tecla_jogada == "V":
		alvo_fundo = 9
		anim = "down_left"

	var p_fundo: Node = obter_pino_por_numero(alvo_fundo)

	if p_fundo == null:
		return

	if p_fundo.derrubado:
		return

	yield(get_tree().create_timer(0.22), "timeout")

	if p_fundo == null:
		return

	if p_fundo.derrubado:
		return

	# Derruba de verdade, sem depender de receber_forca.
	if p_fundo.has_method("cair_voando"):
		p_fundo.cair_voando(anim, 1.45, ponto_impacto)
	elif p_fundo.has_method("cair"):
		p_fundo.cair(anim, 1.45, ponto_impacto)

	yield(get_tree(), "idle_frame")
	marcar_hud_como_suja()


func _reaplicar_layout_leve() -> void:
	ajustar_fundo_fullscreen()
	centralizar_tela_final()
	centralizar_modal_inatividade()


func resetar_estado_audio_jogada() -> void:
	resultado_audio_tocado_na_jogada = false
	inicio_audio_tocado_na_jogada = false
	token_jogada_atual += 1

	if cortar_resultado_anterior_ao_iniciar_nova_jogada:
		_parar_pool(pool_audio_resultado)


func ajustar_fundo_fullscreen() -> void:
	if fundo_fullscreen == null:
		return
	if fundo_fullscreen.texture == null:
		return

	var tela: Vector2 = Tela.retangulo().size
	var tex: Vector2 = fundo_fullscreen.texture.get_size()

	if tela.x <= 0.0 or tela.y <= 0.0:
		return
	if tex.x <= 0.0 or tex.y <= 0.0:
		return

	# cobre a tela inteira sem deixar borda
	var margem_cover: float = 1.02
	var escala: float = max(tela.x / tex.x, tela.y / tex.y) * margem_cover

	fundo_fullscreen.centered = true
	fundo_fullscreen.position = tela * 0.5 + Vector2(0.0, -8.0)
	fundo_fullscreen.scale = Vector2.ONE * escala
	Compat.z(fundo_fullscreen, -1000)


func centralizar_tela_final() -> void:
	if final_panel == null:
		return

	var tela = Tela.retangulo().size

	final_panel.rect_position = Vector2(
		(tela.x - final_panel.rect_size.x) * 0.5,
		(tela.y - final_panel.rect_size.y) * 0.5
	)

	if fim_panel_glow != null:
		fim_panel_glow.rect_position = final_panel.rect_position - Vector2(26, 26)
		fim_panel_glow.rect_size = final_panel.rect_size + Vector2(52, 52)

	if fim_linha_topo != null:
		fim_linha_topo.rect_position = final_panel.rect_position + Vector2(70, 30)
		fim_linha_topo.rect_size = Vector2(final_panel.rect_size.x - 140, 4)

	if fim_linha_base != null:
		fim_linha_base.rect_position = final_panel.rect_position + Vector2(70, final_panel.rect_size.y - 32)
		fim_linha_base.rect_size = Vector2(final_panel.rect_size.x - 140, 4)

	if final_titulo != null:
		final_titulo.rect_position = final_panel.rect_position + Vector2(40, 42)

	if final_logo != null:
		final_logo.rect_position = final_panel.rect_position + Vector2((final_panel.rect_size.x - final_logo.rect_size.x) * 0.5, 115)

	if final_card_p1 != null:
		final_card_p1.rect_position = Vector2(78, 245)

	if final_card_p2 != null:
		final_card_p2.rect_position = Vector2(492, 245)

	if final_card_single != null:
		final_card_single.rect_position = Vector2((final_panel.rect_size.x - final_card_single.rect_size.x) * 0.5, 260)

	if final_recorde != null:
		final_recorde.rect_position = final_panel.rect_position + Vector2(60, 540)

	if final_timer != null:
		final_timer.rect_position = final_panel.rect_position + Vector2(60, 605)

	if final_start_botao != null:
		final_start_botao.rect_position = final_panel.rect_position + Vector2((final_panel.rect_size.x - final_start_botao.rect_size.x) * 0.5, 668)

	if final_start_glow != null and final_start_botao != null:
		final_start_glow.rect_position = final_start_botao.rect_position - Vector2(18, 14)
		final_start_glow.rect_size = final_start_botao.rect_size + Vector2(36, 28)

	if final_start_linha != null and final_start_botao != null:
		final_start_linha.rect_position = Vector2(28, 12)
		final_start_linha.rect_size = Vector2(final_start_botao.rect_size.x - 56, 4)



func _iniciar_idle_botao_final() -> void:
	if final_start_botao == null:
		return

	if final_start_tween_idle != null:
		final_start_tween_idle.kill()

	final_start_botao.visible = true
	final_start_botao.modulate = Color(1, 1, 1, 1)
	final_start_botao.rect_pivot_offset = final_start_botao.rect_size * 0.5
	final_start_botao.rect_scale = Vector2.ONE

	if final_start_glow != null:
		final_start_glow.visible = true

	final_start_tween_idle = create_tween()
	final_start_tween_idle.set_loops()
	final_start_tween_idle.tween_property(final_start_botao, "rect_scale", Vector2.ONE * 1.04, 0.80).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	final_start_tween_idle.tween_property(final_start_botao, "rect_scale", Vector2.ONE, 0.80).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	
	

func _animar_click_botao_final() -> void:
	if final_start_botao == null:
		return

	if final_start_tween_idle != null:
		final_start_tween_idle.kill()

	final_start_botao.visible = true
	final_start_botao.modulate = Color(1, 1, 1, 1)
	final_start_botao.rect_pivot_offset = final_start_botao.rect_size * 0.5
	final_start_botao.rect_scale = Vector2.ONE

	var tween: SceneTreeTween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(final_start_botao, "rect_scale", Vector2.ONE * 0.92, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(final_start_botao, "rect_scale", Vector2.ONE * 1.10, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(final_start_botao, "rect_scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(final_start_botao, "modulate", Color(1.0, 0.98, 0.75, 1.0), 0.12)
	tween.tween_property(final_start_botao, "modulate", Color(1, 1, 1, 1), 0.12).set_delay(0.12)

	if final_start_glow != null:
		tween.tween_property(final_start_glow, "modulate:a", 1.0, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)



func decidir_strike_assist() -> bool:
	if ultima_tecla_jogada != "C":
		return false

	var em_pe: int = contar_pinos_em_pe()

	if em_pe < 9:
		return false

	if pinos_antes_da_jogada < 10:
		return false

	contador_strike_assist_c += 1

	if contador_strike_assist_c >= 5:
		contador_strike_assist_c = 0
		return true

	return randf() <= 0.38


func _resolver_lateral_xv_de_verdade(ponto_impacto: Vector2) -> void:
	if ultima_tecla_jogada != "X" and ultima_tecla_jogada != "V":
		return
 
	var alvo_num: int = 8
	var anim: String = "down_rt"
 
	if ultima_tecla_jogada == "V":
		alvo_num = 9
		anim = "down_left"
 
	var p: Node = obter_pino_por_numero(alvo_num)
	if p == null or p.derrubado:
		return
 
	# Delay pela distância real
	var dist_real: float = p.global_position.distance_to(ponto_impacto)
	var delay_real: float = clamp(dist_real / 520.0, 0.03, 0.18)
 
	yield(get_tree().create_timer(delay_real * 0.5), "timeout")   # metade antes de checar
 
	if p == null or p.derrubado:
		return
 
	if p.has_method("forcar_queda_imediata"):
		p.forcar_queda_imediata(anim, 2.35, ponto_impacto)
	elif p.has_method("cair_voando"):
		p.cair_voando(anim, 2.35, ponto_impacto, 0.0)
	elif p.has_method("cair"):
		p.cair(anim, 2.35, ponto_impacto)
 
	yield(get_tree(), "idle_frame")
	marcar_hud_como_suja()
	atualizar_mapa_visual()
	atualizar_placar()


func resolver_no(nome: String) -> Node:
	var n: Node = get_node_or_null(nome)
	if n != null:
		return n
	return procurar_no_recursivo(self, nome)


func efeito_miss_total() -> void:
	mostrar_banner("PRA FORA!", Color(1.0, 0.35, 0.30))
	shake_camera(4.2, 0.08, 6)
	_efeito_canaleta_erro(2.2)  # <- adicione aqui
	
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1.0, 0.20, 0.18, 0.0)
	Tela.cobrir_auto(flash)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	layer.add_child(flash)

	var tw: SceneTreeTween = create_tween()
	tw.tween_property(flash, "color", Color(1.0, 0.20, 0.18, 0.18), 0.035)
	tw.tween_property(flash, "color", Color(1.0, 0.20, 0.18, 0.0), 0.08)
	tw.connect("finished", layer, "queue_free")


func procurar_no_recursivo(root: Node, nome: String) -> Node:
	if root.name == nome:
		return root

	for child in root.get_children():
		var resultado: Node = procurar_no_recursivo(child, nome)
		if resultado != null:
			return resultado

	return null


## A câmera fica SEMPRE no centro da viewport, com zoom 1: assim o mundo
## (pinos, bola) e a pista (ParallaxBackground, que segue a câmera) saem
## exatamente onde foram desenhados, ocupando a tela inteira.
##
## Antes a câmera copiava a posição da camada "pista" — mas é a própria
## câmera que move essa camada. Cada nova chamada trocava entre o certo e
## o errado (câmera em 0,0 = pista empurrada para baixo e para a direita,
## pinos fora da tela), e na TV Box a ordem dos quadros decidia qual dos
## dois ficava. Agora a conta não depende de nada que a câmera mexe.
func alinhar_camera_sem_mexer_na_pista() -> void:
	if camera_jogo == null:
		return

	camera_jogo.current = true
	camera_jogo.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	camera_jogo.offset = Vector2.ZERO
	camera_jogo.zoom = Vector2.ONE
	camera_jogo.global_position = get_viewport_rect().size * 0.5
	camera_jogo.force_update_scroll()

	camera_base_pos = camera_jogo.global_position
	camera_base_zoom = Vector2.ONE
	camera_base_offset = Vector2.ZERO
	camera_zoom_idle = Vector2.ONE


func criar_10_pinos() -> void:
	for child in pins_container.get_children():
		child.queue_free()

	pins.clear()

	for i in range(10):
		var pino = pino_scene.instance()
		pino.numero = i + 1
		pino.game_ref = self
		pins_container.add_child(pino)
		pins.append(pino)

	organizar_pinos()
	resetar_pinos()



func criar_painel_play() -> void:
	if hud_root == null:
		return

	if is_instance_valid(painel_play):
		painel_play.queue_free()

	painel_play = Panel.new()
	painel_play.rect_position = Vector2(710, 12)
	painel_play.rect_size = Vector2(304, 206)
	painel_play.modulate = Color(1, 1, 1, 1)
	painel_play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(painel_play)

	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.035, 0.060, 0.105, 0.95)
	estilo.border_color = Color(1.0, 0.82, 0.24, 0.44)
	estilo.border_width_left = 3
	estilo.border_width_top = 3
	estilo.border_width_right = 3
	estilo.border_width_bottom = 3
	estilo.corner_radius_top_left = 32
	estilo.corner_radius_top_right = 32
	estilo.corner_radius_bottom_left = 32
	estilo.corner_radius_bottom_right = 32
	estilo.shadow_color = Color(0, 0, 0, 0.40)
	estilo.shadow_size = 16
	painel_play.add_stylebox_override("panel", estilo)

	var brilho_topo: Panel = Panel.new()
	brilho_topo.name = "BrilhoTopo"
	brilho_topo.rect_position = Vector2(14, 12)
	brilho_topo.rect_size = Vector2(276, 30)
	brilho_topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_play.add_child(brilho_topo)

	var brilho_style: StyleBoxFlat = StyleBoxFlat.new()
	brilho_style.bg_color = Color(0.30, 0.78, 1.0, 0.15)
	brilho_style.corner_radius_top_left = 24
	brilho_style.corner_radius_top_right = 24
	brilho_style.corner_radius_bottom_left = 24
	brilho_style.corner_radius_bottom_right = 24
	brilho_topo.add_stylebox_override("panel", brilho_style)

	var faixa1: ColorRect = ColorRect.new()
	faixa1.rect_position = Vector2(24, 62)
	faixa1.rect_size = Vector2(256, 2)
	faixa1.color = Color(0.40, 0.90, 1.0, 0.38)
	painel_play.add_child(faixa1)

	var faixa2: ColorRect = ColorRect.new()
	faixa2.rect_position = Vector2(24, 166)
	faixa2.rect_size = Vector2(256, 2)
	faixa2.color = Color(1.0, 0.84, 0.24, 0.30)
	painel_play.add_child(faixa2)

	faixas_decorativas_play.clear()
	faixas_decorativas_play.append(faixa1)
	faixas_decorativas_play.append(faixa2)

	titulo_play = Label.new()
	titulo_play.rect_position = Vector2(24, 12)
	titulo_play.rect_size = Vector2(240, 38)
	titulo_play.text = "PLAY"
	Compat.tamanho(titulo_play, 32)
	titulo_play.add_color_override("font_color", Color(1.0, 0.94, 0.34))
	titulo_play.add_color_override("font_outline_modulate", Color(0.05, 0.06, 0.10))
	Compat.contorno(titulo_play, 6)
	titulo_play.align = Label.ALIGN_LEFT
	titulo_play.valign = Label.VALIGN_CENTER
	painel_play.add_child(titulo_play)

	subtitulo_play = Label.new()
	subtitulo_play.rect_position = Vector2(24, 69)
	subtitulo_play.rect_size = Vector2(252, 30)
	subtitulo_play.text = "ROUND 1 / 3"
	Compat.tamanho(subtitulo_play, 20)
	subtitulo_play.add_color_override("font_color", Color(0.84, 0.93, 1.0))
	subtitulo_play.add_color_override("font_outline_modulate", Color(0.04, 0.05, 0.09))
	Compat.contorno(subtitulo_play, 4)
	subtitulo_play.align = Label.ALIGN_LEFT
	subtitulo_play.valign = Label.VALIGN_CENTER
	painel_play.add_child(subtitulo_play)

	bolas_tentativa.clear()

	var posicoes_x: Array = [62.0, 152.0, 242.0]
	for i in range(3):
		var bola_lbl: Label = Label.new()
		bola_lbl.rect_position = Vector2(posicoes_x[i] - 32.0, 108.0)
		bola_lbl.rect_size = Vector2(64, 62)
		bola_lbl.text = "🎳"
		bola_lbl.align = Label.ALIGN_CENTER
		bola_lbl.valign = Label.VALIGN_CENTER
		Compat.tamanho(bola_lbl, 44)
		bola_lbl.add_color_override("font_color", Color(1.0, 0.98, 0.98))
		bola_lbl.add_color_override("font_outline_modulate", Color(0.02, 0.02, 0.04))
		Compat.contorno(bola_lbl, 6)
		painel_play.add_child(bola_lbl)
		bolas_tentativa.append(bola_lbl)



func animar_consumo_tentativa(indice: int) -> void:
	if indice < 0 or indice >= bolas_tentativa.size():
		return

	var bola = bolas_tentativa[indice]
	if bola == null:
		return

	var tw = create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(bola, Compat.prop(bola, "scale"), Vector2(1.22, 1.22), 0.08)
	tw.tween_property(bola, Compat.prop(bola, "scale"), Vector2(0.92, 0.92), 0.14)

	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.85, 0.25, 0.0)
	flash.rect_position = Vector2(0, 0)
	flash.rect_size = painel_play.rect_size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_play.add_child(flash)

	var tw2 = create_tween()
	tw2.tween_property(flash, "color", Color(1.0, 0.85, 0.25, 0.12), 0.05)
	tw2.tween_property(flash, "color", Color(1.0, 0.85, 0.25, 0.0), 0.16)
	tw2.connect("finished", flash, "queue_free")


func atualizar_hub_play() -> void:
	if bolas_tentativa.empty(): return
 
	var usadas: int = clamp(tentativa_atual - 1, 0, max_tentativas)
	if is_instance_valid(titulo_play):   titulo_play.text    = "PLAY"
	if is_instance_valid(subtitulo_play):
		subtitulo_play.text = "TENTATIVA %d / %d" % [tentativa_atual, max_tentativas]
 
	for i in range(bolas_tentativa.size()):
		var b = bolas_tentativa[i]
		if b == null: continue
		if jogo_finalizado:
			b.modulate = Color(0.30, 0.30, 0.34, 0.90)
			b.rect_scale    = Vector2(0.90, 0.90)
		elif i < usadas:
			b.modulate = Color(0.26, 0.26, 0.30, 0.90)
			b.rect_scale    = Vector2(0.90, 0.90)
		elif i == usadas:
			b.modulate = Color(1.0, 1.0, 1.0, 1.0)
			b.rect_scale    = Vector2(1.12, 1.12)
		else:
			b.modulate = Color(0.84, 0.90, 1.0, 0.90)
			b.rect_scale    = Vector2(1.0, 1.0)




func configurar_hud() -> void:
	# ── Oculta TODOS os nós legados da cena ──────────────────────────────────
	if hud_panel   != null: hud_panel.visible   = false
	if top_panel   != null: top_panel.visible   = false
	if status_panel != null: status_panel.visible = false
	if placar      != null: placar.visible      = false
	if mapa_label  != null:
		mapa_label.visible  = false
		mapa_label.modulate = Color(0, 0, 0, 0)
 
	# ── Posiciona o mapa_panel como container transparente ───────────────────
	if mapa_panel != null:
		mapa_panel.rect_position = Vector2(716, 382)
		mapa_panel.rect_size     = Vector2(278, 370)
		mapa_panel.color    = Color(0, 0, 0, 0)
		mapa_panel.visible  = true
		mapa_panel.modulate = Color(1, 1, 1, 1)
 
	# ── Constrói o HUD moderno (SÓ as versões com underscore) ────────────────
	_criar_fundo_hud_moderno()
	_criar_placar_moderno()
	_criar_status_moderno()
	_criar_painel_play()
	_criar_mapa_visual()
 
	# ── RoundLabel (banner central flutuante) ─────────────────────────────────
	if round_label != null:
		Compat.z(round_label, 999)
		round_label.rect_position = Vector2(112, 560)
		round_label.rect_size = Vector2(800, 120)
		round_label.modulate.a = 0.0
		_aplicar_fonte_arcade(round_label, TAM_ROUND_AVISO, COR_TEXTO_CYAN)

	if banner_label != null:
		Compat.z(banner_label, 1000)
		banner_label.rect_position = Vector2(42, 585)
		banner_label.rect_size = Vector2(940, 170)
		banner_label.modulate.a = 0.0
		_aplicar_fonte_arcade(banner_label, TAM_AVISO_PADRAO, COR_TEXTO_YELLOW)
 
	atualizar_status()
	atualizar_hub_play()
	atualizar_mapa_visual()
	atualizar_placar()
 



func _criar_fundo_hud_moderno() -> void:
	if hud_root == null: return
	if is_instance_valid(hud_fundo_moderno): hud_fundo_moderno.queue_free()
 
	hud_fundo_moderno      = Panel.new()
	hud_fundo_moderno.name = "HudFundoModerno"
	hud_fundo_moderno.rect_position = Vector2(28, 4)
	hud_fundo_moderno.rect_size     = Vector2(692, 342)
	hud_fundo_moderno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Compat.z(hud_fundo_moderno, -20)
	hud_root.add_child(hud_fundo_moderno)
 
	hud_fundo_moderno.add_stylebox_override("panel",
		_estilo_neon(Color(0.008, 0.016, 0.036, 0.55),
					 COR_BORDA_CYAN * Color(1,1,1,0.35), 42, 3))
	_adicionar_brilho_topo(hud_fundo_moderno, Color(0.20, 0.80, 1.0, 0.08),
							20, 14, 40, 26, 26)


func _criar_placar_moderno() -> void:
	if hud_root == null:
		return

	if placar != null:
		placar.visible = false

	if is_instance_valid(hud_score_card):
		hud_score_card.queue_free()

	hud_score_card = Panel.new()
	hud_score_card.name = "HudScoreCard"
	hud_score_card.rect_position = Vector2(42, 12)
	hud_score_card.rect_size = Vector2(660, 152)
	hud_score_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(hud_score_card)

	hud_score_card.add_stylebox_override("panel", _estilo_neon(COR_BG_PANEL, COR_BORDA_CYAN, 34, 3))

	_adicionar_brilho_topo(hud_score_card, Color(0.25, 0.85, 1.0, 0.13), 14, 10, 28, 26, 22)

	hud_score_player_1_nome = null
	hud_score_player_1_valor = null
	hud_score_player_2_nome = null
	hud_score_player_2_valor = null
	hud_score_total_derrubados = null
	hud_score_em_pe = null
	hud_score_caidos = null

	_criar_label_painel(hud_score_card, "🎳", Vector2(14, 18), Vector2(56, 116), Color.white, 40, 0)

	var sep0 := ColorRect.new()
	sep0.rect_position = Vector2(78, 16)
	sep0.rect_size = Vector2(2, 118)
	sep0.color = Color(0.20, 0.80, 1.0, 0.30)
	hud_score_card.add_child(sep0)

	if quantidade_jogadores > 1:
		# DEPOIS
		hud_score_player_1_nome = _criar_label_painel(
			hud_score_card, "PLAYER 1", Vector2(90, 8), Vector2(160, 30),
			COR_TEXTO_BLUE, 14, 4
		)
		hud_score_player_1_valor = _criar_label_painel(
			hud_score_card, "0", Vector2(90, 38), Vector2(160, 72),
			COR_TEXTO_BLUE, 48, 8
		)

		var sep1 := ColorRect.new()
		sep1.rect_position = Vector2(260, 16)
		sep1.rect_size = Vector2(2, 118)
		sep1.color = Color(0.20, 0.80, 1.0, 0.32)
		hud_score_card.add_child(sep1)

		hud_score_player_2_nome = _criar_label_painel(
			hud_score_card, "PLAYER 2", Vector2(274, 8), Vector2(160, 30),
			Color(1.0, 0.20, 0.18), 14, 4
		)

		hud_score_player_2_valor = _criar_label_painel(
			hud_score_card, "0", Vector2(274, 38), Vector2(160, 72),
			Color(1.0, 0.20, 0.18), 48, 8
		)

		var sep2 := ColorRect.new()
		sep2.rect_position = Vector2(444, 16)
		sep2.rect_size = Vector2(2, 118)
		sep2.color = Color(0.20, 0.80, 1.0, 0.28)
		hud_score_card.add_child(sep2)

		_criar_label_painel(
			hud_score_card, "CAÍDOS ROUND", Vector2(456, 8), Vector2(184, 30),
			COR_TEXTO_ORANGE, 14, 4
		)

		hud_score_caidos = _criar_label_painel(
			hud_score_card, "0", Vector2(456, 38), Vector2(184, 72),
			COR_TEXTO_ORANGE, 44, 7
		)

	else:
		_criar_label_painel(
			hud_score_card, "TOTAL DERRUBADOS", Vector2(88, 8), Vector2(190, 30),
			COR_TEXTO_CYAN, 14, 4
		)

		hud_score_total_derrubados = _criar_label_painel(
			hud_score_card, "0", Vector2(88, 38), Vector2(190, 76),
			COR_TEXTO_BRANCO, 54, 8
		)

		var sep1 := ColorRect.new()
		sep1.rect_position = Vector2(286, 16)
		sep1.rect_size = Vector2(2, 118)
		sep1.color = Color(0.20, 0.80, 1.0, 0.38)
		hud_score_card.add_child(sep1)

		_criar_label_painel(
			hud_score_card, "EM PÉ", Vector2(298, 8), Vector2(150, 30),
			COR_TEXTO_GREEN, 17, 4
		)

		hud_score_em_pe = _criar_label_painel(
			hud_score_card, "10", Vector2(298, 38), Vector2(150, 76),
			COR_TEXTO_GREEN, 44, 7
		)

		var sep2 := ColorRect.new()
		sep2.rect_position = Vector2(456, 16)
		sep2.rect_size = Vector2(2, 118)
		sep2.color = Color(0.20, 0.80, 1.0, 0.26)
		hud_score_card.add_child(sep2)

		_criar_label_painel(
			hud_score_card, "CAÍDOS", Vector2(466, 8), Vector2(174, 30),
			COR_TEXTO_ORANGE, 17, 4
		)

		hud_score_caidos = _criar_label_painel(
			hud_score_card, "0", Vector2(466, 38), Vector2(174, 76),
			COR_TEXTO_ORANGE, 44, 7
		)

	hud_score_linha = ColorRect.new()
	hud_score_linha.rect_position = Vector2(26, 128)
	hud_score_linha.rect_size = Vector2(608, 2)
	hud_score_linha.color = Color(0.20, 0.80, 1.0, 0.32)
	hud_score_card.add_child(hud_score_linha)

	atualizar_placar()

 


func total_pinos_derrubados_partida() -> int:
	var total: int = 0

	for item in historico_rounds:
		total += int(item.get("derrubados", 0))

	if not jogo_finalizado and not transicao_round_em_andamento:
		total += pinos_derrubados_no_round

	return total


func _criar_status_moderno() -> void:
	if hud_root == null:
		return

	if is_instance_valid(hud_status_card):
		hud_status_card.queue_free()

	hud_status_card = Panel.new()
	hud_status_card.name = "HudStatusCard"
	hud_status_card.rect_position = Vector2(54, 168)
	hud_status_card.rect_size = Vector2(626, 166)
	hud_status_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Compat.z(hud_status_card, -5)

	var s_transp := StyleBoxFlat.new()
	s_transp.bg_color = Color(0, 0, 0, 0)
	hud_status_card.add_stylebox_override("panel", s_transp)
	hud_root.add_child(hud_status_card)

	var row_round = _criar_row_status(
		hud_status_card,
		Vector2(0, 0),
		Vector2(626, 76),
		COR_BORDA_CYAN,
		COR_GLOW_CYAN,
		"🏆",
		COR_TEXTO_CYAN,
		"ROUND ATUAL",
		COR_TEXTO_CYAN,
		16
	)

	var lbl_player = _criar_label(
		row_round,
		"",
		Vector2(78, 30),
		Vector2(160, 40),
		COR_TEXTO_CYAN,
		27,
		6,
		Label.ALIGN_LEFT,
		Label.VALIGN_CENTER
	)
	lbl_player.name = "LblPlayerVal"

	var lbl_round = _criar_label(
		row_round,
		"ROUND 1 / 3",
		Vector2(238, 30),
		Vector2(360, 40),
		COR_TEXTO_BRANCO,
		27,
		6,
		Label.ALIGN_LEFT,
		Label.VALIGN_CENTER
	)
	lbl_round.name = "LblRoundVal"

	var row_derru = _criar_row_status(
		hud_status_card,
		Vector2(0, 88),
		Vector2(626, 76),
		COR_BORDA_PURPLE,
		COR_GLOW_PURPLE,
		"🎳",
		COR_TEXTO_PURPLE,
		"DERRUBADOS NO ROUND",
		COR_TEXTO_PURPLE,
		15
	)

	var lbl_derru = _criar_label(
		row_derru,
		"0 / 10",
		Vector2(78, 30),
		Vector2(530, 40),
		COR_TEXTO_BRANCO,
		27,
		6,
		Label.ALIGN_LEFT,
		Label.VALIGN_CENTER
	)
	lbl_derru.name = "LblDerruVal"
 

 
# Helper: cria uma row de status com ícone + label de título
func _criar_row_status(
	pai: Control,
	pos: Vector2,
	tam: Vector2,
	borda: Color,
	glow: Color,
	icone: String,
	cor_icone: Color,
	titulo: String,
	cor_titulo: Color,
	titulo_size: int
) -> Panel:
	var row := Panel.new()
	row.rect_position = pos
	row.rect_size = tam
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_stylebox_override(
		"panel",
		_estilo_neon(
			Color(COR_BG_PANEL.r, COR_BG_PANEL.g, COR_BG_PANEL.b, 0.96),
			borda,
			24,
			3
		)
	)
	pai.add_child(row)

	var ico_bg := Panel.new()
	ico_bg.rect_position = Vector2(0, 0)
	ico_bg.rect_size = Vector2(70, tam.y)
	ico_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ico_s := StyleBoxFlat.new()
	ico_s.bg_color = glow * Color(1, 1, 1, 2.0)
	ico_s.corner_radius_top_left = 22
	ico_s.corner_radius_bottom_left = 22
	ico_bg.add_stylebox_override("panel", ico_s)
	row.add_child(ico_bg)

	_criar_label(
		row,
		icone,
		Vector2(0, 0),
		Vector2(70, tam.y),
		cor_icone,
		30,
		0
	)

	_criar_label(
		row,
		titulo,
		Vector2(78, 6),
		Vector2(tam.x - 92, 26),
		cor_titulo,
		titulo_size,
		4,
		Label.ALIGN_LEFT,
		Label.VALIGN_CENTER
	)

	return row


func _criar_painel_play() -> void:
	if hud_root == null:
		return

	if is_instance_valid(painel_play):
		painel_play.queue_free()

	painel_play = Panel.new()
	painel_play.rect_position = Vector2(710, 12)
	painel_play.rect_size = Vector2(304, 210)
	painel_play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(painel_play)

	painel_play.add_stylebox_override("panel",
		_estilo_neon(COR_BG_PANEL, COR_BORDA_YELLOW, 32, 3))

	_adicionar_brilho_topo(
		painel_play,
		Color(0.90, 0.75, 0.10, 0.13),
		14, 12, 28, 26, 22
	)

	for i in range(3):
		var dot := ColorRect.new()
		dot.rect_size = Vector2(5, 5)
		dot.color = COR_BORDA_YELLOW
		dot.rect_position = Vector2(14 + i * 9, 14)
		painel_play.add_child(dot)

	for i in range(3):
		var dot := ColorRect.new()
		dot.rect_size = Vector2(5, 5)
		dot.color = COR_BORDA_YELLOW
		dot.rect_position = Vector2(painel_play.rect_size.x - 30 + i * 9, 14)
		painel_play.add_child(dot)

	titulo_play = _criar_label_painel(
		painel_play,
		"PLAY",
		Vector2(14, 10),
		Vector2(276, 42),
		COR_TEXTO_YELLOW,
		30,
		7
	)

	_linha_decorativa(
		painel_play,
		58,
		Color(0.30, 0.85, 1.0, 0.45),
		20,
		2
	)

	var badge := Panel.new()
	badge.rect_position = Vector2(18, 66)
	badge.rect_size = Vector2(268, 34)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var badge_s := StyleBoxFlat.new()
	badge_s.bg_color = Color(0.005, 0.012, 0.030, 0.90)
	badge_s.border_color = COR_BORDA_YELLOW * Color(1, 1, 1, 0.50)
	badge_s.border_width_left = 1
	badge_s.border_width_top = 1
	badge_s.border_width_right = 1
	badge_s.border_width_bottom = 1
	badge_s.corner_radius_top_left = 10
	badge_s.corner_radius_top_right = 10
	badge_s.corner_radius_bottom_left = 10
	badge_s.corner_radius_bottom_right = 10
	badge.add_stylebox_override("panel", badge_s)
	painel_play.add_child(badge)

	subtitulo_play = _criar_label_painel(
		painel_play,
		"TENTATIVA 1 / 3",
		Vector2(18, 66),
		Vector2(268, 34),
		COR_TEXTO_BRANCO,
		18,
		4
	)

	_linha_decorativa(
		painel_play,
		106,
		Color(0.30, 0.85, 1.0, 0.38),
		20,
		2
	)

	bolas_tentativa.clear()

	var posicoes_x: Array = [58.0, 152.0, 246.0]

	for i in range(3):
		var b := Label.new()
		b.rect_position = Vector2(posicoes_x[i] - 36.0, 112.0)
		b.rect_size = Vector2(72, 72)
		b.text = "🎳"
		b.align = Label.ALIGN_CENTER
		b.valign = Label.VALIGN_CENTER
		Compat.tamanho(b, 44)
		b.add_color_override("font_color", Color(1, 0.97, 0.97))
		b.add_color_override("font_outline_modulate", Color(0.02, 0.02, 0.04))
		Compat.contorno(b, 6)
		painel_play.add_child(b)
		bolas_tentativa.append(b)

	_linha_decorativa(
		painel_play,
		painel_play.rect_size.y - 14,
		Color(1.0, 0.82, 0.14, 0.38),
		20,
		2
	)


func _criar_mapa_visual() -> void:
	if mapa_panel == null:
		return

	for child in mapa_panel.get_children():
		child.queue_free()

	mapa_pinos_visuais.clear()
	mapa_header_linha = null
	mapa_footer_linha = null
	mapa_subtitulo = null
	mapa_container = null
	mapa_titulo_label = null

	mapa_panel.rect_position = Vector2(716, 382)
	mapa_panel.rect_size = Vector2(278, 370)
	mapa_panel.color = Color(0, 0, 0, 0)

	var card := Panel.new()
	card.name = "MapaCard"
	card.rect_position = Vector2.ZERO
	card.rect_size = mapa_panel.rect_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	card.add_stylebox_override(
		"panel",
		_estilo_neon(
			Color(0.003, 0.038, 0.010, 0.30),
			COR_BORDA_GREEN,
			34,
			4
		)
	)

	mapa_panel.add_child(card)

	_adicionar_brilho_topo(
		card,
		Color(0.22, 1.0, 0.28, 0.08),
		14, 12, 28, 28, 22
	)

	mapa_titulo_label = _criar_label_painel(
		mapa_panel,
		"◆◆  MAPA DOS PINOS  ◆◆",
		Vector2(8, 16),
		Vector2(mapa_panel.rect_size.x - 16, 40),
		COR_TEXTO_GREEN,
		17,
		5
	)

	mapa_header_linha = _linha_decorativa(
		mapa_panel,
		62,
		Color(0.28, 1.0, 0.28, 0.34),
		22,
		3
	)

	mapa_subtitulo = _criar_label_painel(
		mapa_panel,
		"—  FORMAÇÃO DO RACK  —",
		Vector2(8, 70),
		Vector2(mapa_panel.rect_size.x - 16, 45),
		COR_TEXTO_GREEN * Color(1, 1, 1, 0.74),
		15,
		4
	)

	mapa_container = Control.new()
	mapa_container.name = "MapaContainer"
	mapa_container.rect_position = Vector2(20, 118)
	mapa_container.rect_size = Vector2(mapa_panel.rect_size.x - 40, 205)
	mapa_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mapa_panel.add_child(mapa_container)

	var pitch_x: float = 56.0
	var pitch_y: float = 52.0
	var dot_size: float = 38.0

	var largura_triangulo: float = (pitch_x * 3.0) + dot_size
	var origin_x: float = (mapa_container.rect_size.x - largura_triangulo) * 0.5
	var origin_y: float = 4.0

	var posicoes = {
		7: Vector2(origin_x + pitch_x * 0.0, origin_y + pitch_y * 0.0),
		8: Vector2(origin_x + pitch_x * 1.0, origin_y + pitch_y * 0.0),
		9: Vector2(origin_x + pitch_x * 2.0, origin_y + pitch_y * 0.0),
		10: Vector2(origin_x + pitch_x * 3.0, origin_y + pitch_y * 0.0),

		4: Vector2(origin_x + pitch_x * 0.5, origin_y + pitch_y * 1.0),
		5: Vector2(origin_x + pitch_x * 1.5, origin_y + pitch_y * 1.0),
		6: Vector2(origin_x + pitch_x * 2.5, origin_y + pitch_y * 1.0),

		2: Vector2(origin_x + pitch_x * 1.0, origin_y + pitch_y * 2.0),
		3: Vector2(origin_x + pitch_x * 2.0, origin_y + pitch_y * 2.0),

		1: Vector2(origin_x + pitch_x * 1.5, origin_y + pitch_y * 3.0)
	}

	for numero in posicoes.keys():
		var wrap := Control.new()
		wrap.rect_position = posicoes[numero]
		wrap.rect_size = Vector2(dot_size, dot_size)
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mapa_container.add_child(wrap)

		var glow := Panel.new()
		glow.rect_position = Vector2.ZERO
		glow.rect_size = Vector2(dot_size, dot_size)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(glow)

		_criar_label_painel(
			wrap,
			str(numero),
			Vector2(0, 0),
			Vector2(dot_size, dot_size),
			Color(0.94, 1.0, 0.92),
			20,
			4
		)

		mapa_pinos_visuais[int(numero)] = glow

	mapa_footer_linha = _linha_decorativa(
		mapa_panel,
		mapa_panel.rect_size.y - 20,
		Color(0.28, 1.0, 0.28, 0.34),
		22,
		3
	)

	atualizar_mapa_visual()



func criar_fundo_hud_moderno() -> void:
	pass  # Desativada — use _criar_fundo_hud_moderno()


func criar_status_moderno() -> void:
	pass  # Desativada — use _criar_status_moderno()

func criar_placar_moderno() -> void:
	pass  # Desativada — use _criar_placar_moderno()


func criar_mapa_visual() -> void:
	pass  # Desativada — use _criar_mapa_visual()


func atualizar_mapa_visual() -> void:
	for p in pins:
		if p == null: continue
		var dot: Panel = mapa_pinos_visuais.get(p.numero, null)
		if dot == null: continue
 
		var s := StyleBoxFlat.new()
		s.corner_radius_top_left    = 999
		s.corner_radius_top_right   = 999
		s.corner_radius_bottom_left = 999
		s.corner_radius_bottom_right= 999
		s.border_width_left  = 2
		s.border_width_top   = 2
		s.border_width_right = 2
		s.border_width_bottom= 2
 
		if p.derrubado:
			s.bg_color     = Color(0.10, 0.12, 0.16, 0.98)
			s.border_color = Color(0.28, 0.30, 0.36, 0.85)
			dot.rect_scale      = Vector2(0.90, 0.90)
			dot.modulate   = Color(1, 1, 1, 0.50)
		else:
			s.bg_color     = Color(0.12, 0.96, 0.44, 1.0)
			s.border_color = Color(0.02, 0.08, 0.04, 0.95)
			dot.rect_scale      = Vector2(1.0, 1.0)
			dot.modulate   = Color(1, 1, 1, 1.0)
 
		dot.add_stylebox_override("panel", s)




func _calcular_jogadas_feitas() -> int:
	var total: int = 0

	for item in historico_rounds:
		total += int(item.get("tentativas", 0))

	return int(max(total, 0))


func _calcular_rounds_jogados() -> int:
	return int(max(historico_rounds.size(), 1))


func _calcular_media_derrubagem_por_rodada(total_derrubados: int) -> float:
	return float(total_derrubados) / float(_calcular_rounds_jogados())


func _calcular_eficiencia_por_rodada(total_derrubados: int) -> int:
	var rounds: int = _calcular_rounds_jogados()
	return int(round((float(total_derrubados) / (float(rounds) * 10.0)) * 100.0))


func criar_tela_final() -> void:
	overlay_final = CanvasLayer.new()
	overlay_final.layer = 50
	add_child(overlay_final)

	final_bg = ColorRect.new()
	Tela.cobrir_auto(final_bg)
	final_bg.color = Color(0, 0, 0, 0.0)
	overlay_final.add_child(final_bg)

	fim_panel_glow = ColorRect.new()
	fim_panel_glow.color = Color(0.10, 0.75, 1.0, 0.0)
	fim_panel_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_final.add_child(fim_panel_glow)

	final_panel = Panel.new()
	final_panel.rect_size = Vector2(940, 790)
	final_panel.modulate.a = 0.0
	Compat.z(final_panel, 2)
	overlay_final.add_child(final_panel)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.006, 0.014, 0.040, 0.97)
	estilo.border_color = Color(0.18, 0.82, 1.0, 0.95)
	estilo.border_width_left = 5
	estilo.border_width_top = 5
	estilo.border_width_right = 5
	estilo.border_width_bottom = 5
	estilo.corner_radius_top_left = 44
	estilo.corner_radius_top_right = 44
	estilo.corner_radius_bottom_left = 44
	estilo.corner_radius_bottom_right = 44
	estilo.shadow_color = Color(0.0, 0.70, 1.0, 0.55)
	estilo.shadow_size = 52
	final_panel.add_stylebox_override("panel", estilo)

	fim_linha_topo = ColorRect.new()
	fim_linha_topo.color = Color(0.18, 0.82, 1.0, 0.0)
	overlay_final.add_child(fim_linha_topo)

	fim_linha_base = ColorRect.new()
	fim_linha_base.color = Color(1.0, 0.82, 0.14, 0.0)
	overlay_final.add_child(fim_linha_base)

	final_titulo = Label.new()
	final_titulo.rect_size = Vector2(860, 74)
	final_titulo.align = Label.ALIGN_CENTER
	final_titulo.valign = Label.VALIGN_CENTER
	final_titulo.modulate.a = 0.0
	Compat.z(final_titulo, 4)
	overlay_final.add_child(final_titulo)
	_aplicar_fonte_arcade(final_titulo, 48, COR_TEXTO_YELLOW)

	final_logo = TextureRect.new()
	final_logo.expand = true
	final_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	final_logo.rect_size = Vector2(280, 105)
	final_logo.modulate = Color(1, 1, 1, 0.0)
	Compat.z(final_logo, 4)
	if ResourceLoader.exists("res://sprites/logoofi.png"):
		final_logo.texture = load("res://sprites/logoofi.png")
	overlay_final.add_child(final_logo)

	var c1 = _criar_card_final_player(final_panel, "PLAYER 1", COR_TEXTO_CYAN)
	final_card_p1 = c1["card"]
	final_p1_titulo = c1["titulo"]
	final_p1_badge = c1["badge"]
	final_p1_stats = c1["stats"]

	var c2 = _criar_card_final_player(final_panel, "PLAYER 2", Color(1.0, 0.22, 0.18))
	final_card_p2 = c2["card"]
	final_p2_titulo = c2["titulo"]
	final_p2_badge = c2["badge"]
	final_p2_stats = c2["stats"]

	final_card_single = Panel.new()
	final_card_single.rect_size = Vector2(540, 265)
	final_card_single.mouse_filter = Control.MOUSE_FILTER_IGNORE
	final_card_single.add_stylebox_override("panel", _estilo_card_final(COR_TEXTO_CYAN, true))
	final_panel.add_child(final_card_single)

	final_single_titulo = _criar_label_painel(
		final_card_single,
		"RESULTADO",
		Vector2(28, 22),
		Vector2(484, 48),
		COR_TEXTO_CYAN,
		25,
		5
	)

	final_single_stats = _criar_label_painel(
		final_card_single,
		"",
		Vector2(36, 88),
		Vector2(468, 140),
		COR_TEXTO_BRANCO,
		25,
		5
	)

	final_recorde = Label.new()
	final_recorde.rect_size = Vector2(820, 50)
	final_recorde.align = Label.ALIGN_CENTER
	final_recorde.valign = Label.VALIGN_CENTER
	final_recorde.modulate.a = 0.0
	Compat.z(final_recorde, 4)
	overlay_final.add_child(final_recorde)

	final_timer = Label.new()
	final_timer.rect_size = Vector2(820, 44)
	final_timer.align = Label.ALIGN_CENTER
	final_timer.valign = Label.VALIGN_CENTER
	final_timer.modulate.a = 0.0
	Compat.z(final_timer, 4)
	overlay_final.add_child(final_timer)

	final_start_glow = ColorRect.new()
	final_start_glow.color = Color(0.18, 0.70, 1.0, 0.0)
	final_start_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Compat.z(final_start_glow, 2)
	overlay_final.add_child(final_start_glow)

	final_start_botao = Button.new()
	final_start_botao.text = "PRESSIONE START PARA RECOMEÇAR"
	final_start_botao.rect_min_size = Vector2(660, 84)
	final_start_botao.rect_size = final_start_botao.rect_min_size
	final_start_botao.focus_mode = Control.FOCUS_NONE
	final_start_botao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	final_start_botao.disabled = true
	Compat.z(final_start_botao, 5)
	overlay_final.add_child(final_start_botao)

	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.08, 0.42, 1.0, 0.98)
	btn.border_color = Color(1.0, 0.92, 0.32, 1.0)
	btn.border_width_left = 4
	btn.border_width_top = 4
	btn.border_width_right = 4
	btn.border_width_bottom = 4
	btn.corner_radius_top_left = 24
	btn.corner_radius_top_right = 24
	btn.corner_radius_bottom_left = 24
	btn.corner_radius_bottom_right = 24
	btn.shadow_color = Color(0.0, 0.65, 1.0, 0.45)
	btn.shadow_size = 24
	final_start_botao.add_stylebox_override("normal", btn)
	final_start_botao.add_stylebox_override("disabled", btn)
	final_start_botao.add_color_override("font_color", Color.white)
	final_start_botao.add_color_override("font_color_disabled", Color.white)
	final_start_botao.add_color_override("font_outline_modulate", Color.black)
	Compat.contorno(final_start_botao, 6)
	Compat.tamanho(final_start_botao, 24)

	if ResourceLoader.exists(FONTE_PAINEL_PATH):
		Compat.fonte(final_start_botao, load(FONTE_PAINEL_PATH))

	final_start_linha = ColorRect.new()
	final_start_linha.color = Color(1.0, 0.96, 0.72, 0.28)
	final_start_botao.add_child(final_start_linha)

	final_start = Label.new()
	final_start.visible = false
	overlay_final.add_child(final_start)

	centralizar_tela_final()
	overlay_final.visible = false



func preparar_intro_visual() -> void:
	# NÃO desmonta a cena.
	# Apenas prepara uma intro suave com fade + entrada dos pinos.

	for node in [
		hud_fundo_moderno,
		hud_score_card,
		hud_status_card,
		painel_play,
		mapa_panel
	]:
		if node != null:
			node.modulate = Color(1, 1, 1, 0.0)
			node.set(Compat.prop(node, "scale"), Vector2.ONE)

	# Garante layout correto dos painéis
	if mapa_panel != null:
		mapa_panel.rect_position = Vector2(716, 382)

	if painel_play != null:
		painel_play.rect_position = Vector2(710, 12)

	if hud_fundo_moderno != null:
		hud_fundo_moderno.rect_position = Vector2(28, 4)

	if hud_score_card != null:
		hud_score_card.rect_position = Vector2(42, 12)

	if hud_status_card != null:
		hud_status_card.rect_position = Vector2(54, 168)

	# Labels invisíveis no início
	if mapa_label != null:
		mapa_label.visible = false
		mapa_label.modulate = Color(1, 1, 1, 0.0)

	if round_label != null:
		round_label.modulate = Color(1, 1, 1, 0.0)

	if banner_label != null:
		banner_label.modulate = Color(1, 1, 1, 0.0)

	# Pinos: salva posição original e impede acumular deslocamento
	for p in pins:
		if p == null:
			continue

		if p.has_method("resetar"):
			p.resetar()

		if p is Node2D:
			var base_pos: Vector2

			if not p.has_meta("intro_base_pos"):
				base_pos = p.position
				p.set_meta("intro_base_pos", base_pos)
			else:
				base_pos = p.get_meta("intro_base_pos")

			# Entra de baixo levemente
			# A MÁQUINA BAIXA OS PINOS: entram de cima (ver animar_pinos_em_cascata)
			p.position = base_pos + Vector2(0, -DESCIDA_MONTAGEM_PINOS)

		if p is CanvasItem:
			p.modulate = Color(1, 1, 1, 0.0)
			p.visible = true

	# Bola: salva posição original corretamente
	if bola != null and bola is Node2D:
		var bola_base: Vector2

		if not bola.has_meta("intro_base_pos"):
			bola_base = bola.position
			bola.set_meta("intro_base_pos", bola_base)
		else:
			bola_base = bola.get_meta("intro_base_pos")

		bola.position = bola_base + Vector2(0, 85)

		if bola is CanvasItem:
			bola.modulate = Color(1, 1, 1, 0.0)
			bola.visible = true

	# Garante câmera correta ANTES da tela aparecer
	if camera_jogo != null:
		camera_jogo.current = true
		camera_jogo.offset = Vector2.ZERO
		camera_jogo.global_position = camera_base_pos
		camera_jogo.zoom = camera_base_zoom
		camera_jogo.force_update_scroll()

	# Corrige fundo quebrado/cinza
	ajustar_fundo_fullscreen()
	alinhar_camera_sem_mexer_na_pista()
	_reaplicar_layout_leve()



## Quanto o rack desce do alto na montagem dos pinos.
const DESCIDA_MONTAGEM_PINOS := 120.0

func animar_intro_partida() -> void:
	var _g3_estado = null
	intro_em_andamento = true
	aceitando_input = false

	if mapa_label != null:
		mapa_label.visible = false
		mapa_label.modulate = Color(1, 1, 1, 0.0)

	var tw: SceneTreeTween = create_tween()
	tw.set_parallel(true)
	
	if hud_fundo_moderno != null:
		tw.tween_property(hud_fundo_moderno, "rect_position", Vector2(28, 4), 0.78)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(hud_fundo_moderno, "modulate:a", 1.0, 0.42)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if hud_score_card != null:
		tw.tween_property(hud_score_card, "rect_position", Vector2(42, 12), 0.82)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(hud_score_card, "rect_scale", Vector2.ONE, 0.82)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(hud_score_card, "modulate:a", 1.0, 0.42)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if hud_status_card != null:
		tw.tween_property(hud_status_card, "rect_position", Vector2(54, 170), 0.86)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(hud_status_card, "rect_scale", Vector2.ONE, 0.86)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(hud_status_card, "modulate:a", 1.0, 0.46)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if hud_panel != null:
		# fundo termina centralizado
		tw.tween_property(hud_panel, "rect_position", Vector2(46, 8), 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(hud_panel, "modulate:a", 1.0, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if top_panel != null:
		tw.tween_property(top_panel, "rect_position", Vector2(84, 14), 0.80).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(top_panel, "modulate:a", 1.0, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if status_panel != null:
		tw.tween_property(status_panel, "rect_position", Vector2(84, 90), 0.88).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(status_panel, "modulate:a", 1.0, 0.50).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if placar != null:
		tw.tween_property(placar, "rect_position", Vector2(96, 18), 0.78).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(placar, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


	if mapa_panel != null:
		tw.tween_property(mapa_panel, "rect_position", Vector2(738, 382), 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(mapa_panel, "modulate:a", 1.0, 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if painel_play != null:
		tw.tween_property(painel_play, "rect_position", Vector2(710, 12), 0.78).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(painel_play, "modulate:a", 1.0, 0.44).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if camera_jogo != null:
		tw.tween_property(camera_jogo, "zoom", camera_base_zoom, 0.90).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	yield(tw, "finished")

#	if mapa_label != null:
#		mapa_label.position = Vector2(748, 460)
#		mapa_label.visible = true

#		var tw_mapa_label := create_tween()
#		tw_mapa_label.tween_property(mapa_label, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
#		await tw_mapa_label.finished

	# A MONTAGEM DOS PINOS APARECE TAMBÉM NA TV BOX. Antes o Android pulava
	# a cascata, a entrada da bola e o banner (os pinos "brotavam" prontos)
	# só para o banner não segurar o controle. Agora a montagem roda igual
	# no PC e na TV Box (~1 s), e o banner "ROUND 1" corre por cima sem
	# prender o controle.
	_g3_estado = animar_pinos_em_cascata()
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")
	_g3_estado = animar_bola_entrada()
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")
	mostrar_round_banner_intro(1)

	intro_em_andamento = false
	aceitando_input = true


## A FAIXA DE CADA TECLA: os pinos que a bola daquela tecla alcança de
## frente (posição do pino na pista contra o ponto em que a bola de cada
## tecla chega). Cada pino é de UMA faixa só:
##   Z (esquerda) ...... 7
##   X (meio esquerdo) . 2, 4, 8
##   C (centro) ........ 1, 5
##   V (meio direito) .. 3, 6, 9
##   B (extremas) ...... 10
## A bola só começa a derrubar por um pino da faixa dela (depois um pino
## pode derrubar o vizinho, como sempre). Faixa vazia = a bola passa reto:
## ERRO. Antes, com a faixa vazia, a jogada "puxava" o pino mais próximo
## (Z derrubava o 7, depois o 4, depois o 2; X e V caíam em qualquer pino
## que sobrasse) — jogar de novo na mesma tecla nunca errava.
const PINOS_DA_FAIXA = {
	"Z": [7],
	"X": [2, 4, 8],
	"C": [1, 5],
	"V": [3, 6, 9],
	"B": [10],
}


## Os pinos em pé da faixa da tecla, do mais perto do jogador ao do fundo.
func _pinos_da_faixa_em_pe(tecla: String) -> Array:
	var lista: Array = []
	for numero in PINOS_DA_FAIXA.get(tecla, []):
		var p = obter_pino_por_numero(int(numero))
		if p != null and not p.derrubado:
			lista.append(p)
	return lista


## O PRIMEIRO PINO QUE A BOLA TOCA: o primeiro do caminho da bola que é da
## faixa da tecla; sem nenhum no caminho, o da faixa mais perto do jogador.
## Nunca um pino de fora da faixa.
func _primeiro_pino_da_faixa(ponto_impacto: Vector2):
	var da_faixa: Array = _pinos_da_faixa_em_pe(ultima_tecla_jogada)
	if da_faixa.empty():
		return null
	for item in obter_pinos_no_caminho_bola(ponto_impacto):
		if item["pin"] in da_faixa:
			return item["pin"]
	return da_faixa[0]


func obter_pino_por_lista_preferida(lista: Array, ponto_impacto: Vector2):
	var melhor = null
	var melhor_score: float = INF

	for numero in lista:
		var p = obter_pino_por_numero(int(numero))
		if p == null or p.derrubado:
			continue

		var dx: float = abs(p.global_position.x - ponto_impacto.x)
		var dy: float = abs(p.global_position.y - ponto_impacto.y)

		var score: float = dx * 1.35 + dy * 0.55
		if score < melhor_score:
			melhor_score = score
			melhor = p

	return melhor


func obter_pino_principal_por_jogada(ponto_impacto: Vector2):
	match ultima_tecla_jogada:
		"Z":
			return obter_pino_por_lista_preferida([7, 4, 2, 1, 8, 5], ponto_impacto)
		"X":
			return obter_pino_por_lista_preferida([8, 4, 2, 5, 7, 1], ponto_impacto)
		"C":
			return obter_pino_por_lista_preferida([5, 1, 8, 9, 4, 6, 2, 3], ponto_impacto)
		"V":
			return obter_pino_por_lista_preferida([9, 6, 3, 5, 10, 1], ponto_impacto)
		"B":
			return obter_pino_por_lista_preferida([10, 6, 3, 1, 9, 5], ponto_impacto)

	return obter_pino_mais_proximo_livre(ponto_impacto)


func obter_pino_mais_proximo_livre(ponto_impacto: Vector2):
	var melhor = null
	var melhor_score: float = INF

	for p in pins:
		if p == null or p.derrubado:
			continue

		var dx: float = abs(p.global_position.x - ponto_impacto.x)
		var dy: float = abs(p.global_position.y - ponto_impacto.y)
		var score: float = dx * 1.15 + dy * 0.75

		if score < melhor_score:
			melhor_score = score
			melhor = p

	return melhor


func _obter_pin_forcado_da_jogada(ponto_impacto: Vector2):
	if ultima_tecla_jogada == "Z":
		for numero in PINOS_DA_FAIXA["Z"]:
			var p = obter_pino_por_numero(numero)
			if p != null and not p.derrubado:
				return p

	if ultima_tecla_jogada == "B":
		for numero in PINOS_DA_FAIXA["B"]:
			var p = obter_pino_por_numero(numero)
			if p != null and not p.derrubado:
				return p

	if ultima_tecla_jogada == "C":
		if contar_pinos_em_pe() >= 8:
			var p1 = obter_pino_por_numero(1)
			if p1 != null and not p1.derrubado:
				return p1

	return null


func _limite_quedas_por_tecla() -> int:
	match ultima_tecla_jogada:
		"Z", "B":
			return 3
		"X", "V":
			return 6
		"C":
			return 10
	return 5


func _bonus_energia_inicial_por_contexto(principal) -> float:
	if principal == null:
		return 0.0

	if ultima_tecla_jogada == "C":
		if contar_pinos_em_pe() >= 8 and principal.numero == 1:
			return 0.24
		if principal.numero == 5:
			return 0.12

	if ultima_tecla_jogada == "Z":
		if principal.numero == 7:
			return 0.22
		if principal.numero == 4:
			return 0.10

	if ultima_tecla_jogada == "B":
		if principal.numero == 10:
			return 0.22
		if principal.numero == 6:
			return 0.10

	if ultima_tecla_jogada == "X" and principal.numero in [2, 4]:
		return 0.12

	if ultima_tecla_jogada == "V" and principal.numero in [3, 6]:
		return 0.12

	return 0.0


func _energia_minima_para_cair(numero_pin: int) -> float:
	match ultima_tecla_jogada:
		"Z", "B":
			if numero_pin in [7, 10]:
				return 0.20 if _garantia_borda_na_abertura() else 0.30
			if numero_pin in [4, 6]:
				return 0.44
			if numero_pin in [8, 9]:
				return 0.48
			return 0.54
		"X", "V":
			if numero_pin in [2, 3, 4, 6]:
				return 0.24
			if numero_pin in [7, 9]:
				return 0.18
			if numero_pin in [8, 10]:
				return 0.22
			return 0.38
		"C":
			if numero_pin == 1:
				return 0.15
			if numero_pin in [2, 3, 5]:
				return 0.18
			if numero_pin in [4, 6]:
				return 0.20
			if numero_pin in [8, 9]:
				return 0.17
			if numero_pin in [7, 10]:
				return 0.14
			return 0.28
	return 0.30



func _max_secundarios_por_tecla() -> int:
	var em_pe_total: int = contar_pinos_em_pe()

	match ultima_tecla_jogada:
		"Z", "B":
			if em_pe_total <= 3:
				return 1
			return 2
		"X", "V":
			if em_pe_total <= 3:
				return 1
			elif em_pe_total <= 6:
				return 3
			return 5
		"C":
			if em_pe_total <= 3:
				return 2
			elif em_pe_total <= 6:
				return 5
			return 8

	return 2

func _energia_extra_de_cadeia(origem_pin, alvo_pin) -> float:
	if origem_pin == null or alvo_pin == null:
		return 0.0

	match ultima_tecla_jogada:
		"C":
			if origem_pin.numero == 1 and alvo_pin.numero in [2, 3, 5]:
				return 0.22
			if origem_pin.numero == 5 and alvo_pin.numero in [4, 6, 8, 9]:
				return 0.16
			if alvo_pin.numero in [7, 10]:
				return 0.08

		"X":
			if origem_pin.numero in [2, 4] and alvo_pin.numero in [4, 5, 7, 8]:
				return 0.12

		"V":
			if origem_pin.numero in [3, 6] and alvo_pin.numero in [5, 6, 9, 10]:
				return 0.12

		"Z":
			if origem_pin.numero == 7 and alvo_pin.numero in [4, 8]:
				return 0.08

		"B":
			if origem_pin.numero == 10 and alvo_pin.numero in [6, 9]:
				return 0.08

	return 0.0

func derrubar_pino_com_origem(pin, ponto_impacto: Vector2, intensidade: float = 1.0) -> void:
	if pin == null or pin.derrubado:
		return

	var lado: String = obter_lado_queda_principal(ponto_impacto, pin)
	pin.cair(lado, intensidade, ponto_impacto)


func obter_secundarios_do_principal(pin_principal, max_secundarios: int = 6) -> Array:
	var lista: Array = []
	if pin_principal == null:
		return lista

	for numero in vizinhos_pinos.get(pin_principal.numero, []):
		var p = obter_pino_por_numero(int(numero))
		if p == null or p.derrubado:
			continue
		lista.append(p)

	if ultima_tecla_jogada == "C":
		for numero in [7, 8, 9, 10]:
			var p2 = obter_pino_por_numero(numero)
			if p2 != null and not p2.derrubado and not lista.has(p2):
				lista.append(p2)

	elif ultima_tecla_jogada == "X":
		for numero in [8, 7, 5, 4, 2]:
			var p3 = obter_pino_por_numero(numero)
			if p3 != null and not p3.derrubado and not lista.has(p3):
				lista.append(p3)

	elif ultima_tecla_jogada == "V":
		for numero in [9, 10, 5, 6, 3]:
			var p4 = obter_pino_por_numero(numero)
			if p4 != null and not p4.derrubado and not lista.has(p4):
				lista.append(p4)

	_ordem_ponto = pin_principal.global_position
	lista.sort_custom(self, "_ordem_no_por_distancia")

	if lista.size() > max_secundarios:
		lista.resize(max_secundarios)

	return lista


func _empurrar_pinos_proximos_da_passagem(ponto: Vector2, principal: Node, forca: float) -> void:
	for p in pins:
		if p == null:
			continue
		if p == principal:
			continue
		if p.derrubado:
			continue

		var n: int = int(p.numero)

		# BLOQUEIO CRUZADO:
		# V não pode derrubar 2.
		# X não pode derrubar 3.
		if ultima_tecla_jogada == "V" and n == 2:
			continue
		if ultima_tecla_jogada == "X" and n == 3:
			continue

		# Laterais médias só podem encostar no próprio lado + fundo correto.
		if ultima_tecla_jogada == "X" and not n in [4, 5, 7, 8, 9]:
			continue
		if ultima_tecla_jogada == "V" and not n in [5, 6, 8, 9, 10]:
			continue

		var dist: float = p.global_position.distance_to(ponto)

		if dist > 92.0:
			continue

		var dir: Vector2 = (p.global_position - ponto).normalized()
		var intensidade: float = clamp((92.0 - dist) / 92.0, 0.0, 1.0)
		intensidade *= forca * 0.34

		if p.has_method("receber_forca"):
			p.receber_forca(dir, intensidade, ponto)



## A MONTAGEM DOS PINOS: a máquina baixa o rack, fileira por fileira, do
## fundo para a frente (7-10, 4-6, 2-3, 1). Cada pino desce do alto, aparece
## e assenta com um quique curto. Roda igual no PC e na TV Box.
func animar_pinos_em_cascata() -> void:
	var fileiras: Array = [[7, 8, 9, 10], [4, 5, 6], [2, 3], [1]]
	var ultimo: SceneTreeTween = null

	for fileira in fileiras:
		for numero in fileira:
			var p = obter_pino_por_numero(int(numero))
			if p == null or not is_instance_valid(p):
				continue

			var base_pos: Vector2 = p.position
			if p.has_meta("intro_base_pos"):
				base_pos = p.get_meta("intro_base_pos")

			var tw: SceneTreeTween = create_tween()
			tw.set_parallel(true)
			if p is CanvasItem:
				tw.tween_property(p, "modulate:a", 1.0, 0.16)
			if p is Node2D:
				tw.tween_property(p, Compat.prop(p, "position"), base_pos, 0.34)\
					.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			ultimo = tw
			yield(get_tree().create_timer(0.03), "timeout")
		yield(get_tree().create_timer(0.07), "timeout")

	if ultimo != null and ultimo.is_valid():
		yield(ultimo, "finished")
	# Garante cada pino exatamente no lugar, mesmo se um quadro longo da TV
	# Box tiver cortado a animação no meio.
	for p in pins:
		if p != null and is_instance_valid(p) and p is Node2D and p.has_meta("intro_base_pos"):
			p.position = p.get_meta("intro_base_pos")
			p.modulate.a = 1.0


func animar_bola_entrada() -> void:
	if bola == null or not (bola is Node2D):
		return

	var base_pos: Vector2 = bola.position
	if bola.has_meta("intro_base_pos"):
		base_pos = bola.get_meta("intro_base_pos")

	var tw: SceneTreeTween = create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)

	if bola is CanvasItem:
		tw.parallel().tween_property(bola, "modulate:a", 1.0, 0.20)

	tw.parallel().tween_property(bola, Compat.prop(bola, "position"), base_pos, 0.26)

	yield(tw, "finished")


func mostrar_round_banner_intro(round_num: int) -> void:
	if round_label == null:
		return

	round_label.text = "ROUND %d" % round_num
	round_label.rect_scale = Vector2(0.72, 0.72)
	round_label.modulate = Color(0.55, 0.92, 1.0, 0.0)

	var tw: SceneTreeTween = create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)

	tw.tween_property(round_label, "modulate", Color(0.55, 0.92, 1.0, 1.0), 0.18)
	tw.parallel().tween_property(round_label, "rect_scale", Vector2(1.0, 1.0), 0.18)

	# segura mais na intro
	tw.tween_interval(1.10)

	tw.tween_property(round_label, "modulate", Color(0.55, 0.92, 1.0, 0.0), 0.24)
	tw.parallel().tween_property(round_label, "rect_scale", Vector2(1.03, 1.03), 0.24)

	yield(tw, "finished")


func obter_pino_por_numero(numero: int):
	for p in pins:
		if p != null and p.numero == numero:
			return p
	return null



func organizar_pinos() -> void:
	if pins_container == null:
		return

	var centro_x: float = 512.0
	var base_y: float = 755.0

	var espacamento_x: float = 74.0
	var espacamento_y: float = 63.0

	var cfgs: Dictionary = {
		1:  {"pos": Vector2(0.0, 0.0), "scale": 1.00, "z": 72},

		2:  {"pos": Vector2(-espacamento_x * 0.5, -espacamento_y), "scale": 0.988, "z": 66},
		3:  {"pos": Vector2( espacamento_x * 0.5, -espacamento_y), "scale": 0.988, "z": 66},

		4:  {"pos": Vector2(-espacamento_x, -espacamento_y * 2.0), "scale": 0.972, "z": 60},
		5:  {"pos": Vector2(0.0,           -espacamento_y * 2.0), "scale": 0.972, "z": 60},
		6:  {"pos": Vector2( espacamento_x, -espacamento_y * 2.0), "scale": 0.972, "z": 60},

		7:  {"pos": Vector2(-espacamento_x * 1.5, -espacamento_y * 3.0), "scale": 0.952, "z": 54},
		8:  {"pos": Vector2(-espacamento_x * 0.5, -espacamento_y * 3.0), "scale": 0.952, "z": 54},
		9:  {"pos": Vector2( espacamento_x * 0.5, -espacamento_y * 3.0), "scale": 0.952, "z": 54},
		10: {"pos": Vector2( espacamento_x * 1.5, -espacamento_y * 3.0), "scale": 0.952, "z": 54}
	}

	for p in pins:
		if p == null or not cfgs.has(p.numero):
			continue

		var cfg: Dictionary = cfgs[p.numero]
		var pos: Vector2 = cfg["pos"]

		p.position = Vector2(centro_x + pos.x, base_y + pos.y)
		p.fator_profundidade = float(cfg["scale"])
		Compat.z(p, int(cfg["z"]))

		if p.has_method("atualizar_posicao_base"):
			p.atualizar_posicao_base()

		if p.has_method("recalcular_visual"):
			p.recalcular_visual()
			
			

func resetar_pinos() -> void:
	for p in pins:
		if p != null:
			if p.has_method("atualizar_posicao_base"):
				p.atualizar_posicao_base()
			if p.has_method("resetar"):
				p.resetar()

	marcar_hud_como_suja()
	atualizar_placar()


func _distancia_ponto_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len2: float = ab.length_squared()
	if ab_len2 <= 0.0001:
		return p.distance_to(a)

	var t: float = clamp((p - a).dot(ab) / ab_len2, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return p.distance_to(proj)


func _projecao_no_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var comprimento: float = ab.length()
	if comprimento <= 0.0001:
		return 0.0
	return (p - a).dot(ab.normalized())


func _raio_colisao_pin(pin) -> float:
	if pin == null:
		return 22.0

	var area: Vector2 = Vector2(50, 76)
	if pin.has_method("obter_area_colisao"):
		area = pin.obter_area_colisao()

	return max(18.0, min(area.x, area.y) * 0.34)

func _largura_corredor_por_tecla(tecla: String) -> float:
	match tecla:
		"Z", "B":
			return 10.0
		"X", "V":
			return 20.0
		"C":
			return 34.0
	return 12.0


# SUBSTITUA a função faixa_valida_por_tecla por esta:
func faixa_valida_por_tecla(tecla: String) -> Vector2:
	var em_pe: int = contar_pinos_em_pe()
	# Quando poucos pinos restam, amplia a faixa para não perder pinos de fundo
	var ampliacao: float = 0.0
	if em_pe <= 4:
		ampliacao = 30.0
	elif em_pe <= 6:
		ampliacao = 16.0

	match tecla:
		"Z":
			return Vector2(360.0 - ampliacao, 432.0 + ampliacao)
		"X":
			return Vector2(420.0 - ampliacao, 530.0 + ampliacao)
		"C":
			return Vector2(440.0 - ampliacao, 584.0 + ampliacao)
		"V":
			return Vector2(494.0 - ampliacao, 620.0 + ampliacao)
		"B":
			return Vector2(592.0 - ampliacao, 664.0 + ampliacao)
	return Vector2(0.0, 1024.0)


func _energia_base_por_tecla(tecla: String) -> float:
	match tecla:
		"Z", "B":
			return 0.98
		"X", "V":
			return 1.04
		"C":
			return 1.18
	return 1.0



func _raio_propagacao_por_tecla(tecla: String) -> float:
	match tecla:
		"Z", "B":
			return 84.0
		"X", "V":
			return 106.0
		"C":
			return 126.0
	return 96.0


func _bonus_linha_por_tecla(origem, alvo) -> float:
	if origem == null or alvo == null:
		return 1.0

	match ultima_tecla_jogada:
		"C":
			if origem.numero == 1 and alvo.numero in [2, 3, 5]:
				return 1.34
			if origem.numero == 5 and alvo.numero in [4, 6, 8, 9]:
				return 1.22
			if alvo.numero in [7, 10]:
				return 1.08
		"X":
			if origem.numero in [2, 4] and alvo.numero in [4, 5, 7, 8]:
				return 1.20
			if alvo.numero == 1:
				return 0.76
		"V":
			if origem.numero in [3, 6] and alvo.numero in [5, 6, 9, 10]:
				return 1.20
			if alvo.numero == 1:
				return 0.76
		"Z", "B":
			if alvo.numero == 5:
				return 0.70

	return 1.0


func _coletar_pinos_proximos(origem_pin, raio: float) -> Array:
	var lista: Array = []

	for p in pins:
		if p == null or p.derrubado or p == origem_pin:
			continue

		var dist: float = origem_pin.global_position.distance_to(p.global_position)
		if dist <= raio:
			lista.append({"pin": p, "dist": dist})

	lista.sort_custom(self, "_ordem_dist_crescente")

	return lista


func _obter_segmento_trajetoria_bola(ponto_impacto: Vector2) -> Array:
	var inicio = Vector2(centro_pista_x, 980.0)
	if bola != null:
		inicio = bola.global_position

	# Para C, estende o segmento até o fundo do rack (pinos 7-10 ficam em y~613)
	var fim = ponto_impacto
	if ultima_tecla_jogada == "C":
		fim = Vector2(ponto_impacto.x, min(ponto_impacto.y, 580.0))
	elif ultima_tecla_jogada in ["X", "V"]:
		fim = Vector2(ponto_impacto.x, min(ponto_impacto.y, 620.0))

	return [inicio, fim]

func obter_primeiro_pin_atingido_fisico(ponto_impacto: Vector2):
	var impactos: Array = obter_pinos_no_caminho_bola(ponto_impacto)
	if not impactos.empty():
		return impactos[0]["pin"]

	# Fora do caminho, só um pino da faixa da tecla (nunca "puxar" outro).
	var da_faixa: Array = _pinos_da_faixa_em_pe(ultima_tecla_jogada)
	return da_faixa[0] if not da_faixa.empty() else null

func _aplicar_impulso_realista(principal, ponto_impacto: Vector2, forca: float, lateral: float, spin: float) -> void:
	if principal == null:
		return

	var impactos: Array = obter_pinos_no_caminho_bola(ponto_impacto)
	if impactos.empty():
		impactos = [{"pin": principal, "proj": 0.0, "dist": 0.0}]

	var origem_trajeto: Vector2 = _obter_segmento_trajetoria_bola(ponto_impacto)[0]
	var dir_base: Vector2 = (ponto_impacto - origem_trajeto).normalized()
	if dir_base.length() <= 0.001:
		dir_base = Vector2(lateral, -1.0).normalized()

	var energia_inicial: float = clamp(_energia_base_por_tecla(ultima_tecla_jogada) * forca, 0.98, 1.30)

	match ultima_tecla_jogada:
		"Z", "B":
			energia_inicial = clamp(energia_inicial, 0.96, 1.02)
		"X", "V":
			energia_inicial = clamp(energia_inicial, 1.00, 1.10)
		"C":
			energia_inicial = clamp(energia_inicial, 1.18, 1.30)

	var max_diretos: int = 1
	match ultima_tecla_jogada:
		"Z", "B":
			max_diretos = 1
		"X", "V":
			max_diretos = 2
		"C":
			max_diretos = 6

	if contar_pinos_em_pe() <= 3:
		max_diretos = 1

	var pins_processados: Array = []
	var total_processados: int = 0

	for item in impactos:
		if total_processados >= max_diretos:
			break

		var pin = item["pin"]
		if pin == null or pin.derrubado:
			continue

		var energia_pin: float = energia_inicial

		if total_processados == 1:
			energia_pin *= 0.97
		elif total_processados == 2:
			energia_pin *= 0.93
		elif total_processados >= 3:
			energia_pin *= 0.88

		if ultima_tecla_jogada == "C":
			if pin.numero == 1:
				energia_pin += 0.14
			elif pin.numero in [2, 3]:
				energia_pin += 0.12
			elif pin.numero == 5:
				energia_pin += 0.16
			elif pin.numero in [4, 6]:
				energia_pin += 0.18
			elif pin.numero in [8, 9]:
				energia_pin += 0.30
			elif pin.numero in [7, 10]:
				energia_pin += 0.38

		if pin.has_method("receber_forca"):
			pin.receber_forca(dir_base, energia_pin, ponto_impacto)

		pins_processados.append({
			"pin": pin,
			"energia": energia_pin
		})

		total_processados += 1

	if not pins_processados.empty():
		yield(get_tree(), "idle_frame")

	for item in pins_processados:
		var pin = item["pin"]
		var energia_pin: float = float(item["energia"])
		if pin != null:
			_propagar_colisao_curta(pin, energia_pin * 1.08, dir_base)

	if ultima_tecla_jogada == "C" and contar_pinos_em_pe() >= 6:
		yield(get_tree(), "idle_frame")

		for num in [5, 4, 6, 2, 3, 8, 9, 7, 10]:
			var p2 = obter_pino_por_numero(num)
			if p2 != null and not p2.derrubado:
				var dir_fundo: Vector2 = Vector2(0, -1)
				var energia_extra: float = 0.88

				if num in [8, 9]:
					energia_extra = 0.98
				elif num in [7, 10]:
					energia_extra = 1.08

				if p2.has_method("receber_forca"):
					p2.receber_forca(dir_fundo, energia_extra, ponto_impacto)

				_propagar_colisao_curta(p2, energia_extra * 0.94, dir_fundo)


func _carregar_config_jogadores() -> void:
	quantidade_jogadores = 1

	if has_node("/root/GameConfig"):
		quantidade_jogadores = int(get_node("/root/GameConfig").jogadores)

	quantidade_jogadores = clamp(quantidade_jogadores, 1, 2)

	jogador_atual = 1
	round_base_por_jogador = 3
	total_rounds = round_base_por_jogador * quantidade_jogadores



func _resolver_jogada_no_rack(principal, ponto_contato_real: Vector2, forca: float, lateral: float, spin: float, pinos_em_pe_antes: Dictionary) -> void:
	var _g3_estado = null
	if principal == null:
		return

	if principal.has_method("destacar_acerto"):
		principal.destacar_acerto()

	if principal.has_method("impacto_visual"):
		principal.impacto_visual(clamp(forca, 0.95, 1.18), ponto_contato_real)

	_empurrar_pinos_proximos_da_passagem(ponto_contato_real, principal, forca)
	_g3_estado = _aplicar_impulso_realista(principal, ponto_contato_real, forca, lateral, spin)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")

	if ultima_tecla_jogada in ["X", "V"]:
		_g3_estado = _resolver_lateral_xv_de_verdade(ponto_contato_real)
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")

	if ultima_tecla_jogada == "C":
		_g3_estado = _forcar_strike_central_se_preciso(ponto_contato_real)
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")

	if not (ultima_tecla_jogada in ["X", "V"]):
		_aplicar_quase_queda_ao_redor(principal, -1, ponto_contato_real)

	if bola != null and bola.has_method("tocar_passagem_por_cima_dos_pinos"):
		_g3_estado = bola.tocar_passagem_por_cima_dos_pinos(
			ponto_contato_real,
			principal.z_index,
			clamp(forca, 0.98, 1.20)
		)
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")

	yield(get_tree(), "idle_frame")
	marcar_hud_como_suja()
	atualizar_mapa_visual()
	atualizar_placar()


func _forcar_fundo_xv_agora(ponto_impacto: Vector2) -> void:
	if ultima_tecla_jogada != "X" and ultima_tecla_jogada != "V":
		return
 
	var alvos: Array = []
 
	if bloquear_spare_pos_c:
		var p5 = obter_pino_por_numero(5)
		if p5 != null and not p5.derrubado:
			alvos.append(5)
		if ultima_tecla_jogada == "X":
			alvos.append(8)
		else:
			alvos.append(9)
	else:
		if ultima_tecla_jogada == "X":
			alvos.append(8)
		else:
			alvos.append(9)
 
	for alvo_num in alvos:
		var p = obter_pino_por_numero(alvo_num)
		if p == null or p.derrubado:
			continue
 
		# ── NOVIDADE: delay proporcional à distância do pino de fundo ──
		var dist_ao_impacto: float = p.global_position.distance_to(ponto_impacto)
		var delay_fundo: float = clamp(dist_ao_impacto / 520.0, 0.04, 0.22)
 
		var anim: String = "strike"
		if alvo_num == 8:
			anim = "down_rt"
		elif alvo_num == 9:
			anim = "down_left"
 
		if p.has_method("cair_voando"):
			# Passa o delay para cair_voando — o pino espera antes de cair
			p.cair_voando(anim, 3.0, ponto_impacto, delay_fundo)
		elif p.has_method("forcar_queda_imediata"):
			# Fallback sem delay (forcar_queda_imediata é instantâneo)
			yield(get_tree().create_timer(delay_fundo), "timeout")
			p.forcar_queda_imediata(anim, 3.0, ponto_impacto)
		elif p.has_method("cair"):
			p.cair(anim, 3.0, ponto_impacto)
 
	yield(get_tree(), "idle_frame")
	marcar_hud_como_suja()
	atualizar_mapa_visual()
	atualizar_placar()



func _forcar_strike_central_se_preciso(ponto_contato_real: Vector2) -> void:
	# Bolinha no rack completo: strike garantido, independentemente da
	# posicao visual da bola ou da ordem das animacoes de impacto.
	if ultima_tecla_jogada != "C" or tentativa_atual != 1 or pinos_antes_da_jogada != 10:
		return

	var sobreviventes_escolhidos: Array = []
	pinos_protegidos_sobreviventes.clear()

	var grupos: Array = [
		[1],
		[2, 3],
		[4, 5, 6],
		[7, 8, 9, 10]
	]

	for grupo_idx in range(grupos.size()):
		for num in grupos[grupo_idx]:
			if num in sobreviventes_escolhidos:
				continue

			var p = obter_pino_por_numero(num)
			if p == null or p.derrubado:
				continue

			var anim: String = "strike"
			if num in [2, 4, 7, 8]:
				anim = "down_rt"
			elif num in [3, 6, 9, 10]:
				anim = "down_left"

			var intensidade: float = 1.34
			match num:
				8, 9:  intensidade = 1.44
				7, 10: intensidade = 1.56
				4, 6:  intensidade = 1.38
				2, 3:  intensidade = 1.30

			var delay_interno: float = rand_range(0.0, 0.03) * float(grupo_idx)

			if p.has_method("cair_voando"):
				p.cair_voando(anim, intensidade, ponto_contato_real, delay_interno)
			elif p.has_method("cair"):
				p.cair(anim, intensidade, ponto_contato_real)

		var pausa_grupo: float = lerp(0.055, 0.095, float(grupo_idx) / 3.0)
		yield(get_tree().create_timer(pausa_grupo), "timeout")

	# ── Reseta sobreviventes uma segunda vez após as quedas ──
	# (caso algum delay da física ainda os tenha derrubado durante o loop)
	yield(get_tree().create_timer(0.15), "timeout")
	for num in sobreviventes_escolhidos:
		var p = obter_pino_por_numero(num)
		if p != null:
			p.resetar()
			if p.has_method("atualizar_posicao_base"):
				p.atualizar_posicao_base()

	yield(get_tree(), "idle_frame")
	marcar_hud_como_suja()
	
	# ── Limpa a proteção APÓS tudo estar resolvido ──
	pinos_protegidos_sobreviventes.clear()



# Efeito de onda radial nos pinos ao redor do ponto de impacto
func _efeito_onda_pinos_derrubados(ponto_impacto: Vector2, lista_derrubados: Array) -> void:
	# Ordena pela distância ao ponto de impacto para onda saindo do centro
	var ordenados: Array = lista_derrubados.duplicate()
	_ordem_ponto = ponto_impacto
	ordenados.sort_custom(self, "_ordem_pin_por_distancia")

	for i in range(ordenados.size()):
		var item: Dictionary = ordenados[i]
		var p = item["pin"]
		if p == null: continue

		# Abalo visual mesmo em pinos já caídos para simular tremor no chão
		if p.has_method("abalo_lateral"):
			var intensidade_abalo: float = clamp(1.2 - float(i) * 0.08, 0.4, 1.2)
			p.abalo_lateral(intensidade_abalo)

		yield(get_tree().create_timer(0.028), "timeout")


func obter_pinos_em_pe() -> Array:
	var vivos: Array = []
	for p in pins:
		if p != null and not p.derrubado:
			vivos.append(p)
	return vivos


func contar_pinos_em_pe() -> int:
	var em_pe: int = 0
	for p in pins:
		if p != null and not p.derrubado:
			em_pe += 1
	return em_pe


func obter_pin_extremo(tecla: String):
	if tecla != "Z" and tecla != "B":
		return null
	var da_faixa: Array = _pinos_da_faixa_em_pe(tecla)
	return da_faixa[0] if not da_faixa.empty() else null


func obter_pino_alvo_medio(tecla: String):
	var vivos: Array = obter_pinos_em_pe()
	if vivos.empty():
		return null

	var prioridade: Array = []

	if tecla == "X":
		prioridade = [8, 4, 2]
	elif tecla == "V":
		prioridade = [9, 6, 3]
	else:
		prioridade = [1, 5]

	for alvo_num in prioridade:
		for p in vivos:
			if p != null and int(p.numero) == alvo_num:
				return p

	# Nenhum pino da faixa em pé: nada a mirar (a jogada vai errar).
	return null


func obter_unico_pino_restante():
	var vivos: Array = obter_pinos_em_pe()
	if vivos.size() == 1:
		return vivos[0]
	return null


func ajustar_ponto_impacto_por_contexto(ponto: Vector2) -> Vector2:
	var ajustado: Vector2 = ponto
	var vivos: Array = obter_pinos_em_pe()

	if vivos.empty():
		return ajustado

	var unico = obter_unico_pino_restante()
	if unico != null:
		if tecla_alinha_com_pin(ultima_tecla_jogada, unico):
			ajustado.x = lerp(ajustado.x, unico.global_position.x, 0.18)
		return ajustado

	if ultima_tecla_jogada == "B" or ultima_tecla_jogada == "Z":
		var extremo = obter_pin_extremo(ultima_tecla_jogada)
		if extremo != null and tecla_alinha_com_pin(ultima_tecla_jogada, extremo):
			var ajuda_lateral: float = 0.08
			if contar_pinos_em_pe() <= 5:
				ajuda_lateral = 0.05
			if contar_pinos_em_pe() <= 3:
				ajuda_lateral = 0.03

			var dx: float = extremo.global_position.x - ajustado.x
			ajustado.x += dx * ajuda_lateral
			ajustado.y = lerp(ajustado.y, extremo.global_position.y + 4.0, 0.10)

	elif ultima_tecla_jogada == "X" or ultima_tecla_jogada == "V":
		var medio = obter_pino_alvo_medio(ultima_tecla_jogada)
		if medio != null:
			var dx2: float = medio.global_position.x - ajustado.x
			ajustado.x += dx2 * 0.12

	elif ultima_tecla_jogada == "C":
		var pin_um = obter_pino_por_numero(1)
		var pin_cinco = obter_pino_por_numero(5)

		if pin_um != null and not pin_um.derrubado:
			ajustado.x = lerp(ajustado.x, centro_pista_x, 0.36)
			ajustado.y = lerp(ajustado.y, pin_um.global_position.y + 10.0, 0.18)

		elif pin_cinco != null and not pin_cinco.derrubado:
			ajustado.x = lerp(ajustado.x, pin_cinco.global_position.x, 0.26)
			ajustado.y = lerp(ajustado.y, pin_cinco.global_position.y + 10.0, 0.18)

		else:
			ajustado.x = lerp(ajustado.x, centro_pista_x, 0.20)

	return ajustado


func obter_fator_profundidade_pin(pin) -> float:
	if pin == null:
		return 1.0
	if "fator_profundidade" in pin:
		return float(pin.fator_profundidade)
	return 1.0


func score_pin_para_impacto(pin, ponto: Vector2) -> float:
	if pin == null or pin.derrubado:
		return 99999.0

	var area: Vector2 = Vector2(40, 56)
	if pin.has_method("obter_area_colisao"):
		area = pin.obter_area_colisao()

	var dx: float = ponto.x - pin.global_position.x
	var dy: float = ponto.y - pin.global_position.y

	var nx: float = abs(dx) / max(area.x, 1.0)
	var ny: float = abs(dy) / max(area.y, 1.0)

	var profundidade: float = obter_fator_profundidade_pin(pin)
	var peso_lateral: float = lerp(1.00, 1.16, clamp((1.0 - profundidade) * 2.2, 0.0, 1.0))
	var peso_frente: float = lerp(1.08, 0.98, clamp((1.0 - profundidade) * 2.2, 0.0, 1.0))

	return nx * peso_lateral + ny * peso_frente



func obter_candidatos_impacto(ponto: Vector2) -> Array:
	var lista: Array = []

	for p in pins:
		if p == null or p.derrubado:
			continue

		var area: Vector2 = Vector2(40, 56)
		if p.has_method("obter_area_colisao"):
			area = p.obter_area_colisao()

		var dx: float = ponto.x - p.global_position.x
		var dy: float = ponto.y - p.global_position.y
		var dist: float = p.global_position.distance_to(ponto)
		var score: float = score_pin_para_impacto(p, ponto)

		lista.append({
			"pin": p,
			"dx": dx,
			"dy": dy,
			"score": score,
			"dist": dist,
			"alcance_x": area.x,
			"alcance_y": area.y,
			"prof": obter_fator_profundidade_pin(p)
		})

	lista.sort_custom(self, "_ordem_score_crescente")
	return lista


func limiar_colisao_para_pin(pin_num: int, em_pe_total: int) -> float:
	var t: float = 0.92

	match pin_num:
		7, 10:
			t = 0.84
		4, 6:
			t = 0.89
		2, 3, 8, 9:
			t = 0.96
		1:
			t = 0.94
		5:
			t = 0.98

	if em_pe_total <= 2:
		t -= 0.02
	elif em_pe_total <= 4:
		t += 0.03

	if em_pe_total >= 8:
		match ultima_tecla_jogada:
			"X", "V":
				t += 0.06
			"C":
				t += 0.01
			"Z", "B":
				t -= 0.04

	if em_pe_total <= 3:
		match ultima_tecla_jogada:
			"Z", "B":
				t -= 0.07
			"X", "V":
				t -= 0.02
			"C":
				t -= 0.03

	return t
	

func prioridade_principal_por_tecla(tecla: String, em_pe_total: int) -> Array:
	if em_pe_total >= 8:
		match tecla:
			"Z":
				return [7, 4, 2]
			"X":
				return [8, 4, 2, 7, 5]
			"C":
				return [1, 5, 2, 3]
			"V":
				return [9, 6, 3, 10, 5]
			"B":
				return [10, 6, 3]

	elif em_pe_total >= 5:
		match tecla:
			"Z":
				return [7, 4, 2]
			"X":
				return [8, 4, 5, 2, 7]
			"C":
				return [1, 5, 8, 9, 2, 3]
			"V":
				return [9, 6, 5, 3, 10]
			"B":
				return [10, 6, 3]

	else:
		match tecla:
			"Z":
				return [7, 4, 2]
			"X":
				return [8, 4, 5, 2]
			"C":
				return [1, 5, 2, 3]
			"V":
				return [9, 6, 5, 3]
			"B":
				return [10, 6, 3]

	return []


func selecionar_pin_principal(ponto_impacto: Vector2):
	var vivos: Array = obter_pinos_em_pe()
	if vivos.empty():
		return null

	var prioridade: Array = prioridade_principal_por_tecla(ultima_tecla_jogada, vivos.size())
	var melhor = null
	var melhor_score: float = INF

	for num in prioridade:
		var p = obter_pino_por_numero(int(num))
		if p == null or p.derrubado:
			continue

		var dx: float = abs(p.global_position.x - ponto_impacto.x)
		var dy: float = abs(p.global_position.y - ponto_impacto.y)

		var score: float = dx * 1.22 + dy * 0.72

		# Z/B precisam ficar PRESOS na borda
		if ultima_tecla_jogada == "Z":
			if p.numero == 7:
				score -= 30.0
			elif p.numero == 4:
				score -= 18.0
			elif p.numero == 2:
				score -= 10.0
			else:
				score += 18.0

		elif ultima_tecla_jogada == "B":
			if p.numero == 10:
				score -= 30.0
			elif p.numero == 6:
				score -= 18.0
			elif p.numero == 3:
				score -= 10.0
			else:
				score += 18.0

		elif ultima_tecla_jogada == "X":
			if p.numero in [8, 4, 2]:
				score -= 10.0

		elif ultima_tecla_jogada == "V":
			if p.numero in [9, 6, 3]:
				score -= 10.0

		elif ultima_tecla_jogada == "C":
			if p.numero == 1:
				score -= 18.0
			elif p.numero == 5:
				score -= 8.0

		if score < melhor_score:
			melhor_score = score
			melhor = p

	if melhor != null:
		return melhor

	return null



func obter_ponto_contato_ajustado() -> Vector2:
	match ultima_tecla_jogada:
		"Z":
			var p = obter_pino_por_numero(7)
			return p.global_position if p != null else Vector2(442, 570)
		"X":
			var p = obter_pino_por_numero(8)
			return p.global_position if p != null else Vector2(474, 570)
		"C":
			var p = obter_pino_por_numero(5)
			return p.global_position if p != null else Vector2(512, 642)
		"V":
			var p = obter_pino_por_numero(9)
			return p.global_position if p != null else Vector2(550, 570)
		"B":
			var p = obter_pino_por_numero(10)
			return p.global_position if p != null else Vector2(582, 570)

	return Vector2(512, 642)


func obter_secundarios_fortes(pin_principal) -> Array:
	var lista: Array = []
	if pin_principal == null:
		return lista

	for numero in vizinhos_pinos.get(pin_principal.numero, []):
		var p = obter_pino_por_numero(int(numero))
		if p == null or p.derrubado:
			continue
		lista.append(p)

	_ordem_ponto = pin_principal.global_position
	lista.sort_custom(self, "_ordem_no_por_distancia")

	return lista
	


func calcular_ponto_contato_no_pin(pin, ponto_impacto: Vector2) -> Vector2:
	if pin == null:
		return ponto_impacto

	var area: Vector2 = Vector2(38, 52)
	if pin.has_method("obter_area_colisao"):
		area = pin.obter_area_colisao()

	var dir: Vector2 = pin.global_position - ponto_impacto
	if dir.length() < 0.001:
		dir = Vector2(0, 1)
	else:
		dir = dir.normalized()

	var fator: float = 0.18
	var offset_y: float = 7.0

	match pin.numero:
		1:
			fator = 0.16
			offset_y = 5.5
		2, 3:
			fator = 0.15
			offset_y = 5.0
		4, 5, 6:
			fator = 0.18
			offset_y = 7.0
		_:
			fator = 0.20
			offset_y = 7.5

	return pin.global_position - dir * min(area.x, area.y) * fator + Vector2(0, offset_y)
	

func intensidade_camera_por_impacto(lista: Array) -> float:
	if lista.empty():
		return 5.2

	var total: float = 0.0
	for item in lista:
		total += float(item["peso"])

	return clamp(5.2 + total * 0.85, 5.2, 12.0)


func aplicar_efeito_proximidade_sem_colisao(ponto_impacto: Vector2, lateral: float) -> void:
	var lista: Array = obter_candidatos_impacto(ponto_impacto)
	if lista.empty():
		return

	var info: Dictionary = lista[0]
	var pin = info["pin"]
	var score: float = float(info["score"])

	if pin == null:
		return

	if score > 1.45:
		return

	if pin.has_method("abalo_lateral"):
		var intensidade: float = clamp(1.45 - score, 0.20, 0.60)
		pin.abalo_lateral(intensidade)


func gerar_mapa_pinos() -> String:
	return "MAPA DOS PINOS"



func atualizar_placar() -> void:
	var em_pe: int = contar_pinos_em_pe()
	var caidos_round: int = clamp(pinos_derrubados_no_round, 0, 10)

	if hud_score_em_pe != null:
		hud_score_em_pe.text = str(em_pe)
		_aplicar_fonte_painel(hud_score_em_pe, 44, COR_TEXTO_GREEN, 6)

	if hud_score_caidos != null:
		hud_score_caidos.text = str(caidos_round)
		_aplicar_fonte_painel(hud_score_caidos, 44 if quantidade_jogadores <= 1 else 42, COR_TEXTO_ORANGE, 6)

	if quantidade_jogadores > 1:
		var p1: int = total_pinos_jogador(1)
		var p2: int = total_pinos_jogador(2)

		if not jogo_finalizado and not transicao_round_em_andamento:
			if jogador_atual == 1:
				p1 += pinos_derrubados_no_round
			else:
				p2 += pinos_derrubados_no_round

		var cor_p1: Color = COR_TEXTO_BLUE if jogador_atual == 1 else Color(0.12, 0.28, 0.60, 0.72)
		var cor_p2: Color = Color(1.0, 0.20, 0.18) if jogador_atual == 2 else Color(0.55, 0.18, 0.16, 0.72)

		if hud_score_player_1_nome != null:
			hud_score_player_1_nome.text = "★ PLAYER 1  •  VEZ ★" if jogador_atual == 1 else "PLAYER 1"
			_aplicar_fonte_painel(hud_score_player_1_nome, 13, cor_p1, 4)

		if hud_score_player_1_valor != null:
			hud_score_player_1_valor.text = str(p1)
			_aplicar_fonte_painel(hud_score_player_1_valor, 48, cor_p1, 8)

		if hud_score_player_2_nome != null:
			hud_score_player_2_nome.text = "★ PLAYER 2  •  VEZ ★" if jogador_atual == 2 else "PLAYER 2"
			_aplicar_fonte_painel(hud_score_player_2_nome, 13, cor_p2, 4)

		if hud_score_player_2_valor != null:
			hud_score_player_2_valor.text = str(p2)
			_aplicar_fonte_painel(hud_score_player_2_valor, 48, cor_p2, 8)

		_animar_placar_player_da_vez()

	else:
		if hud_score_total_derrubados != null:
			hud_score_total_derrubados.text = str(total_pinos_derrubados_partida())
			_aplicar_fonte_painel(hud_score_total_derrubados, 54, COR_TEXTO_BRANCO, 8)
			hud_score_total_derrubados.rect_scale = Vector2.ONE




func criar_modal_inatividade() -> void:
	if overlay_inatividade != null:
		return
 
	overlay_inatividade = CanvasLayer.new()
	overlay_inatividade.layer = 120
	add_child(overlay_inatividade)
 
	# Fundo escuro
	modal_inatividade_bg = ColorRect.new()
	Tela.cobrir_auto(modal_inatividade_bg)
	modal_inatividade_bg.color        = Color(0, 0, 0, 0.72)
	modal_inatividade_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_inatividade.add_child(modal_inatividade_bg)
 
	# Panel central
	modal_inatividade_panel      = Panel.new()
	modal_inatividade_panel.rect_size = Vector2(580, 310)
	modal_inatividade_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_inatividade.add_child(modal_inatividade_panel)
 
	var estilo := StyleBoxFlat.new()
	estilo.bg_color              = Color(0.05, 0.09, 0.16, 0.98)
	estilo.border_color          = Color(0.22, 0.78, 1.0, 0.90)
	estilo.border_width_left     = 3
	estilo.border_width_top      = 3
	estilo.border_width_right    = 3
	estilo.border_width_bottom   = 3
	estilo.corner_radius_top_left    = 26
	estilo.corner_radius_top_right   = 26
	estilo.corner_radius_bottom_left = 26
	estilo.corner_radius_bottom_right= 26
	estilo.shadow_color = Color(0, 0, 0, 0.50)
	estilo.shadow_size  = 22
	modal_inatividade_panel.add_stylebox_override("panel", estilo)
 
	# ── Brilho decorativo no topo ─────────────────────────────────────────────
	var brilho := ColorRect.new()
	brilho.rect_position     = Vector2(18, 12)
	brilho.rect_size         = Vector2(544, 20)
	brilho.color        = Color(0.25, 0.80, 1.0, 0.14)
	brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_inatividade_panel.add_child(brilho)
 
	# ── Título ────────────────────────────────────────────────────────────────
	#    Zona: y 18 → 80  (altura 62)
	modal_inatividade_titulo          = Label.new()
	modal_inatividade_titulo.text     = "TEM ALGUÉM AÍ? 👀"
	modal_inatividade_titulo.rect_position = Vector2(18, 18)
	modal_inatividade_titulo.rect_size     = Vector2(544, 62)
	modal_inatividade_titulo.align = Label.ALIGN_CENTER
	modal_inatividade_titulo.valign = Label.VALIGN_CENTER
	Compat.tamanho(modal_inatividade_titulo, 34)
	modal_inatividade_titulo.add_color_override("font_color",         Color(1.0, 0.92, 0.26))
	modal_inatividade_titulo.add_color_override("font_outline_modulate", Color(0.04, 0.05, 0.08))
	Compat.contorno(modal_inatividade_titulo, 6)
	modal_inatividade_panel.add_child(modal_inatividade_titulo)
 
	# ── Linha separadora abaixo do título ─────────────────────────────────────
	var linha1        := ColorRect.new()
	linha1.rect_position   = Vector2(30, 86)
	linha1.rect_size       = Vector2(520, 2)
	linha1.color      = Color(0.22, 0.78, 1.0, 0.40)
	linha1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_inatividade_panel.add_child(linha1)
 
	# ── Instrução ─────────────────────────────────────────────────────────────
	#    Zona: y 96 → 210  (altura 114)
	modal_inatividade_texto               = Label.new()
	modal_inatividade_texto.text          = "Aperte  START  para continuar jogando"
	modal_inatividade_texto.rect_position      = Vector2(18, 96)
	modal_inatividade_texto.rect_size          = Vector2(544, 114)
	modal_inatividade_texto.align = Label.ALIGN_CENTER
	modal_inatividade_texto.valign = Label.VALIGN_CENTER
	modal_inatividade_texto.autowrap = true
	Compat.tamanho(modal_inatividade_texto, 24)
	modal_inatividade_texto.add_color_override("font_color",         Color(0.86, 0.95, 1.0))
	modal_inatividade_texto.add_color_override("font_outline_modulate", Color(0.04, 0.05, 0.08))
	Compat.contorno(modal_inatividade_texto, 4)
	modal_inatividade_panel.add_child(modal_inatividade_texto)
 
	# ── Linha separadora acima do timer ──────────────────────────────────────
	var linha2        := ColorRect.new()
	linha2.rect_position   = Vector2(30, 218)
	linha2.rect_size       = Vector2(520, 2)
	linha2.color      = Color(1.0, 0.62, 0.18, 0.35)
	linha2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_inatividade_panel.add_child(linha2)
 
	# ── Timer ─────────────────────────────────────────────────────────────────
	#    Zona: y 226 → 298  (altura 72)
	modal_inatividade_timer               = Label.new()
	modal_inatividade_timer.text          = "RETORNANDO EM:  3"
	modal_inatividade_timer.rect_position      = Vector2(18, 226)
	modal_inatividade_timer.rect_size          = Vector2(544, 72)
	modal_inatividade_timer.align = Label.ALIGN_CENTER
	modal_inatividade_timer.valign = Label.VALIGN_CENTER
	Compat.tamanho(modal_inatividade_timer, 30)
	modal_inatividade_timer.add_color_override("font_color",         Color(1.0, 0.46, 0.18))
	modal_inatividade_timer.add_color_override("font_outline_modulate", Color(0.04, 0.05, 0.08))
	Compat.contorno(modal_inatividade_timer, 5)
	modal_inatividade_panel.add_child(modal_inatividade_timer)
 
	overlay_inatividade.visible = false
	centralizar_modal_inatividade()


func centralizar_modal_inatividade() -> void:
	if modal_inatividade_panel == null:
		return
	var tela: Vector2 = Tela.retangulo().size
	modal_inatividade_panel.rect_position = Vector2(
		(tela.x - modal_inatividade_panel.rect_size.x) * 0.5,
		(tela.y - modal_inatividade_panel.rect_size.y) * 0.5
	)


func registrar_atividade_usuario() -> void:
	tempo_sem_atividade = 0.0

func abrir_modal_inatividade() -> void:
	if modal_inatividade_ativo:
		return

	modal_inatividade_ativo = true
	countdown_inatividade = 3.0
	aceitando_input_antes_modal_inatividade = aceitando_input
	aceitando_input = false

	if overlay_inatividade != null:
		overlay_inatividade.visible = true

	if modal_inatividade_panel != null:
		modal_inatividade_panel.rect_scale = Vector2(0.94, 0.94)
		modal_inatividade_panel.modulate = Color(1, 1, 1, 0.0)

	if modal_inatividade_bg != null:
		modal_inatividade_bg.color = Color(0, 0, 0, 0.0)

	if modal_inatividade_timer != null:
		modal_inatividade_timer.text = "RETORNANDO EM: 3"

	centralizar_modal_inatividade()

	var tw = create_tween()
	tw.set_parallel(true)

	if modal_inatividade_bg != null:
		tw.tween_property(modal_inatividade_bg, "color", Color(0, 0, 0, 0.72), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if modal_inatividade_panel != null:
		tw.tween_property(modal_inatividade_panel, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(modal_inatividade_panel, "rect_scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func fechar_modal_inatividade() -> void:
	if not modal_inatividade_ativo:
		return

	modal_inatividade_ativo = false
	tempo_sem_atividade = 0.0
	countdown_inatividade = 0.0

	if overlay_inatividade != null:
		overlay_inatividade.visible = false

	if not jogo_finalizado and not tela_final_ativa and not transicao_round_em_andamento and not jogando_trajeto:
		aceitando_input = aceitando_input_antes_modal_inatividade



func marcar_hud_como_suja() -> void:
	hud_sujo = true



func atualizar_status(msg: String = "") -> void:
	if hud_status_card != null:
		var lbl_player: Label = null
		var lbl_r: Label = null

		for child in hud_status_card.get_children():
			if child is Panel:
				if lbl_player == null:
					lbl_player = child.get_node_or_null("LblPlayerVal") as Label
				if lbl_r == null:
					lbl_r = child.get_node_or_null("LblRoundVal") as Label

		if lbl_r != null:
			if quantidade_jogadores > 1:
				var rodada_do_jogador: int = int(ceil(float(round_atual) / float(quantidade_jogadores)))

				if lbl_player != null:
					lbl_player.visible = true

					var cor_player_atual: Color = COR_TEXTO_BLUE if jogador_atual == 1 else Color(1.0, 0.20, 0.18)

					if jogador_atual == 1:
						lbl_player.text = "PLAYER 1"
						_aplicar_fonte_painel(lbl_player, 27, COR_TEXTO_BLUE, 6)
					else:
						lbl_player.text = "PLAYER 2"
						_aplicar_fonte_painel(lbl_player, 27, Color(1.0, 0.20, 0.18), 6)

					lbl_r.rect_position = Vector2(238, 30)
					lbl_r.rect_size = Vector2(360, 40)
					lbl_r.text = "|  ROUND  %d  /  %d" % [
						rodada_do_jogador,
						round_base_por_jogador
					]
					_aplicar_fonte_painel(lbl_r, 27, cor_player_atual, 6)
			else:
				if lbl_player != null:
					lbl_player.visible = false

				lbl_r.rect_position = Vector2(78, 30)
				lbl_r.rect_size = Vector2(530, 40)
				lbl_r.text = "ROUND  %d  /  %d" % [
					round_atual,
					total_rounds
				]
				_aplicar_fonte_painel(lbl_r, 27, COR_TEXTO_BRANCO, 6)

		var lbl_d: Label = null
		var cnt: int = 0

		for child in hud_status_card.get_children():
			if child is Panel:
				cnt += 1
				if cnt == 2:
					lbl_d = child.get_node_or_null("LblDerruVal") as Label
					break

		if lbl_d != null:
			lbl_d.text = "%d  /  10  PINOS DERRUBADOS" % pinos_derrubados_no_round
			_aplicar_fonte_painel(lbl_d, 27, COR_TEXTO_BRANCO, 6)

	# O texto amarelo no alto da pista ("PREPARE-SE PARA JOGAR!" etc.) saiu:
	# repetia o que o aviso central (ROUND, ACERTO!, STRIKE...) já mostra.
	if status_label != null:
		status_label.text = ""
		status_label.visible = false



func registrar_resultado_round(derrubados: int, strike: bool, spare: bool) -> void:
	var rodada_do_jogador: int = int(ceil(float(round_atual) / float(quantidade_jogadores)))

	var item = {
		"round": round_atual,
		"rodada_jogador": rodada_do_jogador,
		"jogador": jogador_atual,
		"tentativas": tentativa_atual,
		"derrubados": derrubados,
		"strike": strike,
		"spare": spare
	}

	historico_rounds.append(item)

	if jogador_atual == 1:
		historico_jogador_1.append(item)
	else:
		historico_jogador_2.append(item)



func iniciar_jogo(mostrar_banner_inicial: bool = true) -> void:
	ocultar_tela_final()
	_parar_musica_tela_final()
	fechar_modal_inatividade()

	ultima_tecla_jogada = ""
	processando_impacto = false
	aguardando_fim_bola = false
	transicao_round_em_andamento = false
	tecla_anterior_no_round = ""
	bloquear_spare_pos_lateral_c = false
	lateral_anterior_para_c = ""

	_carregar_config_jogadores()

	round_atual = 1
	tentativa_atual = 1
	pinos_derrubados_no_round = 0

	jogo_finalizado = false
	jogando_trajeto = false

	historico_rounds.clear()
	historico_jogador_1.clear()
	historico_jogador_2.clear()

	contador_strikes_no_jogo = 0
	contador_strikes_jogador_1 = 0
	contador_strikes_jogador_2 = 0

	tempo_sem_atividade = 0.0

	marcar_hud_como_suja()

	criar_10_pinos()

	if quantidade_jogadores > 1:
		atualizar_status("PLAYER 1 - Prepare-se!")
	else:
		atualizar_status("Prepare-se para jogar!")

	if mostrar_banner_inicial:
		mostrar_round_banner(round_atual)

	if bola != null and bola.has_method("resetar_bola"):
		bola.resetar_bola()

	if camera_jogo != null:
		camera_jogo.global_position = camera_base_pos
		camera_jogo.offset = Vector2.ZERO
		camera_jogo.zoom = camera_zoom_idle

	atualizar_hub_play()
	atualizar_mapa_visual()
	atualizar_placar()

	aceitando_input = true



func _input(event: InputEvent) -> void:
	# SELECT (CONFIGURAÇÃO) NA PARTIDA NÃO FAZ NADA: trocar de cena aqui
	# jogava fora uma partida paga. A configuração abre pelo SELECT na
	# abertura, no menu e na demo. (eh_config nunca é verdade para um botão
	# de jogada: nenhuma jogada é engolida aqui.)
	if ArcadeControls.eh_config(event):
		get_viewport().set_input_as_handled()
		return
	if modal_inatividade_ativo:
		if ArcadeControls.eh_start(event):
			fechar_modal_inatividade()
			get_viewport().set_input_as_handled()
		return

	if intro_em_andamento:
		_guardar_jogada_pendente(event)
		return

	if _evento_conta_como_atividade(event):
		registrar_atividade_usuario()

	if tela_final_ativa:
		if final_intro_em_andamento:
			return

		if _evento_acionou_restart(event):
			if not reinicio_com_credito_em_andamento:
				reinicio_com_credito_em_andamento = true
				call_deferred("_reiniciar_com_credito")
		return

	if jogo_finalizado:
		return

	# A JOGADA NÃO SE PERDE. Depois de cada lançamento o jogo fica alguns
	# instantes sem aceitar jogada (pinos caindo, resultado, reposição). Um
	# sensor acionado nesse meio-tempo antes era ignorado — o "comando
	# travado". Agora ele fica guardado e sai assim que a pista liberar.
	if not aceitando_input or intro_em_andamento or transicao_round_em_andamento or jogando_trajeto:
		_guardar_jogada_pendente(event)
		return

	var tecla_jogada: String = _obter_tecla_da_action(event)
	if tecla_jogada != "":
		executar_jogada_por_tecla(tecla_jogada)


func _evento_acionou_restart(event: InputEvent) -> bool:
	return ArcadeControls.eh_start(event)


func _aplicar_fonte_painel(lbl: Label, tamanho: int, cor: Color, outline: int = 4) -> void:
	if lbl == null:
		return

	if ResourceLoader.exists(FONTE_PAINEL_PATH):
		Compat.fonte(lbl, load(FONTE_PAINEL_PATH))

	Compat.tamanho(lbl, tamanho)
	lbl.add_color_override("font_color", cor)
	lbl.add_color_override("font_outline_modulate", Color(0.01, 0.01, 0.02))
	Compat.contorno(lbl, outline)
	lbl.add_color_override("font_color_shadow", Color(0, 0, 0, 0.55))
	lbl.add_constant_override("shadow_offset_x", 3)
	lbl.add_constant_override("shadow_offset_y", 3)


func _criar_label_painel(pai: Control, texto: String, pos: Vector2, tam: Vector2, cor: Color, tamanho: int, outline: int = 4) -> Label:
	var lbl = _criar_label(
		pai,
		texto,
		pos,
		tam,
		cor,
		tamanho,
		outline,
		Label.ALIGN_CENTER,
		Label.VALIGN_CENTER
	)

	_aplicar_fonte_painel(lbl, tamanho, cor, outline)
	return lbl


func _cor_player_ativo(player_id: int, cor_base: Color) -> Color:
	if quantidade_jogadores <= 1:
		return cor_base

	if jogador_atual == player_id:
		return cor_base

	return Color(cor_base.r * 0.38, cor_base.g * 0.38, cor_base.b * 0.38, 0.62)


func _texto_lider_player(player_id: int) -> String:
	if quantidade_jogadores <= 1:
		return ""

	var p1 = total_pinos_jogador(1)
	var p2 = total_pinos_jogador(2)

	if p1 == p2:
		return "EMPATE"

	if player_id == 1 and p1 > p2:
		return "LÍDER"

	if player_id == 2 and p2 > p1:
		return "LÍDER"

	return "ATRÁS"


func _aplicar_fonte_arcade(lbl: Label, tamanho: int, cor: Color) -> void:
	if lbl == null:
		return

	if ResourceLoader.exists(FONTE_ARCADE_PATH):
		Compat.fonte(lbl, load(FONTE_ARCADE_PATH))

	Compat.tamanho(lbl, tamanho)
	lbl.add_color_override("font_color", cor)
	lbl.add_color_override("font_outline_modulate", Color(0.01, 0.01, 0.02))
	Compat.contorno(lbl, 14)
	lbl.add_color_override("font_color_shadow", Color(0, 0, 0, 0.70))
	lbl.add_constant_override("shadow_offset_x", 5)
	lbl.add_constant_override("shadow_offset_y", 5)
	lbl.align = Label.ALIGN_CENTER
	lbl.valign = Label.VALIGN_CENTER



func _animar_label_arcade(lbl: Label, cor: Color, strike: bool = false) -> void:
	if lbl == null:
		return

	lbl.rect_pivot_offset = lbl.rect_size * 0.5
	lbl.modulate = Color(cor.r, cor.g, cor.b, 0.0)

	var escala_inicio = Vector2(0.58, 0.58)
	var escala_pico = Vector2(1.10, 1.10)

	if strike:
		escala_inicio = Vector2(0.44, 0.44)
		escala_pico = Vector2(1.28, 1.28)

	lbl.rect_scale = escala_inicio

	var tw = create_tween()
	tw.set_parallel(true)

	tw.tween_property(lbl, "modulate", Color(cor.r, cor.g, cor.b, 1.0), 0.10)
	tw.tween_property(lbl, "rect_scale", escala_pico, 0.16)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	tw.chain().tween_property(lbl, "rect_scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	tw.chain().tween_interval(0.70)

	tw.chain().tween_property(lbl, "modulate", Color(cor.r, cor.g, cor.b, 0.0), 0.22)
	tw.parallel().tween_property(lbl, "rect_scale", Vector2(0.96, 0.96), 0.22)




func _obter_tecla_da_action(event: InputEvent) -> String:
	return ArcadeControls.tecla_jogada(event)


func _estilo_neon(bg: Color, borda: Color, raio: int = 28, espessura: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color              = bg
	s.border_color          = borda
	s.border_width_left     = espessura
	s.border_width_top      = espessura
	s.border_width_right    = espessura
	s.border_width_bottom   = espessura
	s.corner_radius_top_left     = raio
	s.corner_radius_top_right    = raio
	s.corner_radius_bottom_left  = raio
	s.corner_radius_bottom_right = raio
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size  = 18
	return s


func _adicionar_brilho_topo(pai: Control, cor_brilho: Color,
		offset_x: float = 14, offset_y: float = 10,
		largura_menos: float = 28, altura: float = 28, raio: int = 20) -> void:
	var p := Panel.new()
	p.rect_position           = Vector2(offset_x, offset_y)
	p.rect_size               = Vector2(pai.rect_size.x - largura_menos, altura)
	p.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	var s                := StyleBoxFlat.new()
	s.bg_color           = cor_brilho
	s.corner_radius_top_left    = raio
	s.corner_radius_top_right   = raio
	s.corner_radius_bottom_left = raio
	s.corner_radius_bottom_right= raio
	p.add_stylebox_override("panel", s)
	pai.add_child(p)



func _linha_decorativa(pai: Control, y: float, cor: Color,
		margem_x: float = 22, espessura: float = 2) -> ColorRect:
	var r       := ColorRect.new()
	r.rect_position  = Vector2(margem_x, y)
	r.rect_size      = Vector2(pai.rect_size.x - margem_x * 2, espessura)
	r.color     = cor
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(r)
	return r


func _criar_label(pai: Control, texto: String, pos: Vector2, tam: Vector2,
		cor: Color, fonte_size: int, outline_size: int = 5,
		h_align := Label.ALIGN_CENTER,
		v_align := Label.VALIGN_CENTER) -> Label:
	var l := Label.new()
	l.text               = texto
	l.rect_position           = pos
	l.rect_size               = tam
	l.align = h_align
	l.valign = v_align
	Compat.tamanho(l, fonte_size)
	l.add_color_override("font_color", cor)
	l.add_color_override("font_outline_modulate", Color(0.03, 0.04, 0.08))
	Compat.contorno(l, outline_size)
	pai.add_child(l)
	return l



func _evento_conta_como_atividade(event: InputEvent) -> bool:
	# Só a placa Zero Delay conta; teclado e controle remoto não.
	return ArcadeControls.eh_atividade(event)

func _process(delta: float) -> void:
	# Godot 3 / Mali-450: as fases do brilho da pista vêm daqui (o shader não
	# usa TIME — ver shaders/brilho_pista.shader).
	Compat.avancar_brilho(fundo_shader_material, delta)
	if Input.get_mouse_mode() != Input.MOUSE_MODE_HIDDEN:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	if modal_inatividade_ativo:
		countdown_inatividade -= delta

		if modal_inatividade_timer != null:
			modal_inatividade_timer.text = "RETORNANDO EM: %d" % max(0, int(ceil(countdown_inatividade)))

		if countdown_inatividade <= 0.0:
			modal_inatividade_ativo = false
			if overlay_inatividade != null:
				overlay_inatividade.visible = false
			voltar_para_main()
		return

	if tela_final_ativa:
		anim_tela_final_t += delta

		if final_titulo != null:
			if final_intro_em_andamento:
				final_titulo.rect_scale = Vector2.ONE
			else:
				final_titulo.rect_scale = Vector2.ONE * (1.0 + sin(anim_tela_final_t * 3.8) * 0.015)

		if final_logo != null and final_intro_em_andamento:
			var brilho_logo: float = 0.92 + sin(anim_tela_final_t * 2.8) * 0.08
			final_logo.modulate = Color(brilho_logo, brilho_logo, brilho_logo, final_logo.modulate.a)

		if final_start_botao != null:
			if final_intro_em_andamento:
				final_start_botao.visible = false
				final_start_botao.rect_scale = Vector2.ONE
				if final_start_glow != null:
					final_start_glow.visible = false
					final_start_glow.modulate.a = 0.0
			else:
				final_start_botao.visible = true
				final_start_botao.modulate = Color(1, 1, 1, 1)
				if final_start_glow != null:
					final_start_glow.visible = true
					var a: float = 0.24 + sin(anim_tela_final_t * 4.2) * 0.16
					final_start_glow.modulate.a = clamp(a, 0.10, 0.52)

		if not retorno_em_andamento and not final_intro_em_andamento:
			tempo_restante_tela_final -= delta

		if final_timer != null:
			if final_intro_em_andamento:
				final_timer.text = ""
			else:
				final_timer.text = "RETORNO EM: %d" % max(0, int(ceil(tempo_restante_tela_final)))

		if tempo_restante_tela_final <= 0.0 and not retorno_em_andamento and not final_intro_em_andamento:
			retorno_em_andamento = true
			tela_final_ativa = false
			call_deferred("voltar_para_main")
		return

	if not intro_em_andamento and not jogo_finalizado and not transicao_round_em_andamento and not jogando_trajeto and aceitando_input:
		tempo_sem_atividade += delta
		if tempo_sem_atividade >= limite_inatividade_segundos:
			abrir_modal_inatividade()
			return

	if _jogada_pendente != "":
		_soltar_jogada_pendente()

	tempo_hover_acc += delta
	tempo_hud_acc += delta

	if OS.get_name() != "Android" and tempo_hover_acc >= INTERVALO_UPDATE_HOVER:
		tempo_hover_acc = 0.0
		var mouse_pos: Vector2 = get_global_mouse_position()
		for p in pins:
			if p != null and p.has_method("atualizar_hover"):
				p.atualizar_hover(mouse_pos)

	if hud_sujo and tempo_hud_acc >= INTERVALO_UPDATE_HUD:
		tempo_hud_acc = 0.0
		hud_sujo = false
		atualizar_placar()



func _guardar_jogada_pendente(event: InputEvent) -> void:
	var tecla: String = _obter_tecla_da_action(event)
	if tecla == "":
		return
	# A mesma bola passando por dois sensores vizinhos não vira duas jogadas:
	# logo depois de um lançamento, outro sensor é a mesma bola.
	if Time.get_ticks_msec() - _ultima_jogada_ms < MESMA_BOLA_MS:
		return
	_jogada_pendente = tecla
	_jogada_pendente_ms = Time.get_ticks_msec()


func _soltar_jogada_pendente() -> void:
	if Time.get_ticks_msec() - _jogada_pendente_ms > VALIDADE_JOGADA_PENDENTE_MS or jogo_finalizado or tela_final_ativa:
		_jogada_pendente = ""
		return
	if intro_em_andamento or not aceitando_input or transicao_round_em_andamento or jogando_trajeto:
		return
	var tecla = _jogada_pendente
	_jogada_pendente = ""
	executar_jogada_por_tecla(tecla)


func executar_jogada_por_tecla(tecla: String) -> void:
	if intro_em_andamento or not aceitando_input:
		return
	if transicao_round_em_andamento:
		return
	if jogando_trajeto or jogo_finalizado:
		return
	if bola == null or not is_instance_valid(bola):
		return
	if not config_jogadas.has(tecla):
		return

	registrar_atividade_usuario()

	aceitando_input = false
	jogando_trajeto = true
	_ultima_jogada_ms = Time.get_ticks_msec()

	bloquear_spare_pos_c = (
		tentativa_atual >= 2
		and tecla_anterior_no_round == "C"
		and tecla in ["X", "V"]
	)

	bloquear_spare_pos_lateral_c = (
		tentativa_atual >= 2
		and tecla == "C"
		and tecla_anterior_no_round in ["X", "V"]
	)

	lateral_anterior_para_c = tecla_anterior_no_round if bloquear_spare_pos_lateral_c else ""

	ultima_tecla_jogada = tecla
	pinos_antes_da_jogada = contar_pinos_em_pe()

	resetar_estado_audio_jogada()
	animar_consumo_tentativa(clamp(tentativa_atual - 1, 0, 2))
	marcar_hud_como_suja()

	var cfg: Dictionary = config_jogadas[tecla]
	var dir_base: Vector2 = cfg["dir"] as Vector2
	var dir: Vector2 = Vector2(dir_base.x, dir_base.y)
	var forca: float = float(cfg["forca"])
	var spin: float = float(cfg["spin"])

	dir.x += rand_range(-0.0015, 0.0015)
	forca += rand_range(-0.004, 0.004)
	spin += rand_range(-0.05, 0.05)

	if tecla == "X":
		dir.x = -0.48
		forca = 1.08
		spin = -0.04
	elif tecla == "V":
		dir.x = 0.48
		forca = 1.08
		spin = 0.04
	elif tecla == "C":
		dir.x = 0.0
		forca = 1.06
		spin = 0.0

	if bola.has_method("configurar_audio_por_jogada"):
		bola.configurar_audio_por_jogada(tecla)

	if bola.has_method("lancar_bola"):
		bola.lancar_bola(dir, forca, spin)
		_tocar_som_inicio_com_a_bola()
		aplicar_zoom_jogada()

		if has_method("_animar_rastro_bola_ao_lancar"):
			_animar_rastro_bola_ao_lancar()
	else:
		jogando_trajeto = false
		aceitando_input = true
		push_error("A cena Bola não possui o método lancar_bola().")


func _forcar_c_depois_lateral(ponto_impacto: Vector2) -> void:
	if not bloquear_spare_pos_lateral_c:
		return

	var alvos: Array = []

	var p1 = obter_pino_por_numero(1)
	if p1 != null and not p1.derrubado:
		alvos.append(1)

	# Se a jogada anterior foi V, C derruba 1 + 8.
	# Se a jogada anterior foi X, C derruba 1 + 9.
	if lateral_anterior_para_c == "V":
		alvos.append(8)
	elif lateral_anterior_para_c == "X":
		alvos.append(9)

	for alvo_num in alvos:
		var p = obter_pino_por_numero(alvo_num)
		if p == null or p.derrubado:
			continue

		var anim: String = "strike"
		if alvo_num == 8:
			anim = "down_rt"
		elif alvo_num == 9:
			anim = "down_left"

		if p.has_method("forcar_queda_imediata"):
			p.forcar_queda_imediata(anim, 3.0, ponto_impacto)
		elif p.has_method("cair_voando"):
			p.cair_voando(anim, 3.0, ponto_impacto)
		elif p.has_method("cair"):
			p.cair(anim, 3.0, ponto_impacto)

	yield(get_tree(), "idle_frame")
	marcar_hud_como_suja()
	atualizar_mapa_visual()
	atualizar_placar()





func _animar_rastro_bola_ao_lancar() -> void:
	if camera_jogo == null or bola == null:
		return

	# Leve compressão da câmera no instante do lançamento
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(camera_jogo, "zoom",
		camera_zoom_idle * Vector2(camera_zoom_jogada * 0.985, camera_zoom_jogada * 0.985),
		0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	tw.chain().set_parallel(true)
	tw.tween_property(camera_jogo, "zoom",
		camera_zoom_idle,
		0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func aplicar_zoom_jogada() -> void:
	if camera_jogo == null:
		return

	var tw: SceneTreeTween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(camera_jogo, "zoom", camera_zoom_idle * camera_zoom_jogada, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera_jogo, Compat.prop(camera_jogo, "global_position"), camera_base_pos + camera_focus_offset_jogada, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tw.chain().set_parallel(true)
	tw.tween_property(camera_jogo, "zoom", camera_zoom_idle, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera_jogo, Compat.prop(camera_jogo, "global_position"), camera_base_pos, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func obter_perfil_jogada(tecla: String, em_pe_total: int) -> Dictionary:
	var perfil: Dictionary = {
		"energia_base": 1.0,
		"chain_mult": 0.78,
		"limite_quedas": 10,
		"bonus_frente": 0.24,
		"penalidade_lateral": 0.10,
		"limiar_secundario": 0.74,
		"bonus_centro": 0.0,
		"bonus_fundo": 0.0
	}

	match tecla:
		"Z", "B":
			perfil["energia_base"] = 0.96
			perfil["chain_mult"] = 0.28
			perfil["bonus_frente"] = 0.12
			perfil["penalidade_lateral"] = 0.30
			perfil["limiar_secundario"] = 1.02
			perfil["bonus_centro"] = -0.10
			perfil["bonus_fundo"] = -0.06
			perfil["limite_quedas"] = 1

		"X", "V":
			perfil["energia_base"] = 1.10
			perfil["chain_mult"] = 0.44
			perfil["bonus_frente"] = 0.24
			perfil["penalidade_lateral"] = 0.20
			perfil["limiar_secundario"] = 0.72
			perfil["bonus_centro"] = 0.08
			perfil["bonus_fundo"] = 0.02
			perfil["limite_quedas"] = 5

		"C":
			perfil["energia_base"] = 1.24
			perfil["chain_mult"] = 0.56
			perfil["bonus_frente"] = 0.30
			perfil["penalidade_lateral"] = 0.12
			perfil["limiar_secundario"] = 0.58
			perfil["bonus_centro"] = 0.14
			perfil["bonus_fundo"] = 0.08
			perfil["limite_quedas"] = 8

	return perfil


func transferencia_valida_por_tecla(origem, alvo) -> bool:
	if origem == null or alvo == null:
		return false

	var dx: float = alvo.global_position.x - origem.global_position.x
	var dy: float = alvo.global_position.y - origem.global_position.y

	match ultima_tecla_jogada:
		"Z":
			return dx <= 48.0 and dy <= 26.0
		"B":
			return dx >= -48.0 and dy <= 26.0
		"X":
			return dx <= 62.0 and dy <= 28.0
		"V":
			return dx >= -62.0 and dy <= 28.0
		"C":
			return abs(dx) <= 110.0 and dy <= 220.0

	return true

func energia_transferida_entre_pinos(origem, alvo, peso_origem: float, ponto_impacto: Vector2, perfil: Dictionary) -> float:
	if origem == null or alvo == null:
		return 0.0

	var dist: float = origem.global_position.distance_to(alvo.global_position)
	if dist > 112.0:
		return 0.0

	if not transferencia_valida_por_tecla(origem, alvo):
		return 0.0

	var dx: float = abs(alvo.global_position.x - origem.global_position.x)
	var dy_dir: float = origem.global_position.y - alvo.global_position.y
	var frente: float = clamp((dy_dir + 18.0) / 64.0, 0.0, 1.0)
	var lateral: float = clamp(dx / 84.0, 0.0, 1.0)
	var proximidade: float = max(0.0, (112.0 - dist) / 112.0)

	var energia: float = 0.0
	energia += peso_origem * float(perfil["chain_mult"])
	energia += proximidade * 0.34
	energia += frente * float(perfil["bonus_frente"])
	energia -= lateral * float(perfil["penalidade_lateral"])

	if ultima_tecla_jogada == "C":
		if alvo.numero in [4, 5, 6]:
			energia += 0.12
		if alvo.numero in [8, 9]:
			energia += float(perfil["bonus_centro"])
		if alvo.numero in [7, 8, 9, 10]:
			energia += float(perfil["bonus_fundo"])

	if ultima_tecla_jogada in ["X", "V"]:
		if alvo.numero in [4, 5, 6, 8, 9]:
			energia += 0.10

	if ultima_tecla_jogada in ["Z", "B"] and alvo.numero == 5:
		energia -= 0.12

	if alvo.numero in [7, 10]:
		energia -= 0.01

	return energia
	
	
	
func adicionar_item_derrubada(lista: Array, visitados: Dictionary, pin, peso: float, anim: String, dist_seq: float) -> void:
	if pin == null or pin.derrubado:
		return
	if visitados.has(pin.numero):
		return

	lista.append({
		"pin": pin,
		"peso": peso,
		"anim": anim,
		"dist_seq": dist_seq
	})
	visitados[pin.numero] = true


func escolher_animacao_por_entrada(pin, lateral: float, spin: float, ponto_impacto: Vector2) -> String:
	if pin == null:
		return "strike"

	var base: String = obter_lado_queda_principal(ponto_impacto, pin)

	# No centro, aceita strike visual quando o impacto é muito frontal
	if ultima_tecla_jogada == "C":
		var dx: float = abs(pin.global_position.x - ponto_impacto.x)
		var dy: float = abs(pin.global_position.y - ponto_impacto.y)
		if dx < 10.0 and dy < 22.0:
			return "strike"

	return base


func escolher_animacao_entre_pinos(origem, alvo, lateral: float, spin: float) -> String:
	if origem == null or alvo == null:
		return "strike"

	var base: String = "strike"

	# Herda a direção dominante da jogada
	match ultima_tecla_jogada:
		"Z", "X":
			base = "down_rt"
		"V", "B":
			base = "down_left"
		"C":
			# no centro, decide pela relação local
			var dx_local: float = alvo.global_position.x - origem.global_position.x
			if abs(dx_local) < 8.0:
				base = "strike"
			elif dx_local > 0.0:
				base = "down_rt"
			else:
				base = "down_left"

	# Pequeno ajuste local, mas sem inverter tudo sem motivo
	if ultima_tecla_jogada != "C":
		var dx: float = alvo.global_position.x - origem.global_position.x

		if base == "down_rt" and dx < -26.0:
			return "strike"
		if base == "down_left" and dx > 26.0:
			return "strike"

	return base

func faixa_ideal_x_por_tecla(tecla: String) -> Vector2:
	match tecla:
		"Z":
			return Vector2(360.0, 430.0)
		"X":
			return Vector2(430.0, 500.0)
		"C":
			return Vector2(486.0, 538.0)
		"V":
			return Vector2(524.0, 594.0)
		"B":
			return Vector2(594.0, 664.0)
	return Vector2(0.0, 1024.0)


func tecla_alinha_com_pin(tecla: String, pin) -> bool:
	if pin == null:
		return false

	var faixa: Vector2 = faixa_ideal_x_por_tecla(tecla)
	var px: float = pin.global_position.x
	var margem: float = 24.0

	var em_pe_total: int = contar_pinos_em_pe()

	if em_pe_total <= 5:
		margem = 16.0
	if em_pe_total <= 3:
		margem = 12.0
	if em_pe_total <= 2:
		margem = 10.0

	return px >= faixa.x - margem and px <= faixa.y + margem


func bonus_alinhamento_por_tecla(pin) -> float:
	if pin == null:
		return 0.0

	var px: float = pin.global_position.x
	var centro_faixa: float = (faixa_ideal_x_por_tecla(ultima_tecla_jogada).x + faixa_ideal_x_por_tecla(ultima_tecla_jogada).y) * 0.5
	var dx: float = abs(px - centro_faixa)

	var base: float = clamp(1.0 - (dx / 120.0), 0.0, 1.0)

	if ultima_tecla_jogada == "C":
		return base * 0.08
	elif ultima_tecla_jogada in ["X", "V"]:
		return base * 0.12
	else:
		return base * 0.06



func derrubar_pinos_com_estilo(lista: Array, origem_impacto: Vector2) -> void:
	var _g3_estado = null
	_g3_estado = derrubar_pinos_com_estilo_async(lista, origem_impacto)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")

func derrubar_pinos_com_estilo_async(lista: Array, origem_impacto: Vector2) -> void:
	tocar_impactos_derrubada(lista)

	for i in range(lista.size()):
		var item: Dictionary = lista[i]
		var p = item["pin"]
		var anim: String = str(item["anim"])
		var peso: float = float(item["peso"])

		if p == null or p.derrubado:
			continue

		var intensidade: float = clamp(0.96 + peso * 0.28, 0.96, 1.42)

		if i > 0 and p.has_method("abalo_lateral"):
			p.abalo_lateral(clamp(0.76 + peso * 0.18, 0.76, 1.02))

		if p.has_method("cair_voando"):
			p.cair_voando(anim, intensidade, origem_impacto)
		elif p.has_method("cair"):
			p.cair(anim, intensidade, origem_impacto)

		if i < lista.size() - 1:
			yield(get_tree().create_timer(rand_range(0.050, 0.085)), "timeout")



func efeito_spare_total() -> void:
	shake_camera(4.0, 0.12, 7)

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 45
	add_child(layer)

	var flash_suave := ColorRect.new()
	Tela.cobrir_auto(flash_suave)
	flash_suave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_suave.color = Color(1.0, 0.84, 0.34, 0.0)
	layer.add_child(flash_suave)

	if banner_label != null:
		banner_label.rect_scale = Vector2(0.94, 0.94)
		banner_label.modulate = Color(1.0, 0.95, 0.82, 0.0)

	var tw: SceneTreeTween = create_tween()
	tw.set_parallel(true)

	tw.tween_property(flash_suave, "color", Color(1.0, 0.84, 0.34, 0.12), 0.08)

	if banner_label != null:
		tw.tween_property(banner_label, "modulate", Color(1.0, 0.95, 0.82, 1.0), 0.10)
		tw.tween_property(banner_label, "rect_scale", Vector2(1.08, 1.08), 0.12)

	yield(get_tree().create_timer(0.12), "timeout")

	var tw2: SceneTreeTween = create_tween()
	tw2.set_parallel(true)

	tw2.tween_property(flash_suave, "color", Color(1.0, 0.84, 0.34, 0.0), 0.18)

	if banner_label != null:
		tw2.tween_property(banner_label, "rect_scale", Vector2(1.0, 1.0), 0.16)

	yield(get_tree().create_timer(0.18), "timeout")

	if is_instance_valid(layer):
		layer.queue_free()



func _on_bola_impacto_no_deck(dados: Dictionary) -> void:
	var _g3_estado = null
	if processando_impacto:
		return

	processando_impacto = true

	var pinos_em_pe_antes: Dictionary = {}
	for p in pins:
		if p != null and not p.derrubado:
			pinos_em_pe_antes[p.numero] = true

	var ponto_impacto: Vector2 = Vector2(
		float(dados.get("impact_x", 512.0)),
		float(dados.get("impact_y", 592.0))
	)
	var forca: float = float(dados.get("forca", 1.0))
	var lateral: float = float(dados.get("lateral", 0.0))
	var spin: float = float(dados.get("spin", 0.0))

	if not _ha_pino_frontal_para_jogada(ultima_tecla_jogada):
		_enviar_led("MISS")
		_g3_estado = _tratar_jogada_sem_alvo_na_faixa()
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")
		processando_impacto = false
		return

	# O primeiro pino tocado é sempre um da faixa da tecla (ver PINOS_DA_FAIXA).
	var principal = _primeiro_pino_da_faixa(ponto_impacto)

	if principal == null:
		processando_impacto = false
		aplicar_efeito_proximidade_sem_colisao(ponto_impacto, lateral)

		if bola != null and bola.has_method("tocar_passagem_reta"):
			_g3_estado = bola.tocar_passagem_reta()
			if _g3_estado is GDScriptFunctionState:
				_g3_estado = yield(_g3_estado, "completed")

		_enviar_led("MISS")
		tocar_som_erro_repeticao()
		mostrar_banner("PRA FORA!", COR_MISS)
		_g3_estado = efeito_miss_total()
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")

		if aguardando_fim_bola:
			aguardando_fim_bola = false
			jogando_trajeto = false
			_g3_estado = finalizar_jogada()
			if _g3_estado is GDScriptFunctionState:
				_g3_estado = yield(_g3_estado, "completed")

			if bola != null and bola.has_method("resetar_bola"):
				bola.resetar_bola()

			if not transicao_round_em_andamento and not jogo_finalizado:
				aceitando_input = true
		return

	var ponto_contato_real: Vector2 = calcular_ponto_contato_no_pin(principal, ponto_impacto)

	if bola != null and bola.has_method("tocar_empurrao_no_deck"):
		_g3_estado = bola.tocar_empurrao_no_deck(
			ponto_contato_real,
			principal.z_index,
			clamp(forca, 0.98, 1.20)
		)
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")

	efeito_impacto_deck(ponto_contato_real, clamp(forca, 0.96, 1.22))

	# A BOLA NÃO PARA NO PINO. Antes ela ficava parada no ponto do impacto
	# enquanto a queda dos pinos era calculada e só depois seguia — parecia
	# que batia, voltava e depois ia. Agora ela atravessa na hora, junto
	# com a pancada; o fim da passagem é tratado em _on_bola_jogada_finalizada.
	var bola_seguindo := false
	if bola != null and bola.has_method("tocar_passagem_por_cima_dos_pinos"):
		bola_seguindo = true
		bola.tocar_passagem_por_cima_dos_pinos(
			ponto_contato_real,
			principal.z_index,
			clamp(forca, 0.98, 1.20)
		)

	if principal.has_method("destacar_acerto"):
		principal.destacar_acerto()

	if principal.has_method("impacto_visual"):
		principal.impacto_visual(clamp(forca, 0.95, 1.18), ponto_contato_real)

	if ultima_tecla_jogada in ["Z", "B"]:
		# Um unico pino, sem propagacao de colisao para os vizinhos.
		principal.forcar_queda_imediata("down_rt" if ultima_tecla_jogada == "Z" else "down_left", 1.08, ponto_contato_real)
	elif bloquear_spare_pos_lateral_c:
		_g3_estado = _forcar_c_depois_lateral(ponto_contato_real)
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")
	else:
		_empurrar_pinos_proximos_da_passagem(ponto_contato_real, principal, forca)
		_g3_estado = _aplicar_impulso_realista(principal, ponto_contato_real, forca, lateral, spin)
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")

		if ultima_tecla_jogada in ["X", "V"]:
			_g3_estado = _forcar_fundo_xv_agora(ponto_contato_real)
			if _g3_estado is GDScriptFunctionState:
				_g3_estado = yield(_g3_estado, "completed")

	if ultima_tecla_jogada == "C":
		_g3_estado = _forcar_strike_central_se_preciso(ponto_contato_real)
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")

	if ultima_tecla_jogada == "C":
		_aplicar_quase_queda_ao_redor(principal, -1, ponto_contato_real)

	if not bola_seguindo and bola != null and bola.has_method("tocar_passagem_por_cima_dos_pinos"):
		_g3_estado = bola.tocar_passagem_por_cima_dos_pinos(
			ponto_contato_real,
			principal.z_index,
			clamp(forca, 0.98, 1.20)
		)
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")

	yield(get_tree().create_timer(0.06), "timeout")
	atualizar_placar()

	var lista_derrubados: Array = []

	for p in pins:
		if p == null:
			continue

		if pinos_em_pe_antes.has(p.numero) and p.derrubado:
			lista_derrubados.append({
				"pin": p,
				"peso": 1.0,
				"anim": "impacto",
				"dist_seq": 0.0
			})

	if not lista_derrubados.empty():
		_efeito_onda_pinos_derrubados(ponto_contato_real, lista_derrubados)

	var em_pe_depois: int = contar_pinos_em_pe()
	var derrubados_nesta_jogada: int = lista_derrubados.size()
	var total_no_round_apos_jogada: int = pinos_derrubados_no_round + derrubados_nesta_jogada

	var foi_strike_visual: bool = (
		em_pe_depois == 0
		and tentativa_atual == 1
		and pinos_antes_da_jogada == 10
	)

	var foi_spare_visual: bool = (
		not foi_strike_visual
		and not bloquear_spare_pos_c
		and not bloquear_spare_pos_lateral_c
		and total_no_round_apos_jogada >= 10
		and tentativa_atual == 2
	)

	if foi_strike_visual:
		for num in [7, 10, 8, 9, 4, 6, 2, 3, 5, 1]:
			var p = obter_pino_por_numero(num)
			if p != null and not p.derrubado:
				if p.has_method("cair_voando"):
					var anim_extra: String = "strike"
					if num in [7, 8, 2, 4]:
						anim_extra = "down_rt"
					elif num in [10, 9, 3, 6]:
						anim_extra = "down_left"

					p.cair_voando(anim_extra, 1.42, ponto_contato_real)
				elif p.has_method("cair"):
					p.cair("strike", 1.42, ponto_contato_real)

		yield(get_tree().create_timer(0.10), "timeout")
		atualizar_placar()

		lista_derrubados.clear()

		for p in pins:
			if p == null:
				continue

			if pinos_em_pe_antes.has(p.numero) and p.derrubado:
				lista_derrubados.append({
					"pin": p,
					"peso": 1.0,
					"anim": "impacto",
					"dist_seq": 0.0
				})

		em_pe_depois = contar_pinos_em_pe()
		derrubados_nesta_jogada = lista_derrubados.size()
		total_no_round_apos_jogada = pinos_derrubados_no_round + derrubados_nesta_jogada

	if derrubados_nesta_jogada > 0:
		if foi_strike_visual:
			_enviar_led("STRIKE")
			tocar_impactos_derrubada(lista_derrubados)
			yield(get_tree().create_timer(0.03), "timeout")
			tocar_resultado_sem_cortar_impactos("strike")
			mostrar_banner("STRIKE!", COR_STRIKE)
			_g3_estado = efeito_strike_total()
			if _g3_estado is GDScriptFunctionState:
				_g3_estado = yield(_g3_estado, "completed")

		elif foi_spare_visual:
			_enviar_led("SPARE")
			tocar_impactos_derrubada(lista_derrubados)
			yield(get_tree().create_timer(0.03), "timeout")
			tocar_resultado_sem_cortar_impactos("spare")
			mostrar_banner("SPARE!", COR_SPARE)
			_g3_estado = efeito_spare_total()
			if _g3_estado is GDScriptFunctionState:
				_g3_estado = yield(_g3_estado, "completed")

		elif derrubados_nesta_jogada == 1:
			_enviar_led("NORMAL")
			tocar_som_um_unico_pino()
			mostrar_banner("ACERTO!", Color(1.0, 0.93, 0.25))

		else:
			_enviar_led("NORMAL")
			tocar_impactos_derrubada(lista_derrubados)
			mostrar_banner("ACERTO!", Color(1.0, 0.93, 0.25))
	else:
		_enviar_led("MISS")
		tocar_som_erro_repeticao()
		mostrar_banner("PRA FORA!", COR_MISS)
		_g3_estado = efeito_miss_total()
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")

	processando_impacto = false

	if aguardando_fim_bola:
		aguardando_fim_bola = false
		jogando_trajeto = false
		_g3_estado = finalizar_jogada()
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")

		if bola != null and bola.has_method("resetar_bola"):
			bola.resetar_bola()

		if not transicao_round_em_andamento and not jogo_finalizado:
			aceitando_input = true



func _comprimento_stream(stream: AudioStream) -> float:
	if stream == null:
		return 0.0
	if stream.has_method("get_length"):
		return max(0.0, float(stream.get_length()))
	return 0.0


func _parar_roll_imediatamente_para_um_pino() -> void:
	if bola == null:
		return

	if bola.has_method("encerrar_audio_roll_para_resultado"):
		bola.encerrar_audio_roll_para_resultado(0.001)
	elif bola.has_method("_fade_out_audio_roll"):
		bola._fade_out_audio_roll(0.001)


func _propagar_colisao_curta(origem_pin, energia_base: float, dir_base: Vector2) -> void:
	if origem_pin == null:
		return
 
	var candidatos: Array = []
	var max_secundarios: int = _max_secundarios_por_tecla()
 
	for numero_vizinho in vizinhos_pinos.get(origem_pin.numero, []):
		var alvo = obter_pino_por_numero(int(numero_vizinho))
		if alvo == null or alvo.derrubado:
			continue
 
		var vetor: Vector2 = alvo.global_position - origem_pin.global_position
		var dist: float = vetor.length()
 
		var dist_max: float = 92.0
		if ultima_tecla_jogada == "C":
			dist_max = 160.0
		elif ultima_tecla_jogada in ["X", "V"]:
			dist_max = 120.0
		if dist > dist_max:
			continue
 
		var dir_viz: Vector2 = vetor.normalized()
		var alinhamento: float = max(0.0, dir_base.dot(dir_viz))
		var frente: float = clamp((origem_pin.global_position.y - alvo.global_position.y + 18.0) / 64.0, 0.0, 1.0)
		var lateralidade: float = clamp(abs(vetor.x) / 86.0, 0.0, 1.0)
 
		var energia: float = energia_base
		energia *= lerp(0.18, 0.66, alinhamento)
		energia += frente * 0.32
		energia -= lateralidade * 0.14
 
		match ultima_tecla_jogada:
			"C":
				if origem_pin.numero == 1 and alvo.numero in [2, 3, 5]:
					energia += 0.12
				elif origem_pin.numero == 5 and alvo.numero in [4, 6]:
					energia += 0.14
				elif origem_pin.numero == 5 and alvo.numero in [8, 9]:
					energia += 0.55
				elif alvo.numero in [7, 10]:
					energia += 0.40
			"X":
				if alvo.numero in [7, 8]:
					energia += 0.38
				elif alvo.numero in [4, 5]:
					energia += 0.22
			"V":
				if alvo.numero in [9, 10]:
					energia += 0.38
				elif alvo.numero in [5, 6]:
					energia += 0.22
			"Z":
				if alvo.numero == 4:
					energia += 0.04
				elif alvo.numero == 8:
					energia += 0.02
				else:
					energia -= 0.12
			"B":
				if alvo.numero == 6:
					energia += 0.04
				elif alvo.numero == 9:
					energia += 0.02
				else:
					energia -= 0.12
 
		if contar_pinos_em_pe() <= 4 and ultima_tecla_jogada != "C":
			energia *= 0.82
 
		if energia < _energia_minima_para_cair(alvo.numero):
			continue
 
		var score: float = 0.0
		score += frente * 1.95
		score += alinhamento * 1.00
		score -= lateralidade * 0.78
		score -= dist * 0.0035
 
		# ── NOVIDADE: calcula delay pela distância ao ponto de impacto ──
		# Velocidade da bola estimada em ~520 px/s.
		# Pinos mais distantes do ponto de origem recebem mais delay.
		var delay_base: float = dist / 520.0
		# Adiciona pequena variação aleatória para não parecer mecânico
		var delay_final: float = delay_base + rand_range(0.0, 0.02)
 
		candidatos.append({
			"pin": alvo,
			"energia": energia,
			"dir": dir_viz,
			"score": score,
			"dist": dist,
			"delay": delay_final
		})
 
	candidatos.sort_custom(self, "_ordem_score_decrescente")
 
	var aplicados: int = 0
	for item in candidatos:
		if aplicados >= max_secundarios:
			break
 
		var alvo = item["pin"]
		var energia: float = float(item["energia"])
		var dir_viz: Vector2 = item["dir"]
		var delay_pin: float = float(item["delay"])
 
		if alvo != null and not alvo.derrubado and alvo.has_method("receber_forca"):
			# Pequeno delay antes de aplicar a força para que pinos distantes
			# reajam depois dos pinos da frente (ordem visual correta).
			if delay_pin > 0.008:
				# Usamos call_deferred com timer para não bloquear o frame
				_aplicar_forca_com_delay(alvo, dir_viz, energia, origem_pin.global_position, delay_pin)
			else:
				alvo.receber_forca(dir_viz, energia, origem_pin.global_position)
 
			aplicados += 1


func _aplicar_forca_com_delay(alvo: Node, direcao: Vector2, energia: float, origem: Vector2, delay_s: float) -> void:
	yield(get_tree().create_timer(delay_s), "timeout")
	if alvo != null and not alvo.derrubado and alvo.has_method("receber_forca"):
		alvo.receber_forca(direcao, energia, origem)



func _aplicar_quase_queda_ao_redor(principal, derrubados_nesta_jogada: int, ponto_contato_real: Vector2) -> void:
	if principal == null:
		return

	var candidatos: Array = []
	var max_quases: int = 0

	match ultima_tecla_jogada:
		"Z", "B":
			max_quases = 1
		"X", "V":
			max_quases = 2
		"C":
			max_quases = 3
		_:
			max_quases = 1

	for numero_vizinho in vizinhos_pinos.get(principal.numero, []):
		var p = obter_pino_por_numero(int(numero_vizinho))
		if p == null or p.derrubado:
			continue

		var dist: float = principal.global_position.distance_to(p.global_position)
		var score: float = dist

		if ultima_tecla_jogada == "C" and p.numero in [4, 6, 8, 9]:
			score -= 18.0
		elif ultima_tecla_jogada == "X" and p.numero in [4, 5, 7, 8]:
			score -= 12.0
		elif ultima_tecla_jogada == "V" and p.numero in [5, 6, 9, 10]:
			score -= 12.0

		candidatos.append({
			"pin": p,
			"score": score
		})

	candidatos.sort_custom(self, "_ordem_score_crescente")

	var aplicados: int = 0
	for item in candidatos:
		if aplicados >= max_quases:
			break

		var p = item["pin"]
		if p == null or p.derrubado:
			continue

		if p.has_method("_oscilar"):
			var dir: Vector2 = (p.global_position - ponto_contato_real).normalized()
			if dir.length() <= 0.001:
				dir = Vector2(1, 0)

			# quase queda mais forte e imediata
			p._oscilar(dir, 0.92)

		elif p.has_method("abalo_lateral"):
			p.abalo_lateral(1.15)

		aplicados += 1

func obter_lado_queda_principal(ponto_impacto: Vector2, pin_principal) -> String:
	if pin_principal == null:
		return "down_rt"

	var dx: float = pin_principal.global_position.x - ponto_impacto.x

	if abs(dx) > 6.0:
		return "down_rt" if dx > 0.0 else "down_left"

	match ultima_tecla_jogada:
		"Z", "X":
			return "down_rt"
		"V", "B":
			return "down_left"
		"C":
			return "strike"
		_:
			return "strike"


func obter_pinos_no_caminho_bola(ponto_impacto: Vector2) -> Array:
	var segmento: Array = _obter_segmento_trajetoria_bola(ponto_impacto)
	var a: Vector2 = segmento[0]
	var b: Vector2 = segmento[1]
	var lista: Array = []
	var largura_extra: float = _largura_corredor_por_tecla(ultima_tecla_jogada)
	var faixa: Vector2 = faixa_valida_por_tecla(ultima_tecla_jogada)
	var em_pe_total: int = contar_pinos_em_pe()
	if em_pe_total <= 3:
		largura_extra *= 0.72
	elif em_pe_total <= 5:
		largura_extra *= 0.86

	if ultima_tecla_jogada == "C":
		var pin1 = obter_pino_por_numero(1)
		if pin1 != null and not pin1.derrubado:
			lista.append({"pin": pin1, "proj": -1.0, "dist": 0.0})

	for p in pins:
		if p == null or p.derrubado:
			continue
		if p.global_position.x < faixa.x or p.global_position.x > faixa.y:
			continue
		if ultima_tecla_jogada == "C" and p.numero == 1:
			continue
		var proj: float = _projecao_no_segmento(p.global_position, a, b)
		if proj < 0.0:
			continue
		var dist_linha: float = _distancia_ponto_segmento(p.global_position, a, b)
		var raio_pin: float = _raio_colisao_pin(p)
		var limiar: float = raio_pin + largura_extra
		if dist_linha <= limiar:
			lista.append({
				"pin": p,
				"proj": proj,
				"dist": dist_linha
			})

	lista.sort_custom(self, "_ordem_proj_crescente")
	return lista


func _garantia_borda_na_abertura() -> bool:
	return tentativa_atual == 1 and pinos_antes_da_jogada >= 10



func efeito_strike_total() -> void:
	shake_camera(9.5, 0.22, 14)
	_efeito_canaleta_strike(2.0)  # <- adicione aqui
	


	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 45
	add_child(layer)

	var flash_quente := ColorRect.new()
	Tela.cobrir_auto(flash_quente)
	flash_quente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_quente.color = Color(1.0, 0.62, 0.12, 0.0)
	layer.add_child(flash_quente)

	var flash_branco := ColorRect.new()
	Tela.cobrir_auto(flash_branco)
	flash_branco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_branco.color = Color(1, 1, 1, 0.0)
	layer.add_child(flash_branco)

	if banner_label != null:
		banner_label.rect_scale = Vector2(0.86, 0.86)
		banner_label.modulate = Color(1.0, 0.96, 0.72, 0.0)

	var tw: SceneTreeTween = create_tween()
	tw.set_parallel(true)

	tw.tween_property(flash_branco, "color", Color(1, 1, 1, 0.28), 0.035)
	tw.tween_property(flash_quente, "color", Color(1.0, 0.62, 0.12, 0.22), 0.08)

	if banner_label != null:
		tw.tween_property(banner_label, "modulate", Color(1.0, 0.96, 0.72, 1.0), 0.08)
		tw.tween_property(banner_label, "rect_scale", Vector2(1.18, 1.18), 0.11)

	yield(get_tree().create_timer(0.09), "timeout")

	var tw2: SceneTreeTween = create_tween()
	tw2.set_parallel(true)

	tw2.tween_property(flash_branco, "color", Color(1, 1, 1, 0.0), 0.10)
	tw2.tween_property(flash_quente, "color", Color(1.0, 0.62, 0.12, 0.0), 0.18)

	if banner_label != null:
		tw2.tween_property(banner_label, "rect_scale", Vector2(0.98, 0.98), 0.14)

	yield(get_tree().create_timer(0.05), "timeout")

	var tw3: SceneTreeTween = create_tween()
	tw3.set_parallel(true)

	if banner_label != null:
		tw3.tween_property(banner_label, "rect_scale", Vector2(1.06, 1.06), 0.10)

	yield(get_tree().create_timer(0.08), "timeout")

	var tw4: SceneTreeTween = create_tween()
	tw4.set_parallel(true)

	if banner_label != null:
		tw4.tween_property(banner_label, "rect_scale", Vector2(1.0, 1.0), 0.12)

	yield(get_tree().create_timer(0.20), "timeout")

	if is_instance_valid(layer):
		layer.queue_free()
	

func _on_bola_jogada_finalizada() -> void:
	var _g3_estado = null
	if processando_impacto:
		aguardando_fim_bola = true
		return

	jogando_trajeto = false
	_g3_estado = finalizar_jogada()
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")

	if bola != null and bola.has_method("resetar_bola"):
		bola.resetar_bola()

	if not transicao_round_em_andamento and not jogo_finalizado:
		aceitando_input = true



func finalizar_jogada() -> void:
	var _g3_estado = null
	aceitando_input = false

	# Espera a física terminar antes de mostrar STRIKE / SPARE / ACERTO / ERRO.
	# (Esperas mais curtas que antes: a pista travava a placa por até 6 s
	# depois de um strike. As animações continuam rodando por cima.)
	yield(get_tree().create_timer(ESPERA_FISICA_S), "timeout")

	var em_pe: int = contar_pinos_em_pe()
	var derrubados_nesta_jogada: int = max(0, pinos_antes_da_jogada - em_pe)

	pinos_derrubados_no_round += derrubados_nesta_jogada
	pinos_derrubados_no_round = min(pinos_derrubados_no_round, 10)

	atualizar_placar()
	atualizar_status()
	atualizar_mapa_visual()

	var foi_strike: bool = derrubados_nesta_jogada == 10 and tentativa_atual == 1
	var round_fechado: bool = pinos_derrubados_no_round >= 10

	if (bloquear_spare_pos_c or bloquear_spare_pos_lateral_c) and tentativa_atual >= 2:
		round_fechado = false

	if foi_strike:
		registrar_resultado_round(10, true, false)
		transicao_round_em_andamento = true
		yield(get_tree().create_timer(ESPERA_STRIKE_S), "timeout")
		_g3_estado = avancar_round()
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")
		return

	if round_fechado:
		var foi_spare: bool = not foi_strike and tentativa_atual >= 2

		registrar_resultado_round(pinos_derrubados_no_round, false, foi_spare)

		transicao_round_em_andamento = true
		yield(get_tree().create_timer(ESPERA_ROUND_FECHADO_S), "timeout")
		_g3_estado = avancar_round()
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")
		return

	if tentativa_atual < max_tentativas:
		tecla_anterior_no_round = ultima_tecla_jogada
		tentativa_atual += 1

		yield(get_tree().create_timer(ESPERA_PROXIMA_TENTATIVA_S), "timeout")

		atualizar_status()
		atualizar_hub_play()
		atualizar_placar()
		atualizar_mapa_visual()

		aceitando_input = true
		return

	registrar_resultado_round(pinos_derrubados_no_round, false, false)

	transicao_round_em_andamento = true
	yield(get_tree().create_timer(ESPERA_FIM_DE_ROUND_S), "timeout")
	_g3_estado = avancar_round()
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")



func avancar_round() -> void:
	var _g3_estado = null
	aceitando_input = false
	transicao_round_em_andamento = true
	ultima_tecla_jogada = ""
	processando_impacto = false
	aguardando_fim_bola = false
	tecla_anterior_no_round = ""
	bloquear_spare_pos_c = false
	bloquear_spare_pos_lateral_c = false
	lateral_anterior_para_c = ""

	round_atual += 1

	if round_atual > total_rounds:
		transicao_round_em_andamento = false
		finalizar_jogo()
		return

	if quantidade_jogadores > 1:
		jogador_atual = 1 if jogador_atual == 2 else 2
		ultimo_player_animado_placar = -1
	else:
		jogador_atual = 1

	tentativa_atual = 1
	pinos_derrubados_no_round = 0

	atualizar_hub_play()
	atualizar_placar()
	atualizar_mapa_visual()

	if quantidade_jogadores > 1:
		atualizar_status("PLAYER %d - sua vez!" % jogador_atual)
	else:
		atualizar_status("Preparando próximo round.")

	mostrar_round_banner(round_atual)

	yield(get_tree().create_timer(0.28), "timeout")
	_g3_estado = animar_montagem_round_ou_player()
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")

	atualizar_status()
	atualizar_hub_play()
	atualizar_placar()
	atualizar_mapa_visual()

	transicao_round_em_andamento = false
	aceitando_input = true



func finalizar_jogo() -> void:
	var _g3_estado = null
	jogo_finalizado = true
	aceitando_input = false
	jogando_trajeto = false
	processando_impacto = false
	aguardando_fim_bola = false

	var total_derrubados: int = 0
	var strikes: int = 0

	for item in historico_rounds:
		total_derrubados += int(item["derrubados"])
		if bool(item["strike"]):
			strikes += 1
			
	if hud_score_total_derrubados != null:
		hud_score_total_derrubados.text = str(total_derrubados)

	atualizar_hub_play()

	var info_recorde: Dictionary = salvar_e_obter_status_recorde(total_derrubados, strikes)
	_g3_estado = _sequencia_fim_de_jogo(total_derrubados, strikes, info_recorde)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")


func mostrar_round_banner(round_num: int) -> void:
	if round_label == null:
		return

	if quantidade_jogadores > 1:
		var rodada_do_jogador: int = int(ceil(float(round_num) / float(quantidade_jogadores)))
		round_label.text = "PLAYER %d  •  ROUND %d" % [jogador_atual, rodada_do_jogador]
	else:
		round_label.text = "ROUND %d" % round_num

	var cor = Color(0.55, 0.92, 1.0)
	_aplicar_fonte_arcade(round_label, TAM_ROUND_AVISO, cor)
	_animar_label_arcade(round_label, cor, false)


func mostrar_banner(texto: String, cor: Color) -> void:
	if banner_label == null:
		return

	var t = texto.to_upper()
	var eh_strike = Compat.contem(t, "STRIKE")

	banner_label.text = texto

	if eh_strike:
		_aplicar_fonte_arcade(banner_label, TAM_AVISO_STRIKE, cor)
	else:
		_aplicar_fonte_arcade(banner_label, TAM_AVISO_PADRAO, cor)

	_animar_label_arcade(banner_label, cor, eh_strike)



func shake_camera(forca: float = 5.0, duracao: float = 0.15, passos: int = 8) -> void:
	if camera_jogo == null:
		return

	_call_shake_camera_async(forca, duracao, passos)


func _call_shake_camera_async(forca: float, duracao: float, passos: int) -> void:
	var _g3_estado = null
	_g3_estado = _shake_camera_async(forca, duracao, passos)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")


func _shake_camera_async(forca: float = 5.0, duracao: float = 0.15, passos: int = 8) -> void:
	if camera_jogo == null:
		return

	passos = max(passos, 1)

	for i in range(passos):
		var decaimento: float = 1.0 - (float(i) / float(passos))
		var ox: float = rand_range(-forca, forca) * decaimento
		var oy: float = rand_range(-forca * 0.90, forca * 0.90) * decaimento
		camera_jogo.offset = camera_base_offset + Vector2(ox, oy)
		yield(get_tree().create_timer(duracao / passos), "timeout")

	camera_jogo.offset = camera_base_offset


## A PANCADA DO CONTATO: tranco curto na câmera (tremida forte e rápida e
## um soco de zoom) no instante em que a bola chega nos pinos. Na bola no
## centro com o rack cheio (o strike), o tranco é maior. Sem flash na tela
## (o flash antigo deixava névoa no ponto de contato).
func efeito_impacto_deck(pos: Vector2, intensidade: float = 1.0) -> void:
	var cheio: bool = tentativa_atual == 1 and contar_pinos_em_pe() == 10
	var forte: bool = ultima_tecla_jogada == "C" and cheio
	shake_camera((8.5 if forte else 5.0) * intensidade, 0.10 if forte else 0.08, 7 if forte else 5)
	if camera_jogo == null:
		return
	var base: Vector2 = camera_zoom_idle
	var tw = create_tween()
	tw.tween_property(camera_jogo, "zoom", base * (1.045 if forte else 1.025), 0.05)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera_jogo, "zoom", base, 0.22)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _configurar_audio_menu_final() -> void:
	if audio_menu_final_player != null:
		return

	audio_menu_final_player = get_node_or_null("MenuFinalMusic") as AudioStreamPlayer
	if audio_menu_final_player == null:
		audio_menu_final_player = AudioStreamPlayer.new()
		audio_menu_final_player.name = "MenuFinalMusic"
		add_child(audio_menu_final_player)

	audio_menu_final_player.bus = "Master"
	audio_menu_final_player.autoplay = false
	audio_menu_final_player.volume_db = VOLUME_MUSICA_MENU_FINAL_DB

	if ResourceLoader.exists(CAMINHO_MUSICA_MENU_FINAL):
		musica_menu_final = load(CAMINHO_MUSICA_MENU_FINAL)
		audio_menu_final_player.stream = musica_menu_final
	else:
		push_warning("Música da tela final não encontrada em: " + CAMINHO_MUSICA_MENU_FINAL)

func _tocar_musica_tela_final() -> void:
	_configurar_audio_menu_final()

	if audio_menu_final_player == null:
		return

	if audio_menu_final_player.stream == null:
		return

	if audio_menu_final_player.playing:
		audio_menu_final_player.stop()

	audio_menu_final_player.play(OFFSET_INICIAL_MUSICA_FINAL)


func _parar_musica_tela_final() -> void:
	if audio_menu_final_player != null and audio_menu_final_player.playing:
		audio_menu_final_player.stop()
		

func salvar_e_obter_status_recorde(total_derrubados: int, strikes: int) -> Dictionary:
	var cfg: ConfigFile = ConfigFile.new()
	var path: String = "user://dragon_bowling_save.cfg"
	var err: int = cfg.load(path)

	if err != OK:
		cfg.set_value("records", "best_total", 0)
		cfg.set_value("records", "best_strikes", 0)

	var best_total: int = int(cfg.get_value("records", "best_total", 0))
	var best_strikes: int = int(cfg.get_value("records", "best_strikes", 0))

	var novo_recorde: bool = false

	if total_derrubados > best_total:
		best_total = total_derrubados
		novo_recorde = true

	if strikes > best_strikes:
		best_strikes = strikes
		novo_recorde = true

	cfg.set_value("records", "best_total", best_total)
	cfg.set_value("records", "best_strikes", best_strikes)
	cfg.save(path)

	return {
		"novo_recorde": novo_recorde,
		"best_total": best_total,
		"best_strikes": best_strikes
	}


func animar_montagem_round_ou_player() -> void:
	var _g3_estado = null
	aceitando_input = false

	# Some os pinos antigos suavemente antes de montar o novo rack.
	for p in pins:
		if p == null:
			continue

		if p is CanvasItem:
			var tw_out = create_tween()
			tw_out.tween_property(p, "modulate:a", 0.0, 0.16)

	yield(get_tree().create_timer(0.18), "timeout")

	criar_10_pinos()

	for p in pins:
		if p == null:
			continue

		if p.has_method("resetar"):
			p.resetar()

		if p is CanvasItem:
			p.modulate = Color(1, 1, 1, 0.0)

		if p is Node2D:
			var base_pos: Vector2 = p.position
			p.set_meta("intro_base_pos", base_pos)
			p.position = base_pos + Vector2(0, -DESCIDA_MONTAGEM_PINOS)

	_g3_estado = animar_pinos_em_cascata()
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")

	if bola != null and bola.has_method("resetar_bola"):
		bola.resetar_bola()

	if bola != null and bola is Node2D:
		var base_bola: Vector2 = bola.position
		bola.set_meta("intro_base_pos", base_bola)
		bola.position = base_bola + Vector2(0, 110)

		if bola is CanvasItem:
			bola.modulate = Color(1, 1, 1, 0.0)

	_g3_estado = animar_bola_entrada()
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")


func mostrar_tela_final(total_derrubados: int, strikes: int, info_recorde: Dictionary) -> void:
	_tocar_musica_tela_final()

	retorno_em_andamento = false
	tela_final_ativa = true
	tempo_restante_tela_final = tempo_tela_final
	anim_tela_final_t = 0.0
	overlay_final.visible = true
	
	if final_logo != null:
		final_logo.rect_size = Vector2(280, 105)
		final_logo.rect_pivot_offset = final_logo.rect_size * 0.5
		final_logo.rect_scale = Vector2.ONE

	var rounds_jogados: int = _calcular_rounds_jogados()
	var media_por_rodada: float = _calcular_media_derrubagem_por_rodada(total_derrubados)
	var eficiencia: int = _calcular_eficiencia_por_rodada(total_derrubados)

	var modo_dupla = quantidade_jogadores > 1

	if final_card_p1 != null:
		final_card_p1.visible = modo_dupla
	if final_card_p2 != null:
		final_card_p2.visible = modo_dupla
	if final_card_single != null:
		final_card_single.visible = not modo_dupla

	if modo_dupla:
		var p1 = total_pinos_jogador(1)
		var p2 = total_pinos_jogador(2)
		var s1 = total_strikes_jogador(1)
		var s2 = total_strikes_jogador(2)
		var r1: int = max(historico_jogador_1.size(), 1)
		var r2: int = max(historico_jogador_2.size(), 1)
		var m1: float = float(p1) / float(r1)
		var m2: float = float(p2) / float(r2)

		var vencedor_p1 = p1 > p2 or (p1 == p2 and s1 > s2)
		var vencedor_p2 = p2 > p1 or (p1 == p2 and s2 > s1)
		var empate = not vencedor_p1 and not vencedor_p2

		if empate:
			final_titulo.text = "🤝  EMPATE ENTRE PLAYERS"
		elif vencedor_p1:
			final_titulo.text = "🏆  PLAYER 1 VENCEU!"
		else:
			final_titulo.text = "🏆  PLAYER 2 VENCEU!"

		_aplicar_fonte_arcade(final_titulo, 46, COR_TEXTO_YELLOW)

		if final_p1_stats != null:
			final_p1_stats.text = "PINOS:  %d\nSTRIKES:  %d\nRODADAS:  %d\nMÉDIA:  %.1f" % [p1, s1, r1, m1]

		if final_p2_stats != null:
			final_p2_stats.text = "PINOS:  %d\nSTRIKES:  %d\nRODADAS:  %d\nMÉDIA:  %.1f" % [p2, s2, r2, m2]

		_aplicar_vencedor_card(final_card_p1, final_p1_titulo, final_p1_badge, COR_TEXTO_CYAN, vencedor_p1 or empate)
		_aplicar_vencedor_card(final_card_p2, final_p2_titulo, final_p2_badge, Color(1.0, 0.22, 0.18), vencedor_p2 or empate)

		if empate:
			if final_p1_badge != null:
				final_p1_badge.text = "EMPATE"
			if final_p2_badge != null:
				final_p2_badge.text = "EMPATE"

	else:
		final_titulo.text = "RESULTADO FINAL"
		_aplicar_fonte_arcade(final_titulo, 52, COR_TEXTO_YELLOW)

		if final_single_stats != null:
			final_single_stats.text = "PINOS:  %d\nSTRIKES:  %d\nRODADAS:  %d\nMÉDIA:  %.1f\nEFICIÊNCIA:  %d%%" % [
				total_derrubados,
				strikes,
				rounds_jogados,
				media_por_rodada,
				eficiencia
			]

	if bool(info_recorde.get("novo_recorde", false)) and not modo_dupla:
		final_recorde.text = "🏆  NOVO RECORDE!"
		_aplicar_fonte_painel(final_recorde, 29, COR_TEXTO_YELLOW, 5)
	else:
		final_recorde.text = "RECORDE  •  PINOS: %d  •  STRIKES: %d" % [
			int(info_recorde.get("best_total", 0)),
			int(info_recorde.get("best_strikes", 0))
		]
		_aplicar_fonte_painel(final_recorde, 24, COR_TEXTO_CYAN, 5)

	final_timer.text = "RETORNO EM: %d" % int(ceil(tempo_restante_tela_final))
	_aplicar_fonte_painel(final_timer, 24, COR_TEXTO_YELLOW, 5)

	centralizar_tela_final()

	final_bg.color = Color(0, 0, 0, 0.86)
	final_panel.modulate.a = 0.0
	final_titulo.modulate.a = 0.0
	final_logo.modulate.a = 0.0
	final_recorde.modulate.a = 0.0
	final_timer.modulate.a = 0.0

	if final_card_p1 != null:
		final_card_p1.modulate.a = 0.0
	if final_card_p2 != null:
		final_card_p2.modulate.a = 0.0
	if final_card_single != null:
		final_card_single.modulate.a = 0.0

	if fim_panel_glow != null:
		fim_panel_glow.modulate.a = 0.0
	if fim_linha_topo != null:
		fim_linha_topo.modulate.a = 0.0
	if fim_linha_base != null:
		fim_linha_base.modulate.a = 0.0

	if final_start_botao != null:
		final_start_botao.visible = false
		final_start_botao.rect_scale = Vector2.ONE

	if final_start_glow != null:
		final_start_glow.visible = false
		final_start_glow.modulate.a = 0.0

	var tw = create_tween()
	tw.set_parallel(true)

	tw.tween_property(final_panel, "modulate:a", 1.0, 0.22)
	tw.tween_property(final_titulo, "modulate:a", 1.0, 0.25)
	tw.tween_property(final_logo, "modulate:a", 1.0, 0.32)
	tw.tween_property(final_recorde, "modulate:a", 1.0, 0.45)
	tw.tween_property(final_timer, "modulate:a", 1.0, 0.52)

	if modo_dupla:
		tw.tween_property(final_card_p1, "modulate:a", 1.0, 0.35)
		tw.tween_property(final_card_p2, "modulate:a", 1.0, 0.45)
		tw.tween_property(final_card_p1, "rect_position:y", final_card_p1.rect_position.y - 8, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(final_card_p2, "rect_position:y", final_card_p2.rect_position.y - 8, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(final_card_single, "modulate:a", 1.0, 0.38)
		tw.tween_property(final_card_single, "rect_scale", Vector2(1.04, 1.04), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if fim_panel_glow != null:
		tw.tween_property(fim_panel_glow, "modulate:a", 1.0, 0.25)
	if fim_linha_topo != null:
		tw.tween_property(fim_linha_topo, "modulate:a", 1.0, 0.32)
	if fim_linha_base != null:
		tw.tween_property(fim_linha_base, "modulate:a", 1.0, 0.38)

	yield(tw, "finished")

	if final_start_botao != null:
		final_start_botao.visible = true
		final_start_botao.disabled = false

	if final_start_glow != null:
		final_start_glow.visible = true
		final_start_glow.modulate.a = 0.34

	_iniciar_idle_botao_final()



func ocultar_tela_final() -> void:
	tela_final_ativa = false
	final_intro_em_andamento = false
	reinicio_com_credito_em_andamento = false
	retorno_em_andamento = false
	tempo_restante_tela_final = 0.0
	anim_tela_final_t = 0.0

	if overlay_final != null:
		overlay_final.visible = false

func voltar_para_main() -> void:
	_parar_musica_tela_final()
	
	var caminho: String = cena_main_path.strip_edges()

	if caminho.empty():
		caminho = "res://scene/Main Menu.tscn"

	if not ResourceLoader.exists(caminho):
		push_error("Cena não encontrada: " + caminho)
		return

	Cortina.trocar_para(get_tree(), caminho)
	



func _aguardar_fade_roll_da_bola() -> void:
	var _g3_estado = null
	if bola == null:
		return
	if bola.has_method("encerrar_audio_roll_para_resultado"):
		_g3_estado = bola.encerrar_audio_roll_para_resultado(fade_out_roll_antes_resultado)
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")
	elif bola.has_method("_fade_out_audio_roll"):
		_g3_estado = bola._fade_out_audio_roll(fade_out_roll_antes_resultado)
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")


func _tocar_resultado_da_jogada(tipo: String) -> void:
	var _g3_estado = null
	_g3_estado = _aguardar_fade_roll_da_bola()
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")
	tocar_som_resultado(tipo)


func _carregar_stream_por_caminho(caminho: String) -> AudioStream:
	if caminho == "":
		return null
	if not ResourceLoader.exists(caminho):
		return null
	var recurso = load(caminho)
	if recurso is AudioStream:
		return recurso
	return null


func _resolver_stream_resultado_personalizado(tipo: String) -> AudioStream:
	match tipo:
		"song_ini":
			if audio_song_ini != null:
				return audio_song_ini
			if audio_jogada_borda != null:
				return audio_jogada_borda
			return _carregar_stream_por_caminho(CAMINHO_AUDIO_SONG_INI)
		"song_play":
			if audio_song_play != null:
				return audio_song_play
			if audio_jogada_lateral != null:
				return audio_jogada_lateral
			return _carregar_stream_por_caminho(CAMINHO_AUDIO_SONG_PLAY)
	return null


func _obter_stream_jogada_normal() -> AudioStream:
	# Jogada normal não toca mais resultado próprio no principal.
	# Z/B usam song_ini no início.
	# X/C/V usam bola_roll na bola.
	return null

func _obter_volume_jogada_normal() -> float:
	match ultima_tecla_jogada:
		"Z", "B":
			return volume_jogada_borda_db
		"X", "V":
			return volume_jogada_lateral_db
		"C":
			return volume_jogada_centro_db
	return volume_resultado_normal_db


func _obter_prolongar_jogada_normal() -> bool:
	match ultima_tecla_jogada:
		"Z", "B":
			return prolongar_jogada_borda
		"X", "V":
			return prolongar_jogada_lateral
		"C":
			return prolongar_jogada_centro
	return prolongar_resultado_normal


func _obter_duracao_jogada_normal() -> float:
	match ultima_tecla_jogada:
		"Z", "B":
			return duracao_min_jogada_borda
		"X", "V":
			return duracao_min_jogada_lateral
		"C":
			return duracao_min_jogada_centro
	return duracao_min_resultado_normal


func _obter_offset_inicio_jogada_normal() -> float:
	match ultima_tecla_jogada:
		"Z":
			return offset_inicio_jogada_z
		"X":
			return offset_inicio_jogada_x
		"C":
			return offset_inicio_jogada_c
		"V":
			return offset_inicio_jogada_v
		"B":
			return offset_inicio_jogada_b
	return 0.0





func limpar_players_invalidos(lista: Array) -> void:
	for i in range(lista.size() - 1, -1, -1):
		var p = lista[i]
		if not is_instance_valid(p):
			lista.remove(i)


func _parar_resultado_atual() -> void:
	if is_instance_valid(player_resultado_atual):
		player_resultado_atual.stop()
		player_resultado_atual.queue_free()
	player_resultado_atual = null


func _parar_inicio_jogada_atual() -> void:
	if is_instance_valid(player_inicio_jogada_atual):
		player_inicio_jogada_atual.stop()
		player_inicio_jogada_atual.queue_free()
	player_inicio_jogada_atual = null


func _criar_player_resultado_unico(stream: AudioStream, volume_db: float, nome_base: String = "SfxResultadoTemp", inicio_em_segundos: float = 0.0) -> AudioStreamPlayer:
	if stream == null:
		return null

	_parar_resultado_atual()

	var player := AudioStreamPlayer.new()
	player.name = nome_base
	player.bus = "Master"
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)

	player_resultado_atual = player
	player.play()

	if inicio_em_segundos > 0.0:
		var duracao: float = 0.0
		if stream.has_method("get_length"):
			duracao = float(stream.get_length())
		if duracao <= 0.05 or inicio_em_segundos < duracao:
			player.seek(inicio_em_segundos)

	player.connect("finished", self, "_liberar_player_resultado", [player])

	return player


func _criar_player_temporario(stream: AudioStream, volume_db: float, nome_base: String, lista_controle: Array, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	if stream == null:
		return null

	limpar_players_invalidos(lista_controle)

	var player := AudioStreamPlayer.new()
	player.name = nome_base
	player.bus = "Master"
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	lista_controle.append(player)
	player.play()

	player.connect("finished", self, "_liberar_player_da_lista", [player, lista_controle])

	return player


func tocar_som_impacto_individual(volume_db: float = volume_impacto_pino_db) -> void:
	if not tocar_impacto_pinos:
		return

	if audio_impacto_pino == null:
		push_warning("audio_impacto_pino está vazio.")
		return

	limpar_players_invalidos(players_impacto_ativos)

	if max_players_impacto > 0 and players_impacto_ativos.size() >= max_players_impacto:
		return

	var player := AudioStreamPlayer.new()
	player.name = "SfxImpactoPinTemp"
	player.bus = "Master"
	player.stream = audio_impacto_pino
	player.volume_db = volume_db
	add_child(player)

	players_impacto_ativos.append(player)
	player.play()

	player.connect("finished", self, "_liberar_player_da_lista", [player, players_impacto_ativos])


func tocar_impactos_derrubada(lista: Array) -> void:
	if lista.empty():
		return

	if ultima_tecla_jogada in ["Z", "B"]:
		return

	if not tocar_impacto_pinos:
		return

	var validos: Array = []
	for item in lista:
		if item is Dictionary and item.has("pin"):
			var pin = item["pin"]
			if pin != null:
				validos.append(item)

	if validos.empty():
		return

	if validos.size() < max(1, impacto_min_pinos_para_tocar):
		return

	var snapshot: Array = validos.duplicate(true)
	_call_tocar_impactos_async(snapshot)



func _call_tocar_impactos_async(lista: Array) -> void:
	var _g3_estado = null
	_g3_estado = _tocar_impactos_derrubada_async(lista)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")

func _tocar_impactos_derrubada_async(lista: Array) -> void:
	if not tocar_impacto_pinos:
		return
	if lista.empty():
		return

	var itens_validos: Array = []
	for item in lista:
		if item is Dictionary and item.has("pin"):
			var pin = item["pin"]
			if pin != null:
				itens_validos.append(item)

	if itens_validos.empty():
		return

	# UM SOM SÓ PARA O GRUPO TODO
	var qtd: int = itens_validos.size()
	var peso_total: float = 0.0

	for item in itens_validos:
		peso_total += float(item.get("peso", 1.0))

	var peso_medio: float = peso_total / max(1.0, float(qtd))

	var volume_grupo: float = volume_impacto_pino_db
	volume_grupo += min(float(qtd - 1) * 0.45, 2.2)
	volume_grupo += clamp((peso_medio - 1.0) * 1.6, -0.5, 1.4)
	volume_grupo += rand_range(-0.25, 0.25)
	volume_grupo = clamp(volume_grupo, -8.0, 4.0)

	tocar_som_impacto_individual(volume_grupo)


## O som do lançamento sai junto com a bola na tela: espera o quadro em
## que ela já foi desenhada (e a folga de GameConfig), sem segurar nada.
func _tocar_som_inicio_com_a_bola() -> void:
	var esta_jogada = token_jogada_atual
	yield(VisualServer, "frame_post_draw")
	if GameConfig.atraso_som_jogada > 0.0:
		yield(get_tree().create_timer(GameConfig.atraso_som_jogada), "timeout")
	if esta_jogada != token_jogada_atual or not is_inside_tree():
		return
	tocar_som_inicio_da_jogada()


func tocar_som_inicio_da_jogada() -> void:
	if inicio_audio_tocado_na_jogada:
		return

	inicio_audio_tocado_na_jogada = true

	var stream: AudioStream = null
	var volume_db: float = 0.0
	var pitch: float = 1.0
	var offset: float = 0.0

	match ultima_tecla_jogada:
		"Z":
			stream = audio_jogada_borda
			volume_db = volume_jogada_borda_db
			pitch = pitch_song_play
			offset = offset_inicio_jogada_z
		"X":
			stream = audio_jogada_lateral
			volume_db = volume_jogada_lateral_db
			pitch = pitch_song_play
			offset = offset_inicio_jogada_x
		"C":
			stream = audio_jogada_centro
			volume_db = volume_jogada_centro_db
			pitch = pitch_song_play
			offset = offset_inicio_jogada_c
		"V":
			stream = audio_jogada_lateral
			volume_db = volume_jogada_lateral_db
			pitch = pitch_song_play
			offset = offset_inicio_jogada_v
		"B":
			stream = audio_jogada_borda
			volume_db = volume_jogada_borda_db
			pitch = pitch_song_play
			offset = offset_inicio_jogada_b

	if stream == null:
		stream = audio_song_play
		volume_db = volume_song_play_db
		pitch = pitch_song_play
		offset = 0.0

	player_inicio_jogada_atual = _tocar_stream_em_pool(pool_audio_roll, stream, volume_db, pitch, max(0.0, offset))


func tocar_som_resultado(tipo: String) -> void:
	tocar_resultado_sem_cortar_impactos(tipo)


func _obter_stream_strike_por_ordem(ordem_strike: int) -> AudioStream:
	match ordem_strike:
		1:
			if audio_strike_1 != null:
				return audio_strike_1
			return _carregar_stream_por_caminho(CAMINHO_AUDIO_STRIKE_1)
		2:
			if audio_strike_2 != null:
				return audio_strike_2
			return _carregar_stream_por_caminho(CAMINHO_AUDIO_STRIKE_2)
		3:
			if audio_strike_3 != null:
				return audio_strike_3
			return _carregar_stream_por_caminho(CAMINHO_AUDIO_STRIKE_3)

	if audio_strike_3 != null:
		return audio_strike_3
	return _carregar_stream_por_caminho(CAMINHO_AUDIO_STRIKE_3)


func tocar_som_strike_progressivo() -> void:
	tocar_resultado_sem_cortar_impactos("strike")


func tocar_som_fora() -> void:
	var stream_escolhido: AudioStream = audio_fora
	if stream_escolhido == null:
		stream_escolhido = _carregar_stream_por_caminho(CAMINHO_AUDIO_FORA)

	if stream_escolhido == null:
		return

	_criar_player_resultado_unico(stream_escolhido, volume_fora_db, "SfxForaTemp", 0.0)

func tocar_som_erro_repeticao() -> void:
	var stream_escolhido: AudioStream = audio_erro_repeticao

	if stream_escolhido == null:
		stream_escolhido = _carregar_stream_por_caminho(CAMINHO_AUDIO_ERRO_REPETICAO)

	if stream_escolhido == null:
		return

	_criar_player_resultado_unico(stream_escolhido, volume_erro_repeticao_db, "SfxErroRepeticaoTemp", 0.0)
	
	
func tocar_som_um_unico_pino() -> void:
	if resultado_audio_tocado_na_jogada:
		return

	var stream_escolhido: AudioStream = _resolver_stream_resultado_personalizado("song_ini")
	if stream_escolhido == null:
		return

	_parar_resultado_atual()
	_parar_inicio_jogada_atual()
	_parar_roll_imediatamente_para_um_pino()

	resultado_audio_tocado_na_jogada = true

	var player := AudioStreamPlayer.new()
	player.name = "SfxUmPinoTemp"
	player.bus = "Master"
	player.stream = stream_escolhido
	player.volume_db = volume_song_ini_db + 4.0
	player.pitch_scale = 1.0
	add_child(player)

	player_resultado_atual = player
	player.play()

	player.connect("finished", self, "_liberar_player_resultado", [player])


func tocar_resultado_sem_cortar_impactos(tipo: String) -> void:
	if resultado_audio_tocado_na_jogada:
		return

	if tipo in ["strike", "spare", "miss"]:
		_parar_inicio_jogada_atual()

	var stream_escolhido: AudioStream = null
	var volume_escolhido: float = 0.0

	match tipo:
		"strike":
			var ordem_strike: int = 1

			if quantidade_jogadores > 1:
				if jogador_atual == 1:
					ordem_strike = clamp(contador_strikes_jogador_1 + 1, 1, 3)
				else:
					ordem_strike = clamp(contador_strikes_jogador_2 + 1, 1, 3)
			else:
				ordem_strike = clamp(contador_strikes_no_jogo + 1, 1, 3)

			stream_escolhido = _obter_stream_strike_por_ordem(ordem_strike)
			volume_escolhido = volume_strike_progressivo_db

		"spare":
			if audio_resultado_spare != null:
				stream_escolhido = audio_resultado_spare
			else:
				stream_escolhido = _carregar_stream_por_caminho("res://songs/spare.wav")
			volume_escolhido = volume_resultado_spare_db

		"miss":
			stream_escolhido = audio_resultado_miss
			volume_escolhido = volume_resultado_miss_db

		_:
			return

	if stream_escolhido == null:
		return

	resultado_audio_tocado_na_jogada = true

	var player := AudioStreamPlayer.new()
	player.name = "SfxResultadoParaleloTemp"
	player.bus = "Master"
	player.stream = stream_escolhido
	player.volume_db = volume_escolhido
	add_child(player)

	player_resultado_atual = player
	player.play()

	player.connect("finished", self, "_liberar_player_resultado", [player])

	if tipo == "strike":
		contador_strikes_no_jogo = min(contador_strikes_no_jogo + 1, 999)

		if quantidade_jogadores > 1:
			if jogador_atual == 1:
				contador_strikes_jogador_1 = min(contador_strikes_jogador_1 + 1, 3)
			else:
				contador_strikes_jogador_2 = min(contador_strikes_jogador_2 + 1, 3)


func total_pinos_jogador(player_id: int) -> int:
	var total: int = 0
	var lista: Array = historico_jogador_1 if player_id == 1 else historico_jogador_2

	for item in lista:
		total += int(item.get("derrubados", 0))

	return total


func total_strikes_jogador(player_id: int) -> int:
	var total: int = 0
	var lista: Array = historico_jogador_1 if player_id == 1 else historico_jogador_2

	for item in lista:
		if bool(item.get("strike", false)):
			total += 1

	return total


func texto_vencedor_2_players() -> String:
	var p1: int = total_pinos_jogador(1)
	var p2: int = total_pinos_jogador(2)

	var s1: int = total_strikes_jogador(1)
	var s2: int = total_strikes_jogador(2)

	if p1 > p2:
		return "🏆 VENCEDOR: PLAYER 1"
	elif p2 > p1:
		return "🏆 VENCEDOR: PLAYER 2"

	if s1 > s2:
		return "🏆 VENCEDOR: PLAYER 1 NOS STRIKES"
	elif s2 > s1:
		return "🏆 VENCEDOR: PLAYER 2 NOS STRIKES"

	return "🤝 EMPATE ENTRE OS PLAYERS"



# SUBSTITUA a função _ha_pino_frontal_para_jogada por esta:
func _ha_pino_frontal_para_jogada(tecla: String) -> bool:
	return not _pinos_da_faixa_em_pe(tecla).empty()


func _tratar_jogada_sem_alvo_na_faixa() -> void:
	var _g3_estado = null
	processando_impacto = false

	if bola != null and bola.has_method("tocar_passagem_reta"):
		_g3_estado = bola.tocar_passagem_reta()
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")

	# erro apenas
	tocar_som_erro_repeticao()
	mostrar_banner("PRA FORA!", COR_MISS)
	_g3_estado = efeito_miss_total()
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")

	if aguardando_fim_bola:
		aguardando_fim_bola = false
		jogando_trajeto = false
		_g3_estado = finalizar_jogada()
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")

		if bola != null and bola.has_method("resetar_bola"):
			bola.resetar_bola()

		if not transicao_round_em_andamento and not jogo_finalizado:
			aceitando_input = true


func _tocar_musica_final() -> void:
	if audio_musica_final == null:
		return

	var player := AudioStreamPlayer.new()
	player.name = "MusicaFinalTemp"
	player.stream = audio_musica_final
	player.volume_db = volume_musica_final_db
	player.bus = "Master"
	add_child(player)
	player.play()

func _resolver_stream_end_game() -> AudioStream:
	if audio_end_game != null:
		return audio_end_game
	return _carregar_stream_por_caminho(CAMINHO_AUDIO_END_GAME)


func _resolver_stream_coin() -> AudioStream:
	if audio_coin != null:
		return audio_coin
	return _carregar_stream_por_caminho(CAMINHO_AUDIO_COIN)


func _tocar_audio_unico_ate_fim(stream: AudioStream, volume_db: float, nome_base: String, cortar_final_segundos: float = 0.0) -> void:
	if stream == null:
		return

	var player: AudioStreamPlayer = _criar_player_resultado_unico(stream, volume_db, nome_base, 0.0)
	if player == null:
		return

	var duracao: float = 0.0
	if stream.has_method("get_length"):
		duracao = float(stream.get_length())

	duracao = max(0.1, duracao - max(0.0, cortar_final_segundos))

	yield(get_tree().create_timer(duracao), "timeout")

	if is_instance_valid(player) and player.playing:
		player.stop()


func _efeito_fim_de_jogo_visual() -> void:
	shake_camera(6.0, 0.16, 10)

	if overlay_final == null or final_bg == null or final_titulo == null or final_panel == null:
		return

	overlay_final.visible = true
	final_bg.color = Color(0, 0, 0, 0.0)

	if fim_panel_glow != null:
		fim_panel_glow.modulate.a = 0.0
	if fim_panel_borda != null:
		fim_panel_borda.modulate.a = 0.0
	if fim_linha_topo != null:
		fim_linha_topo.modulate.a = 0.0
	if fim_linha_base != null:
		fim_linha_base.modulate.a = 0.0

	if final_start_botao != null:
		final_start_botao.visible = false
		final_start_botao.modulate = Color(1, 1, 1, 1)
		final_start_botao.rect_scale = Vector2.ONE

	if final_start_glow != null:
		final_start_glow.visible = false
		final_start_glow.modulate.a = 0.0

	final_panel.modulate.a = 0.0
	final_titulo.text = "FIM DE JOGO"
	final_titulo.add_color_override("font_color", Color(1.0, 0.42, 0.18))
	final_titulo.add_color_override("font_outline_modulate", Color(1.0, 0.86, 0.32))
	Compat.contorno(final_titulo, 10)
	final_titulo.modulate = Color(1, 1, 1, 0.0)
	final_titulo.rect_scale = Vector2.ONE
	final_titulo.rect_rotation = 0.0

	if final_logo != null:
		final_logo.rect_size = Vector2(440, 165)
		final_logo.rect_pivot_offset = final_logo.rect_size * 0.5
		final_logo.modulate = Color(1, 1, 1, 0.0)
		final_logo.rect_scale = Vector2(0.72, 0.72)

	var tela: Vector2 = Tela.retangulo().size
	var centro_x: float = tela.x * 0.5
	var centro_y: float = tela.y * 0.5

	final_titulo.rect_position = Vector2(centro_x - final_titulo.rect_size.x * 0.5, centro_y - 110.0)

	if final_logo != null:
		final_logo.rect_position = Vector2(centro_x - final_logo.rect_size.x * 0.5, centro_y + 0.0)

	var entrada = create_tween()
	entrada.set_parallel(true)
	entrada.tween_property(final_bg, "color", Color(0, 0, 0, 0.86), 0.12)
	entrada.tween_property(final_titulo, "modulate:a", 1.0, 0.10)
	if final_logo != null:
		entrada.tween_property(final_logo, "modulate:a", 1.0, 0.14)
		entrada.tween_property(final_logo, "rect_scale", Vector2(1.55, 1.55), 0.22)

	yield(entrada, "finished")

	var brilho = create_tween()
	brilho.set_parallel(true)
	brilho.tween_property(final_titulo, "modulate", Color(1.08, 1.02, 0.96, 1.0), 0.10)
	if final_logo != null:
		brilho.tween_property(final_logo, "modulate", Color(1.08, 1.08, 1.08, 1.0), 0.10)

	yield(brilho, "finished")

	var volta = create_tween()
	volta.set_parallel(true)
	volta.tween_property(final_titulo, "modulate", Color(1, 1, 1, 1.0), 0.12)
	if final_logo != null:
		volta.tween_property(final_logo, "modulate", Color(1, 1, 1, 1.0), 0.12)

	yield(volta, "finished")

	

func _sequencia_fim_de_jogo(total_derrubados: int, strikes: int, info_recorde: Dictionary) -> void:
	var _g3_estado = null
	final_intro_em_andamento = true
	reinicio_com_credito_em_andamento = false
	retorno_em_andamento = false
	tela_final_ativa = true
	tempo_restante_tela_final = tempo_tela_final
	anim_tela_final_t = 0.0

	if overlay_final != null:
		overlay_final.visible = true

	if final_panel != null:
		final_panel.modulate.a = 0.0
	if final_stats != null:
		final_stats.modulate.a = 0.0
	if final_recorde != null:
		final_recorde.modulate.a = 0.0
	if final_timer != null:
		final_timer.modulate.a = 0.0
		final_timer.text = ""
	if final_start != null:
		final_start.modulate.a = 0.0

	_parar_musica_tela_final()
	_parar_resultado_atual()
	_parar_inicio_jogada_atual()

	_g3_estado = _efeito_fim_de_jogo_visual()
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")
	_g3_estado = _tocar_audio_unico_ate_fim(_resolver_stream_end_game(), volume_end_game_db, "SfxEndGameTemp", 2.0)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")

	_g3_estado = mostrar_tela_final(total_derrubados, strikes, info_recorde)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")
	final_intro_em_andamento = false


func _reiniciar_com_credito() -> void:
	var _g3_estado = null
	aceitando_input = false
	retorno_em_andamento = true

	_animar_click_botao_final()
	yield(get_tree().create_timer(0.10), "timeout")

	var stream_coin: AudioStream = _resolver_stream_coin()

	_parar_musica_tela_final()
	_g3_estado = _tocar_audio_unico_ate_fim(stream_coin, volume_coin_db, "SfxCoinTemp", 0.0)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")

	# ── Preserva o modo da partida anterior ──────────────────────────────────
	var modo_anterior: int = quantidade_jogadores
	if has_node("/root/GameConfig"):
		get_node("/root/GameConfig").jogadores = modo_anterior

	ocultar_tela_final()
	iniciar_jogo()
	reinicio_com_credito_em_andamento = false



func criar_cortina_inicio() -> void:
	if overlay_transicao_inicio != null:
		return

	overlay_transicao_inicio = CanvasLayer.new()
	overlay_transicao_inicio.layer = 300
	add_child(overlay_transicao_inicio)

	cortina_inicio = ColorRect.new()
	Tela.cobrir_auto(cortina_inicio)
	cortina_inicio.color = Color(0, 0, 0, 1.0)
	cortina_inicio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_transicao_inicio.add_child(cortina_inicio)
	
	
func revelar_cena_com_suavidade() -> void:
	if cortina_inicio == null:
		return

	var tw: SceneTreeTween = create_tween()
	tw.tween_property(cortina_inicio, "color", Color(0, 0, 0, 0.0), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	yield(tw, "finished")

	if overlay_transicao_inicio != null:
		overlay_transicao_inicio.queue_free()
		overlay_transicao_inicio = null
		cortina_inicio = null


func _criar_player_audio(bus_name: String = "Master") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	add_child(p)
	return p


func _inicializar_pools_de_audio() -> void:
	pool_audio_fx.clear()
	pool_audio_roll.clear()
	pool_audio_resultado.clear()

	for i in range(MAX_AUDIO_PLAYERS_PADRAO):
		pool_audio_fx.append(_criar_player_audio("Master"))

	for i in range(3):
		pool_audio_roll.append(_criar_player_audio("Master"))

	for i in range(3):
		pool_audio_resultado.append(_criar_player_audio("Master"))



func _obter_player_livre(pool: Array) -> AudioStreamPlayer:
	for p in pool:
		if p != null and not p.playing:
			return p

	if not pool.empty():
		return pool[0]

	return null



func _tocar_stream_em_pool(pool: Array, stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0, from_position: float = 0.0) -> AudioStreamPlayer:
	if stream == null:
		return null

	var player = _obter_player_livre(pool)
	if player == null:
		return null

	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play(from_position)
	return player

func _animar_pulso_forte_botao_restart() -> void:
	if final_start_botao == null:
		return

	final_start_botao.rect_pivot_offset = final_start_botao.rect_size * 0.5

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(final_start_botao, "rect_scale", Vector2(1.12, 1.12), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if final_start_glow != null:
		tw.tween_property(final_start_glow, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tw.chain().set_parallel(true)
	tw.tween_property(final_start_botao, "rect_scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _parar_pool(pool: Array) -> void:
	for p in pool:
		if p != null:
			p.stop()




func _estilo_card_final(cor: Color, vencedor: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(cor.r * 0.10, cor.g * 0.10, cor.b * 0.10, 0.94)
	s.border_color = cor if vencedor else Color(cor.r, cor.g, cor.b, 0.55)
	s.border_width_left = 5 if vencedor else 3
	s.border_width_top = 5 if vencedor else 3
	s.border_width_right = 5 if vencedor else 3
	s.border_width_bottom = 5 if vencedor else 3
	s.corner_radius_top_left = 28
	s.corner_radius_top_right = 28
	s.corner_radius_bottom_left = 28
	s.corner_radius_bottom_right = 28
	s.shadow_color = Color(cor.r, cor.g, cor.b, 0.70 if vencedor else 0.30)
	s.shadow_size = 42 if vencedor else 20
	return s


func _criar_card_final_player(pai: Control, nome: String, cor: Color) -> Dictionary:
	var card := Panel.new()
	card.rect_size = Vector2(370, 255)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_stylebox_override("panel", _estilo_card_final(cor, false))
	pai.add_child(card)

	var titulo = _criar_label_painel(
		card,
		nome,
		Vector2(18, 18),
		Vector2(334, 44),
		cor,
		24,
		5
	)

	var badge = _criar_label_painel(
		card,
		"",
		Vector2(70, 70),
		Vector2(230, 38),
		COR_TEXTO_YELLOW,
		20,
		5
	)

	var stats = _criar_label_painel(
		card,
		"",
		Vector2(22, 118),
		Vector2(326, 112),
		COR_TEXTO_BRANCO,
		21,
		4
	)
	stats.autowrap = true

	return {
		"card": card,
		"titulo": titulo,
		"badge": badge,
		"stats": stats
	}


func _aplicar_vencedor_card(card: Panel, titulo: Label, badge: Label, cor: Color, vencedor: bool) -> void:
	if card == null:
		return

	card.add_stylebox_override("panel", _estilo_card_final(cor, vencedor))
	card.rect_scale = Vector2(1.06, 1.06) if vencedor else Vector2(0.96, 0.96)

	if titulo != null:
		_aplicar_fonte_painel(titulo, 25 if vencedor else 22, cor, 5)

	if badge != null:
		if vencedor:
			badge.text = "🏆  VENCEDOR"
			_aplicar_fonte_painel(badge, 22, COR_TEXTO_YELLOW, 5)
		else:
			badge.text = "RESULTADO"
			_aplicar_fonte_painel(badge, 17, Color(1, 1, 1, 0.62), 4)

func _animar_placar_player_da_vez() -> void:
	if quantidade_jogadores <= 1:
		return

	if ultimo_player_animado_placar == jogador_atual:
		return

	ultimo_player_animado_placar = jogador_atual

	if tween_placar_player_vez != null:
		tween_placar_player_vez.kill()
		tween_placar_player_vez = null

	if hud_score_player_1_valor != null:
		hud_score_player_1_valor.rect_scale = Vector2.ONE

	if hud_score_player_2_valor != null:
		hud_score_player_2_valor.rect_scale = Vector2.ONE

	var alvo: Label = hud_score_player_1_valor if jogador_atual == 1 else hud_score_player_2_valor
	if alvo == null:
		return

	alvo.rect_pivot_offset = alvo.rect_size * 0.5

	tween_placar_player_vez = create_tween()
	tween_placar_player_vez.set_loops()
	tween_placar_player_vez.tween_property(alvo, "rect_scale", Vector2(1.16, 1.16), 0.42)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_placar_player_vez.tween_property(alvo, "rect_scale", Vector2(1.04, 1.04), 0.42)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ------------------------------------------------------------ Godot 3
# As funções anônimas do Godot 4 (ordenar, "quando o som acabar") viraram
# métodos: o Godot 3 não tem lambda.
var _ordem_ponto := Vector2.ZERO


func _ordem_no_por_distancia(a, b) -> bool:
	return a.global_position.distance_to(_ordem_ponto) < b.global_position.distance_to(_ordem_ponto)


func _ordem_pin_por_distancia(a, b) -> bool:
	var pa = a["pin"]
	var pb = b["pin"]
	if pa == null or pb == null:
		return false
	return pa.global_position.distance_to(_ordem_ponto) < pb.global_position.distance_to(_ordem_ponto)


func _ordem_dist_crescente(a, b) -> bool:
	return float(a["dist"]) < float(b["dist"])


func _ordem_score_crescente(a, b) -> bool:
	return float(a["score"]) < float(b["score"])


func _ordem_score_decrescente(a, b) -> bool:
	return float(a["score"]) > float(b["score"])


func _ordem_proj_crescente(a, b) -> bool:
	return float(a["proj"]) < float(b["proj"])


func _liberar_player_resultado(player: AudioStreamPlayer) -> void:
	if player_resultado_atual == player:
		player_resultado_atual = null
	if is_instance_valid(player):
		player.queue_free()


func _liberar_player_da_lista(player: AudioStreamPlayer, lista: Array) -> void:
	if player in lista:
		lista.erase(player)
	if is_instance_valid(player):
		player.queue_free()
