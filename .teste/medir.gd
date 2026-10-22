extends SceneTree
## MEDIDOR DE CUSTO POR TELA (só no PC, com a janela de verdade):
##   DRAGON_GIRO=1 MEDIR=/pasta godot3 --path . -s res://.teste/medir.gd
## Joga o mesmo roteiro do roteiro.gd (abertura, START, 9 jogadas, fim de
## jogo) e, quadro a quadro, anota por tela: tempo do quadro, tempo dos
## scripts, itens e chamadas de desenho 2D, memória e texturas. A cada
## 6 quadros soma a ÁREA desenhada (em pixels do jogo, 1024 x 1536): é o
## que pesa na Mali-450 - cada camada de tela cheia é a tela inteira de
## pixels a mais para ela pintar. No fim: resumo por tela, as camadas que
## mais cobrem a tela e as imagens desenhadas bem menores do que são
## (sem mipmap, a Mali lê a imagem inteira para encolher).
## Variáveis: FIM (s, padrão 110), ROTEIRO=demo (espera a demo, sem teclas),
## FOTOS=1 (foto a cada 2 s em MEDIR).
const TECLAS = {"start": KEY_1, "z": KEY_A, "x": KEY_S, "c": KEY_D, "v": KEY_F, "b": KEY_G, "sel": KEY_5, "q": KEY_Q, "w": KEY_W}
var ROTEIRO = [[7.0, "start"], [16.0, "c"], [24.0, "x"], [32.0, "v"], [40.0, "z"], [48.0, "c"], [56.0, "b"], [64.0, "c"], [72.0, "x"], [80.0, "c"]]
const AREA_JOGO = 1024.0 * 1536.0

var t0 = 0
var ultimo_us = 0
var soltar = []
var fim = 110.0
var pasta = OS.get_environment("MEDIR") if OS.has_environment("MEDIR") else "user://medir"
var fotos = OS.has_environment("FOTOS")
## SEM_AREA=1: não soma a área (no Godot sem tela, para medir só o processador)
var sem_area = OS.has_environment("SEM_AREA")
var proxima_foto = 1.0
var quadro = 0
var csv: File
var por_tela = {}
var maiores_camadas = {}
var encolhidas = {}
## nós criados desde o último quadro (para dizer o que um tranco montou)
var novos = []
var tex_antes = 0.0
## LETRAS=1: junta, por fonte (dados|tamanho|contorno), as letras que
## aparecem na tela (Label e Button) - o que precisa estar pronto antes.
var letras_ligado = OS.has_environment("LETRAS")
var letras = {}


func _init():
	if OS.has_environment("FIM"):
		fim = float(OS.get_environment("FIM"))
	match OS.get_environment("ROTEIRO"):
		"demo":
			ROTEIRO = []
		"jogo2":
			# 2 jogadores, todos strike: empate no fim
			ROTEIRO = [[7.0, "start"], [7.5, "start"], [16.0, "c"], [24.0, "c"], [32.0, "c"], [40.0, "c"], [48.0, "c"], [56.0, "c"]]
		"jogo2b":
			# 2 jogadores, o 1 ganha
			ROTEIRO = [[7.0, "start"], [7.5, "start"], [16.0, "c"], [24.0, "z"], [32.0, "z"], [40.0, "c"], [48.0, "z"], [56.0, "z"], [64.0, "c"], [72.0, "x"], [80.0, "x"]]
		"config":
			# SELECT no menu: a configuração abre e fecha sozinha (20 s)
			ROTEIRO = [[6.0, "sel"], [9.0, "start"], [12.0, "z"]]
		"inativo":
			# partida sem ninguém jogar: o aviso de inatividade
			ROTEIRO = [[7.0, "start"]]
		"aviso":
			# tecla sem função no menu
			ROTEIRO = [[6.0, "q"], [8.0, "w"]]
		"demo_ja":
			# a demo sem esperar 80 s; START na demo volta ao menu com o modal
			# aberto e o 2o START escolhe 2 jogadores
			ROTEIRO = [[6.0, "!demo"], [22.0, "start"], [23.0, "start"], [34.0, "c"], [42.0, "x"]]
	# sem isso o Godot sem tela guarda as teclas simuladas e nunca as entrega
	Input.set_use_accumulated_input(false)
	Directory.new().make_dir_recursive(pasta)
	csv = File.new()
	csv.open(pasta + "/quadros.csv", File.WRITE)
	csv.store_line("t;tela;quadro_ms;script_ms;fisica_ms;itens;desenhos;nos;orfaos;mem_mb;tex_mb;area")
	t0 = OS.get_ticks_msec()
	ultimo_us = OS.get_ticks_usec()
	connect("node_added", self, "_no_novo")
	change_scene("res://scene/abertura.tscn")


