extends SceneTree
## TESTE DE RESISTÊNCIA (só no PC, com a janela de verdade):
##   DRAGON_GIRO=1 RESISTENCIA=/pasta godot3 --path . -s res://.teste/resistencia.gd
## O jogo joga sozinho por DURACAO segundos (padrão 1800), sem parar, um
## ciclo atrás do outro: partida de 1 jogador, de 2 jogadores, a demo
## (esperando no menu), a configuração (fecha sozinha e pelo SELECT), uma
## partida largada (aviso de inatividade) e a demo interrompida pelo START.
## A cada 5 s anota memória, texturas, nós, órfãos, objetos e recursos; no
## fim compara as voltas ao menu: o que cresce volta após volta é vazamento.
## Sai com "RESISTENCIA: OK" ou "RESISTENCIA: FALHOU (...)".
const TECLAS = {"start": KEY_1, "z": KEY_A, "x": KEY_S, "c": KEY_D, "v": KEY_F, "b": KEY_G, "sel": KEY_5}
const JOGADAS = ["z", "x", "c", "v", "b", "c", "c"]
const CICLO = ["jogo1", "jogo2", "demo", "config_espera", "inativo", "demo_start", "config_select", "jogo1"]
## uma missão que passa disto travou em algum lugar
const LIMITE_MISSAO = 420.0

var duracao = 1800.0
var pasta = OS.get_environment("RESISTENCIA") if OS.has_environment("RESISTENCIA") else "user://resistencia"
var t0 = 0
var csv: File
var soltar = []
var missao = ""
var indice = -1
var inicio_missao = 0.0
var passo = 0
var proxima_acao = 0.0
var tela_antes = ""
var chegou_na_tela = 0.0
var proxima_amostra = 0.0
var voltas_ao_menu = []
var missoes_feitas = {}
var problemas = []
var pior_quadro = 0.0
var ultimo_us = 0
var quadros_lentos = 0
var rng = RandomNumberGenerator.new()


func _init():
	if OS.has_environment("DURACAO"):
		duracao = float(OS.get_environment("DURACAO"))
	rng.seed = 2026
	Input.set_use_accumulated_input(false)
	Directory.new().make_dir_recursive(pasta)
	csv = File.new()
	csv.open(pasta + "/amostras.csv", File.WRITE)
	csv.store_line("t;tela;missao;mem_mb;mem_max_mb;tex_mb;nos;orfaos;objetos;recursos;itens;desenhos;fps")
	t0 = OS.get_ticks_msec()
	ultimo_us = OS.get_ticks_usec()
	change_scene("res://scene/abertura.tscn")


func _t() -> float:
	return (OS.get_ticks_msec() - t0) / 1000.0


func _apertar(nome, down):
	var ev = InputEventKey.new()
	ev.physical_scancode = TECLAS[nome]
	ev.scancode = TECLAS[nome]
	ev.pressed = down
	Input.parse_input_event(ev)


func _tocar(nome):
	_apertar(nome, true)
	soltar.append([_t() + 0.12, nome])


func _tela() -> String:
	var c = current_scene
	return c.name if c != null else "(sem cena)"


func _idle(_d):
	var agora_us = OS.get_ticks_usec()
	var q = (agora_us - ultimo_us) / 1000.0
	ultimo_us = agora_us
	var t = _t()
	if t > 3.0:
		pior_quadro = max(pior_quadro, q)
		if q > 250.0:
			quadros_lentos += 1
			print("QUADRO LENTO t=%.1f %s %.0f ms" % [t, _tela(), q])
	for s in soltar.duplicate():
		if t >= s[0]:
			_apertar(s[1], false)
			soltar.erase(s)
	var tela = _tela()
	if tela != tela_antes:
		print("t=%.1f tela: %s -> %s (missão %s)" % [t, tela_antes, tela, missao])
		tela_antes = tela
		chegou_na_tela = t
		if tela == "Main Menu":
			_voltou_ao_menu(t)
	_conduzir(t, tela)
	if t >= proxima_amostra:
		_amostra(t, tela)
		proxima_amostra = t + 5.0
	if t >= duracao and tela == "Main Menu" and t - chegou_na_tela > 4.0:
		_relatorio()
		quit()
	elif t >= duracao + LIMITE_MISSAO:
		problemas.append("não voltou ao menu no fim (%s)" % tela)
		_relatorio()
		quit()
	return false


## a tela que a missão precisa ter visitado para terminar ao voltar ao menu
const ALVO = {"jogo1": "Game", "jogo2": "Game", "inativo": "Game", "demo": "Demo", "demo_start": "Game",
	"config_espera": "ConfiguracaoTVBox", "config_select": "ConfiguracaoTVBox"}
var visitou = {}


func _voltou_ao_menu(_t):
	if missao != "" and visitou.has(ALVO[missao]):
		missoes_feitas[missao] = missoes_feitas.get(missao, 0) + 1
		missao = ""


func _proxima_missao(t):
	indice = (indice + 1) % CICLO.size()
	missao = CICLO[indice]
	inicio_missao = t
	passo = 0
	proxima_acao = t
	visitou = {}
	print("t=%.1f MISSÃO %s" % [t, missao])


