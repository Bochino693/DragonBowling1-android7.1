extends SceneTree
## Uso: FOTOS=/pasta FIM=110 godot --path . -s res://.teste/roteiro.gd (fotos a cada 0,5 s).
## Roteiro fixo: mesmas teclas nos mesmos segundos que o do Godot 4.
const TECLAS = {"start": KEY_1, "z": KEY_A, "x": KEY_S, "c": KEY_D, "v": KEY_F, "b": KEY_G}
var ROTEIRO = [[7.0, "start"], [16.0, "c"], [24.0, "x"], [32.0, "v"], [40.0, "z"], [48.0, "c"], [56.0, "b"], [64.0, "c"], [72.0, "x"], [80.0, "c"]]
var t0 = 0
var proxima_foto = 0.5
var soltar = []
var fim = 110.0
var pasta = OS.get_environment("FOTOS") if OS.has_environment("FOTOS") else "user://roteiro"
func _init():
	if OS.has_environment("FIM"):
		fim = float(OS.get_environment("FIM"))
	t0 = OS.get_ticks_msec()
	change_scene("res://scene/abertura.tscn")
func _apertar(nome, down):
	var ev = InputEventKey.new()
	ev.physical_scancode = TECLAS[nome]
	ev.scancode = TECLAS[nome]
	ev.pressed = down
	Input.parse_input_event(ev)
func _idle(_d):
	var t = (OS.get_ticks_msec() - t0) / 1000.0
	for s in soltar.duplicate():
		if t >= s[0]:
			_apertar(s[1], false)
			soltar.erase(s)
	while not ROTEIRO.empty() and t >= ROTEIRO[0][0]:
		var r = ROTEIRO.pop_front()
		_apertar(r[1], true)
		soltar.append([t + 0.12, r[1]])
		print("APERTOU %s em %.1f" % [r[1], t])
	if t >= proxima_foto:
		var img = root.get_texture().get_data()
		img.flip_y()
		img.resize(img.get_width() / 2, img.get_height() / 2)
		img.save_png("%s/%05.1f.png" % [pasta, proxima_foto])
		proxima_foto += 0.5
	if t >= fim:
		if OS.has_environment("MEM"):
			var lista = VisualServer.texture_debug_usage()
			var total = 0
			for x in lista:
				total += x["bytes"]
			print("TEXTURAS %.1f MB | fixa %.1f MB | dinamica %.1f MB" % [total / 1048576.0, OS.get_static_memory_usage() / 1048576.0, OS.get_dynamic_memory_usage() / 1048576.0])
			var ch = root.get_node("Compat")._fontes.keys()
			ch.sort()
			for k in ch:
				print("FONTE ", k)
			lista.sort_custom(self, "_maior")
			for i in range(min(25, lista.size())):
				var x = lista[i]
				print("%7.2f MB %dx%d fmt%d %s" % [x["bytes"] / 1048576.0, x["width"], x["height"], x["format"], x["path"]])
		quit()
	return false

func _maior(a, b):
	return a["bytes"] > b["bytes"]