func _no_novo(n: Node) -> void:
	if novos.size() < 40:
		novos.append(n.get_class() + ":" + n.name)


func _apertar(nome, down):
	var ev = InputEventKey.new()
	ev.physical_scancode = TECLAS[nome]
	ev.scancode = TECLAS[nome]
	ev.pressed = down
	Input.parse_input_event(ev)


func _nome_da_tela() -> String:
	var c = current_scene
	if c == null:
		return "(sem cena)"
	var n = c.name
	# a partida: o que está por cima (fim de jogo, aviso) conta como outra tela
	var g = c.get_node_or_null("Game") if n == "Demo" else (c if c.get_script() != null and c.get_script().resource_path.ends_with("game.gd") else null)
	if g != null:
		for k in [["overlay_final", "/fim"], ["overlay_inatividade", "/inativo"], ["overlay_transicao_inicio", "/entrada"]]:
			var l = g.get(k[0])
			if l is CanvasLayer and is_instance_valid(l) and l.visible and _tem_algo_visivel(l):
				return n + k[1]
	return n


func _tem_algo_visivel(l: CanvasLayer) -> bool:
	for f in l.get_children():
		if f is CanvasItem and f.visible and f.modulate.a > 0.05:
			return true
	return false


func _idle(_d):
	var agora = OS.get_ticks_usec()
	var quadro_ms = (agora - ultimo_us) / 1000.0
	ultimo_us = agora
	quadro += 1
	var t = (OS.get_ticks_msec() - t0) / 1000.0
	for s in soltar.duplicate():
		if t >= s[0]:
			_apertar(s[1], false)
			soltar.erase(s)
	while not ROTEIRO.empty() and t >= ROTEIRO[0][0]:
		var r = ROTEIRO.pop_front()
		if r[1].begins_with("!"):
			# "!demo": chama a demo do menu na hora
			if current_scene != null and current_scene.has_method("_iniciar_demo"):
				current_scene.call("_iniciar_demo")
			print("CHAMOU %s em %.1f" % [r[1], t])
			continue
		_apertar(r[1], true)
		soltar.append([t + 0.12, r[1]])
		print("APERTOU %s em %.1f" % [r[1], t])
	var tela = _nome_da_tela()
	var area = -1.0
	if quadro % 6 == 0 and not sem_area:
		area = _area_desenhada(tela)
	if letras_ligado and quadro % 5 == 0:
		_juntar_letras(root)
	var script_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var fisica_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var itens = Performance.get_monitor(Performance.RENDER_2D_ITEMS_IN_FRAME)
	var desenhos = Performance.get_monitor(Performance.RENDER_2D_DRAW_CALLS_IN_FRAME)
	var nos = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orfaos = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var mem = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var tex = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	csv.store_line("%.3f;%s;%.2f;%.2f;%.2f;%d;%d;%d;%d;%.1f;%.1f;%.2f" % [t, tela, quadro_ms, script_ms, fisica_ms, itens, desenhos, nos, orfaos, mem, tex, area])
	if quadro_ms > 40.0 and t > 0.5:
		print("TRANCO t=%.2f %s %.0f ms | tex %+.1f MB | nós novos %d: %s" % [t, tela, quadro_ms, tex - tex_antes, novos.size(), PoolStringArray(novos.slice(0, 12)).join(" ") if not novos.empty() else ""])
	novos.clear()
	tex_antes = tex
	if not por_tela.has(tela):
		por_tela[tela] = {"n": 0, "q": [], "s": [], "itens": 0, "desenhos": 0, "area": [], "tex": 0.0, "mem": 0.0}
	var p = por_tela[tela]
	p["n"] += 1
	p["q"].append(quadro_ms)
	p["s"].append(script_ms)
	p["itens"] = max(p["itens"], itens)
	p["desenhos"] = max(p["desenhos"], desenhos)
	p["tex"] = max(p["tex"], tex)
	p["mem"] = max(p["mem"], mem)
	if area >= 0.0:
		p["area"].append(area)
	if fotos and t >= proxima_foto:
		var img = root.get_texture().get_data()
		img.flip_y()
		if not OS.has_environment("FOTO_CHEIA"):
			img.resize(img.get_width() / 2, img.get_height() / 2)
		img.save_png("%s/%05.1f_%s.png" % [pasta, proxima_foto, tela.replace("/", "-").replace(" ", "_")])
		proxima_foto += float(OS.get_environment("FOTO_A_CADA")) if OS.has_environment("FOTO_A_CADA") else 2.0
	if t >= fim:
		_relatorio()
		quit()
	return false


