extends Node

## Somente modo livre. Configuracoes antigas de credito sao ignoradas.
var modo_livre: bool = true

## Cena da pista, sons e fontes carregados em segundo plano pelo menu.
## Ficam guardados aqui para não saírem do cache entre uma partida e outra.
var precarregados: Dictionary = {}

## SOM JUNTO COM A IMAGEM. O som sai na hora; a imagem da bola chega à
## tela um ou dois quadros depois (e a TV ainda processa a imagem). O som
## da jogada espera o quadro com a bola já desenhado e mais esta folga.
var atraso_som_jogada: float = 0.06

## FONTES SEM BUSCA NO SISTEMA. As fontes do jogo não têm 🎳 🏆 ★ ◆ ▼...
## No Godot 3 cada letra é uma DynamicFont (fonte + tamanho + contorno) e
## TODA ela já nasce com as duas fontinhas de reserva do jogo
## (fonts/simbolos_do_jogo.ttf e fonts/emoji_do_jogo.ttf) — ver
## `Compat.fonte_para`. O Godot 3 não procura fonte no sistema: nada trava.
const FONTES_DO_JOGO := [
	"res://fonts/arcade_impact.ttf",
	"res://fonts/painel_arcade.ttf",
	"res://fonts/titan.ttf",
]


# ─────────────────────────────────────────────
# CONFIGURAÇÃO GLOBAL DO JOGO
# ─────────────────────────────────────────────

# Quantidade de jogadores (1 ou 2)
var jogadores: int = 1

# Rodadas base por jogador
var rounds_por_jogador: int = 3

# Dados persistentes da sessão
var jogador_atual: int = 1
var partida_ativa: bool = false

# Nome do cenário atual
var cenario_atual: String = ""

# Dificuldade (facil / dificil)
var dificuldade: String = "facil"

# Idioma
var idioma: String = "pt_br"

# Tempo padrão de partida
var tempo_partida: int = 120

# ─────────────────────────────────────────────
# RESET DE PARTIDA
# ─────────────────────────────────────────────
func resetar_partida() -> void:
	jogadores = clamp(jogadores, 1, 2)
	jogador_atual = 1
	partida_ativa = false


# ─────────────────────────────────────────────
# CONFIGURA JOGADORES
# ─────────────────────────────────────────────
func configurar_jogadores(qtd: int) -> void:
	jogadores = clamp(qtd, 1, 2)
	jogador_atual = 1


# ─────────────────────────────────────────────
# TROCA PLAYER
# ─────────────────────────────────────────────
func proximo_jogador() -> int:
	if jogadores <= 1:
		jogador_atual = 1
		return jogador_atual

	jogador_atual += 1

	if jogador_atual > jogadores:
		jogador_atual = 1

	return jogador_atual


# ─────────────────────────────────────────────
# RETORNA TEXTO PLAYER
# ─────────────────────────────────────────────
func texto_player() -> String:
	if jogadores <= 1:
		return "1 PLAYER"

	return "PLAYER %d" % jogador_atual