func _conduzir(t, tela):
	if missao != "":
		visitou[tela] = true
		if t - inicio_missao > LIMITE_MISSAO:
			problemas.append("missão %s passou de %d s (tela %s, t=%.0f)" % [missao, LIMITE_MISSAO, tela, t])
			print("TRAVOU? missão %s na tela %s" % [missao, tela])
			missao = ""
	match tela:
		"Main Menu":
			# o menu assenta (cortina, modal) antes de qualquer tecla
			if t - chegou_na_tela < 4.0:
				return
			if missao == "":
				# a foto do menu assentado, a cada volta
				voltas_ao_menu.append(_valores(t))
				_proxima_missao(t)
			match missao:
				"jogo1", "inativo":
					if passo == 0:
						_tocar("start")
						passo = 1
				"jogo2":
					if passo == 0:
						_tocar("start")
						passo = 1
						proxima_acao = t + 0.6
					elif passo == 1 and t >= proxima_acao:
						_tocar("start")
						passo = 2
				"config_espera", "config_select":
					if passo == 0:
						_tocar("sel")
						passo = 1
				"demo_start":
					# depois do START na demo: o menu com o modal aberto; o
					# 2o START escolhe 2 jogadores
					if passo == 1:
						_tocar("start")
						passo = 2
				# "demo": esperar a demo começar sozinha (80 s sem ninguém)
		"Game":
			if missao in ["jogo1", "jogo2", "demo_start"] and t >= proxima_acao and t - chegou_na_tela > 5.0:
				_tocar(JOGADAS[rng.randi_range(0, JOGADAS.size() - 1)])
				proxima_acao = t + 8.0
		"Demo":
			if missao == "demo_start" and passo == 0 and t - chegou_na_tela > 6.0:
				_tocar("start")
				passo = 1
		"ConfiguracaoTVBox":
			if missao == "config_select" and passo == 1 and t - chegou_na_tela > 3.0:
				_tocar("sel")
				passo = 2


func _valores(t) -> Dictionary:
	return {
		"t": t,
		"mem": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"tex": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"nos": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orfaos": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"objetos": Performance.get_monitor(Performance.OBJECT_COUNT),
		"recursos": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
	}


func _amostra(t, tela):
	var v = _valores(t)
	csv.store_line("%.1f;%s;%s;%.1f;%.1f;%.1f;%d;%d;%d;%d;%d;%d;%.0f" % [t, tela, missao, v["mem"],
		Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0, v["tex"], v["nos"], v["orfaos"],
		v["objetos"], v["recursos"], Performance.get_monitor(Performance.RENDER_2D_ITEMS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_2D_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.TIME_FPS)])
	csv.flush()


func _relatorio():
	var t = _t()
	print("")
	print("== RESISTÊNCIA: %.0f s, %d voltas ao menu" % [t, voltas_ao_menu.size()])
	print("missões completas: %s" % str(missoes_feitas))
	print("pior quadro: %.0f ms | quadros acima de 250 ms: %d" % [pior_quadro, quadros_lentos])
	print("volta      t     mem   tex   nós  órfãos objetos recursos")
	for i in range(voltas_ao_menu.size()):
		var v = voltas_ao_menu[i]
		print("%5d %6.0f %7.1f %5.1f %5d %6d %7d %8d" % [i, v["t"], v["mem"], v["tex"], v["nos"], v["orfaos"], v["objetos"], v["recursos"]])
	# vazamento: o MESMO ponto em ciclos diferentes (o menu depois de cada
	# ciclo inteiro de missões). No 1o ciclo cada tela carrega o que é dela
	# uma vez (as letras da configuração, por exemplo); depois, nada pode
	# crescer de um ciclo para o outro.
	var n = CICLO.size()
	if voltas_ao_menu.size() > 2 * n:
		var a = voltas_ao_menu[n]
		var b = voltas_ao_menu[(voltas_ao_menu.size() - 1) / n * n]
		var cresceu = {"mem": b["mem"] - a["mem"], "tex": b["tex"] - a["tex"], "nos": b["nos"] - a["nos"],
			"orfaos": b["orfaos"] - a["orfaos"], "objetos": b["objetos"] - a["objetos"], "recursos": b["recursos"] - a["recursos"]}
		print("do fim do 1o ciclo (volta %d) ao fim do último (volta %d): %s" % [n, (voltas_ao_menu.size() - 1) / n * n, str(cresceu)])
		if cresceu["mem"] > 4.0:
			problemas.append("memória cresceu %.1f MB" % cresceu["mem"])
		if cresceu["tex"] > 1.0:
			problemas.append("texturas cresceram %.1f MB" % cresceu["tex"])
		if cresceu["orfaos"] > 0:
			problemas.append("nós órfãos cresceram %d" % cresceu["orfaos"])
		if cresceu["nos"] > 10:
			problemas.append("nós cresceram %d" % cresceu["nos"])
		if cresceu["objetos"] > 100:
			problemas.append("objetos cresceram %d" % cresceu["objetos"])
	else:
		problemas.append("poucas voltas ao menu (%d; precisa de mais de %d: DURACAO maior)" % [voltas_ao_menu.size(), 2 * n])
	for m in ["jogo1", "jogo2", "demo", "config_espera", "inativo", "demo_start", "config_select"]:
		if not missoes_feitas.has(m) and t > 1500.0:
			problemas.append("missão %s nunca terminou" % m)
	if quadros_lentos > 0:
		problemas.append("%d quadros acima de 250 ms" % quadros_lentos)
	print("RESISTENCIA: " + ("OK" if problemas.empty() else "FALHOU (%s)" % PoolStringArray(problemas).join("; ")))
	csv.close()
