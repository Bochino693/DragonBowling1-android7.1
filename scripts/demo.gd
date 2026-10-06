extends Node2D

export(String, FILE, "*.tscn") var cena_menu_path: String = "res://scene/Main Menu.tscn"
export(String, FILE, "*.tscn") var cena_jogo_path: String = "res://scene/game.tscn"
export var tempo_total_demo: float = 18.0
export var intervalo_entre_jogadas: float = 2.2
export var atraso_primeira_jogada: float = 1.3

onready var game = get_node_or_null("Game")
var audio_coin_player: AudioStreamPlayer = null
var transicao_com_moeda_em_andamento: bool = false

var sequencia: Array = ["C", "X", "V", "Z", "B", "C"]
var indice: int = 0

var demo_encerrando: bool = false
var demo_ativa: bool = false
var tempo_sem_interacao: float = 0.0
var transicao_em_andamento: bool = false


func _ready() -> void:
	if game == null:
		push_error("Nó 'Game' não encontrado dentro da demo.")
		return

	if game.has_method("iniciar_jogo"):
		game.iniciar_jogo(false)

	demo_ativa = true
	demo_encerrando = false
	transicao_em_andamento = false
	tempo_sem_interacao = 0.0
	indice = 0

	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)

	call_deferred("_loop_demo")



func _garantir_player_moeda() -> void:
	if audio_coin_player != null:
		return

	audio_coin_player = AudioStreamPlayer.new()
	audio_coin_player.name = "CoinPlayer"
	audio_coin_player.bus = "Master"
	add_child(audio_coin_player)

	if ResourceLoader.exists("res://songs/coin.wav"):
		audio_coin_player.stream = load("res://songs/coin.wav")


func _abrir_jogo_com_moeda() -> void:
	if transicao_com_moeda_em_andamento:
		return
	if demo_encerrando:
		return
	if transicao_em_andamento:
		return

	transicao_com_moeda_em_andamento = true
	transicao_em_andamento = true
	demo_encerrando = true
	demo_ativa = false

	_garantir_player_moeda()

	if audio_coin_player != null and audio_coin_player.stream != null:
		audio_coin_player.stop()
		audio_coin_player.play()

		var duracao: float = 0.0
		if audio_coin_player.stream.has_method("get_length"):
			duracao = float(audio_coin_player.stream.get_length())

		yield(get_tree().create_timer(max(0.08, duracao)), "timeout")

	abrir_jogo()

func _process(delta: float) -> void:
	if not demo_ativa:
		return
	if demo_encerrando:
		return
	if transicao_em_andamento:
		return

	tempo_sem_interacao += delta

	if tempo_sem_interacao >= tempo_total_demo:
		encerrar_demo()


func _input(event: InputEvent) -> void:
	if ArcadeControls.eh_config(event):
		get_tree().change_scene("res://scene/configuracao_tvbox.tscn")
		get_viewport().set_input_as_handled()
		return
	if not demo_ativa:
		return
	if demo_encerrando:
		return
	if transicao_em_andamento:
		return

	if _evento_conta_como_interacao(event):
		tempo_sem_interacao = 0.0

	# START abre o jogo
	# START abre o jogo com som da moeda
	# START na demo NÃO começa uma partida de 1 jogador sozinho: volta ao
	# menu já com o modal "1 ou 2 jogadores" aberto (moeda + contagem). Um
	# segundo START escolhe 2 jogadores, igual ao menu.
	if ArcadeControls.eh_start(event):
		get_viewport().set_input_as_handled()
		ArcadeControls.abrir_selecao_de_jogadores = true
		encerrar_demo()
		return



func _unhandled_input(event: InputEvent) -> void:
	if not demo_ativa:
		return
	if demo_encerrando:
		return
	if transicao_em_andamento:
		return

	if _evento_conta_como_interacao(event):
		tempo_sem_interacao = 0.0


func _evento_conta_como_interacao(event: InputEvent) -> bool:
	# Só a placa Zero Delay conta; teclado e controle remoto não.
	return ArcadeControls.eh_atividade(event)


func abrir_jogo() -> void:
	if transicao_em_andamento and not transicao_com_moeda_em_andamento:
		return

	var caminho: String = cena_jogo_path.strip_edges()
	if caminho.empty():
		caminho = "res://scene/game.tscn"

	if not ResourceLoader.exists(caminho):
		push_error("Cena do jogo não encontrada: " + caminho)
		demo_encerrando = false
		demo_ativa = true
		transicao_em_andamento = false
		transicao_com_moeda_em_andamento = false
		return

	call_deferred("_trocar_cena_seguro", caminho)


func encerrar_demo() -> void:
	if demo_encerrando:
		return
	if transicao_em_andamento:
		return

	transicao_em_andamento = true
	demo_encerrando = true
	demo_ativa = false

	var caminho: String = cena_menu_path.strip_edges()
	if caminho.empty():
		caminho = "res://scene/Main Menu.tscn"

	if not ResourceLoader.exists(caminho):
		push_error("Cena do menu não encontrada: " + caminho)
		demo_encerrando = false
		demo_ativa = true
		transicao_em_andamento = false
		return

	call_deferred("_trocar_cena_seguro", caminho)


func _trocar_cena_seguro(caminho: String) -> void:
	var _g3_estado = null
	if not is_inside_tree():
		return

	var tree = get_tree()
	if tree == null:
		return

	_g3_estado = Cortina.fechar(tree)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")
	var erro: int = tree.change_scene(caminho)
	Cortina.abrir(tree)
	if erro != OK:
		push_error("Erro ao trocar cena para: " + caminho)

		demo_encerrando = false
		demo_ativa = true
		transicao_em_andamento = false
		transicao_com_moeda_em_andamento = false
		tempo_sem_interacao = 0.0


func _loop_demo() -> void:
	var _g3_estado = null
	_g3_estado = _esperar(atraso_primeira_jogada)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")
	if not _g3_estado:
		return

	while demo_ativa and not demo_encerrando and not transicao_em_andamento:
		_executar_proxima_jogada()

		_g3_estado = _esperar(intervalo_entre_jogadas)
		if _g3_estado is GDScriptFunctionState:
			_g3_estado = yield(_g3_estado, "completed")
		if not _g3_estado:
			return


func _executar_proxima_jogada() -> void:
	if demo_encerrando or not demo_ativa or transicao_em_andamento:
		return

	if game == null or not is_instance_valid(game):
		return

	if indice >= sequencia.size():
		indice = 0

	var tecla: String = sequencia[indice]
	indice += 1

	if game.has_method("executar_jogada_por_tecla"):
		game.executar_jogada_por_tecla(tecla)


func _esperar(segundos: float) -> bool:
	if demo_encerrando:
		return false

	if not is_inside_tree():
		return false

	var tree = get_tree()
	if tree == null:
		return false

	var timer = tree.create_timer(segundos)
	if timer == null:
		return false

	yield(timer, "timeout")

	if demo_encerrando:
		return false

	if not is_inside_tree():
		return false

	return true
	