# ------------------------------------------------------------ área desenhada
func _area_desenhada(tela: String) -> float:
	var total = 0.0
	var pilha = [root]
	while not pilha.empty():
		var n = pilha.pop_back()
		if n is CanvasItem and not n.is_visible_in_tree():
			continue
		if n is CanvasLayer and not n.visible:
			continue
		if n is CanvasItem:
			var a = _area_do_item(n)
			if a > 0.0:
				total += a
				var chave = tela + " | " + _caminho(n)
				var desc = _descricao(n)
				if not maiores_camadas.has(chave) or maiores_camadas[chave][0] < a:
					maiores_camadas[chave] = [a, desc]
		for f in n.get_children():
			pilha.append(f)
	return total / AREA_JOGO


func _alfa(n: CanvasItem) -> float:
	var a = 1.0
	var x = n
	while x != null and x is CanvasItem:
		a *= x.modulate.a * x.self_modulate.a if x == n else x.modulate.a
		x = x.get_parent()
	return a


func _area_do_item(n: CanvasItem) -> float:
	if _alfa(n) < 0.01:
		return 0.0
	var tamanho = Vector2.ZERO
	var deslocamento = Vector2.ZERO
	var textura: Texture = null
	if n is Sprite:
		textura = n.texture
		if textura == null:
			return 0.0
		var r: Rect2 = n.get_rect()
		tamanho = r.size
		deslocamento = r.position
	elif n is AnimatedSprite:
		if n.frames == null:
			return 0.0
		textura = n.frames.get_frame(n.animation, n.frame)
		if textura == null:
			return 0.0
		tamanho = textura.get_size()
		deslocamento = -tamanho * 0.5 if n.centered else Vector2.ZERO
	elif n is TextureRect:
		textura = n.texture
		if textura == null:
			return 0.0
		tamanho = n.rect_size
	elif n is ColorRect:
		if n.color.a < 0.01:
			return 0.0
		tamanho = n.rect_size
	elif n is NinePatchRect:
		textura = n.texture
		tamanho = n.rect_size
	elif n is Panel or n is PanelContainer:
		var sb = n.get_stylebox("panel")
		if sb == null or sb is StyleBoxEmpty:
			return 0.0
		if sb is StyleBoxFlat and sb.bg_color.a < 0.01 and sb.border_width_left == 0:
			return 0.0
		tamanho = n.rect_size
	elif n is Label:
		if n.text == "":
			return 0.0
		# as letras cobrem mais ou menos metade da caixa do texto
		tamanho = n.rect_size * Vector2(1.0, 0.5)
	elif n is Polygon2D:
		var pol: PoolVector2Array = n.polygon
		if pol.size() < 3:
			return 0.0
		var r2 = Rect2(pol[0], Vector2.ZERO)
		for v in pol:
			r2 = r2.expand(v)
		tamanho = r2.size * 0.6
		deslocamento = r2.position
	elif n is Button:
		tamanho = n.rect_size
	else:
		return 0.0
	var tr: Transform2D = n.get_global_transform_with_canvas()
	var det = abs(tr.x.x * tr.y.y - tr.x.y * tr.y.x)
	var area = abs(tamanho.x * tamanho.y) * det
	# só o que cai dentro da tela do jogo
	var canto = tr.xform(deslocamento)
	var caixa = Rect2(canto, Vector2.ZERO)
	for v in [Vector2(tamanho.x, 0), Vector2(0, tamanho.y), tamanho]:
		caixa = caixa.expand(tr.xform(deslocamento + v))
	var visivel = caixa.clip(Rect2(0, 0, 1024, 1536))
	if caixa.get_area() > 0.0:
		area *= visivel.get_area() / caixa.get_area()
	if textura != null and area > 20000.0:
		var tx = textura.get_size()
		var mostrado = sqrt(area)
		var original = sqrt(tx.x * tx.y)
		if original > mostrado * 1.8:
			var chave = textura.resource_path if textura.resource_path != "" else str(textura)
			encolhidas[chave] = [tx, original / mostrado, (textura.flags & Texture.FLAG_MIPMAPS) != 0]
	return area


