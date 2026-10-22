extends Node

## O GUARDIÃO DA MÁQUINA: TELA SEMPRE LIGADA E JOGO SEMPRE DE PÉ.
##
## Uma máquina de fliperama passa o dia inteiro na mesma tela sem ninguém
## tocar no controle remoto da TV Box. O Android não sabe disso: depois de
## um tempo ele apaga a tela, liga o protetor de tela ou põe a placa para
## dormir — e a máquina fica PRETA com o jogo vivo por baixo.
##
## O pedido de "tela sempre ligada" o Godot faz uma vez só, no começo. Se a
## TV for desligada e religada (o HDMI cai e volta), se o Android tirar o
## jogo da frente por um instante ou se o próprio sistema limpar o pedido,
## ninguém pedia de novo. Aqui o pedido é REFEITO: ao voltar para a frente,
## ao ganhar o foco e a cada poucos segundos.
##
## E A CENA NUNCA FICA VAZIA. Se uma troca de tela falhar e o jogo ficar
## sem cena (o que na TV é uma tela preta para sempre), a abertura é
## carregada de novo sozinha.

const ABERTURA := "res://scene/abertura.tscn"
## A cada quanto tempo o pedido de tela ligada é refeito.
const REFORCO_S := 15.0
## Quanto tempo o jogo pode ficar sem cena antes de voltar para a abertura
## (uma troca de cena normal deixa o jogo sem cena por um quadro só).
const SEM_CENA_MAXIMO_S := 3.0

var _relogio := 0.0
var _sem_cena := 0.0


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	# Nenhum pedido do sistema fecha o jogo (o VOLTAR já é ignorado em
	# ArcadeControls; este é o "fechar janela").
	get_tree().set_auto_accept_quit(false)
	_manter_tela_ligada()


func _process(delta: float) -> void:
	_relogio += delta
	if _relogio >= REFORCO_S:
		_relogio = 0.0
		_manter_tela_ligada()
	if get_tree().current_scene == null:
		_sem_cena += delta
		if _sem_cena >= SEM_CENA_MAXIMO_S:
			_sem_cena = 0.0
			push_warning("Jogo sem cena: voltando para a abertura.")
			get_tree().change_scene(ABERTURA)
	else:
		_sem_cena = 0.0


func _notification(what: int) -> void:
	match what:
		MainLoop.NOTIFICATION_APP_RESUMED, MainLoop.NOTIFICATION_WM_FOCUS_IN:
			_manter_tela_ligada()
			_relogio = 0.0
		MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
			print("Pedido de fechar ignorado (máquina de arcade não sai do jogo)")


func _manter_tela_ligada() -> void:
	OS.keep_screen_on = true
	# Economia de processador desligada: com ela, o Godot só redesenha
	# quando "algo muda" e uma tela parada podia ficar sem quadro novo.
	OS.low_processor_usage_mode = false