func _caminho(n: Node) -> String:
	var s = str(n.get_path())
	var i = s.find("/root/")
	return s.substr(i + 6) if i >= 0 else s


func _descricao(n: CanvasItem) -> String:
	var tex: Texture = null
	if n is Sprite or n is TextureRect or n is NinePatchRect:
		tex = n.texture
	elif n is AnimatedSprite and n.frames != null:
		tex = n.frames.get_frame(n.animation, n.frame)
	var d = n.get_class()
	if tex != null:
		d += " %dx%d %s%s" % [tex.get_width(), tex.get_height(), tex.resource_path.get_file(), " mip" if tex.flags & Texture.FLAG_MIPMAPS else ""]
	if n.material != null:
		d += " +material"
	return d


# ------------------------------------------------------------ relatório
func _media(v: Array) -> float:
	if v.empty():
		return 0.0
	var s = 0.0
	for x in v:
		s += x
	return s / v.size()


func _pct(v: Array, p: float) -> float:
	if v.empty():
		return 0.0
	var c = v.duplicate()
	c.sort()
	return c[int(min(c.size() - 1, floor(c.size() * p)))]


func _juntar_letras(n: Node) -> void:
	if (n is Label or n is Button) and n.is_visible_in_tree() and n.text != "":
		var f = n.get_font("font")
		var chave = "?"
		if f is DynamicFont:
			chave = "%s|%d|%d" % [f.font_data.resource_path.get_file() if f.font_data != null else "-", f.size, f.outline_size]
		elif f != null:
			chave = f.get_class() + "|" + f.resource_path.get_file()
		var t = n.text.to_upper() if (n is Label and n.uppercase) else n.text
		if not letras.has(chave):
			letras[chave] = {}
		for c in t:
			letras[chave][c] = true
	for f in n.get_children():
		_juntar_letras(f)


func _relatorio():
	csv.close()
	if letras_ligado:
		print("\n=== LETRAS POR FONTE (dados|tamanho|contorno) ===")
		var ch = letras.keys()
		ch.sort()
		for k in ch:
			var cs = letras[k].keys()
			cs.sort()
			print("%-34s %3d letras: %s" % [k, cs.size(), PoolStringArray(cs).join("")])
	print("\n=== POR TELA (área = telas inteiras pintadas por quadro) ===")
	for tela in por_tela:
		var p = por_tela[tela]
		print("%-22s quadros %5d | quadro med %6.1f p95 %6.1f max %7.1f ms | script med %5.2f p95 %5.2f max %6.1f ms | área med %4.2f max %4.2f | itens %4d desenhos %4d | tex %5.1f MB mem %5.1f MB" % [
			tela, p["n"], _media(p["q"]), _pct(p["q"], 0.95), _pct(p["q"], 1.0), _media(p["s"]), _pct(p["s"], 0.95), _pct(p["s"], 1.0),
			_media(p["area"]), _pct(p["area"], 1.0), p["itens"], p["desenhos"], p["tex"], p["mem"]])
	print("\n=== CAMADAS QUE MAIS COBREM A TELA (fração da tela) ===")
	var lista = []
	for k in maiores_camadas:
		lista.append([maiores_camadas[k][0] / AREA_JOGO, k, maiores_camadas[k][1]])
	lista.sort_custom(self, "_maior_primeiro")
	for i in range(min(45, lista.size())):
		print("%5.2f  %s  [%s]" % [lista[i][0], lista[i][1], lista[i][2]])
	print("\n=== IMAGENS DESENHADAS BEM MENORES DO QUE SÃO ===")
	for k in encolhidas:
		var e = encolhidas[k]
		print("%5.1fx  %dx%d  mipmaps=%s  %s" % [e[1], e[0].x, e[0].y, e[2], k])
	var texs = VisualServer.texture_debug_usage()
	var total = 0
	for x in texs:
		total += x["bytes"]
	print("\nTEXTURAS NO FIM %.1f MB | fixa %.1f MB" % [total / 1048576.0, OS.get_static_memory_usage() / 1048576.0])
	texs.sort_custom(self, "_maior_bytes")
	for i in range(min(30, texs.size())):
		var x = texs[i]
		print("%7.2f MB %dx%d fmt%d %s" % [x["bytes"] / 1048576.0, x["width"], x["height"], x["format"], x["path"]])


func _maior_primeiro(a, b):
	return a[0] > b[0]


func _maior_bytes(a, b):
	return a["bytes"] > b["bytes"]
