extends Node

## COMPAT: O QUE O GODOT 4 FAZ NUMA LINHA E O GODOT 3 NÃO.
##
## O jogo nasceu no Godot 4.6 (Pro Ultra). Na TV Box S905L (Mali-450, só
## OpenGL ES 2.0) roda no Godot 3.6, e o conversor
## (tools/godot4_para_godot3.py) manda para cá as chamadas sem equivalente
## direto:
##
##   • LETRAS: no Godot 4 um Label tem fonte, tamanho e contorno separados
##     (`add_theme_font_size_override`...). No Godot 3 os três moram numa
##     DynamicFont só. `tamanho`, `fonte` e `contorno` guardam o pedido no
##     próprio Label e montam (ou reaproveitam) a DynamicFont certa, sempre
##     com as fontinhas de reserva (símbolos e emojis do jogo).
##   • CARGA EM SEGUNDO PLANO: `load_threaded_request` não existe. Aqui é
##     uma fila na linha do jogo — nada de carregar textura fora da linha
##     principal na Mali-450. Cada arquivo carrega em PEDAÇOS
##     (`load_interactive`: a cena da pista é uma textura, um som, um
##     script por vez) e cada quadro gasta no máximo ORCAMENTO_CARGA_MS com
##     isso: o menu segue animando em vez de congelar um segundo inteiro.
##   • miudezas: randi_range, roundi, String.contains, find_children, as
##     fases do brilho da pista (o shader não usa TIME: ver o .shader).

const PADRAO := "res://fonts/padrao_opensans.ttf"
const RESERVAS := ["res://fonts/simbolos_do_jogo.ttf", "res://fonts/emoji_do_jogo.ttf"]
## Tamanho de letra de um Label sem tamanho pedido (o padrão do Godot 4).
const TAMANHO_PADRAO := 16

const CARGA_INVALIDA := 0
const CARGA_EM_ANDAMENTO := 1
const CARGA_FALHOU := 2
const CARGA_PRONTA := 3

var _dados := {}
var _fontes := {}
var _reservas := []
var _fila := []
var _prontos := {}
## Carga em pedaços do primeiro da fila (null: ainda não começou).
var _carga_atual: ResourceInteractiveLoader = null
const ORCAMENTO_CARGA_MS := 8


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	for caminho in RESERVAS:
		if ResourceLoader.exists(caminho):
			_reservas.append(load(caminho))


# ------------------------------------------------------------- letras
func dados_da_fonte(f) -> DynamicFontData:
	if f == null:
		return _dados_de(PADRAO)
	if f is DynamicFontData:
		return f
	if f is DynamicFont:
		return (f as DynamicFont).font_data
	if f is String:
		return _dados_de(f)
	return _dados_de(PADRAO)


func _dados_de(caminho: String) -> DynamicFontData:
	if not _dados.has(caminho):
		_dados[caminho] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _dados[caminho]


## A DynamicFont de (fonte, tamanho, contorno) — uma só para o jogo todo.
## `contorno` é o do Godot 4 (espessura TOTAL do traço); no Godot 3 o
## contorno é o quanto ele avança para fora da letra: metade.
## `cor_contorno`: só para o que NÃO é Label (Button...). No Godot 3 só o
## Label pinta o contorno com uma cor própria (font_outline_modulate); nos
## outros a cor mora na fonte.
func fonte_para(f, tamanho: int, contorno: int = 0, cor_contorno = null) -> DynamicFont:
	var dados = dados_da_fonte(f)
	tamanho = int(max(1, tamanho))
	var raio = int(ceil(max(0, contorno) * 0.5))
	var chave = "%s|%d|%d|%s" % [dados.resource_path if dados != null else "", tamanho, raio, str(cor_contorno)]
	if _fontes.has(chave):
		return _fontes[chave]
	var df = DynamicFont.new()
	df.font_data = dados
	df.size = tamanho
	df.use_filter = true
	df.use_mipmaps = false
	if raio > 0:
		df.outline_size = raio
		df.outline_color = cor_contorno if cor_contorno != null else Color(1, 1, 1, 1)
	for r in _reservas:
		if r != dados:
			df.add_fallback(r)
	_fontes[chave] = df
	return df


func tamanho(no: Control, n) -> void:
	no.set_meta("g3_tam", int(n))
	_aplicar_fonte(no)


func fonte(no: Control, f) -> void:
	no.set_meta("g3_fonte", dados_da_fonte(f))
	_aplicar_fonte(no)


func contorno(no: Control, n) -> void:
	no.set_meta("g3_cont", int(n))
	# No Godot 4 o contorno é preto se ninguém pediu cor; no 3 é branco.
	if int(n) > 0 and not no.has_color_override("font_outline_modulate"):
		no.add_color_override("font_outline_modulate", Color(0, 0, 0, 1))
	_aplicar_fonte(no)


## [fonte, tamanho, contorno] pedidos para o Label (como o Godot 4 lê).
func estilo_de(no: Control) -> Array:
	return [
		no.get_meta("g3_fonte") if no.has_meta("g3_fonte") else dados_da_fonte(null),
		int(no.get_meta("g3_tam")) if no.has_meta("g3_tam") else TAMANHO_PADRAO,
		int(no.get_meta("g3_cont")) if no.has_meta("g3_cont") else 0,
	]


func _aplicar_fonte(no: Control) -> void:
	var e = estilo_de(no)
	if no is Label or e[2] <= 0:
		no.add_font_override("font", fonte_para(e[0], e[1], e[2]))
		return
	# Button e cia.: a cor do contorno pedida depois (na mesma leva de
	# linhas) só é conhecida no fim do quadro.
	no.add_font_override("font", fonte_para(e[0], e[1], e[2], Color(0, 0, 0, 1)))
	if not no.has_meta("g3_reaplicar"):
		no.set_meta("g3_reaplicar", true)
		call_deferred("_fonte_com_cor_do_contorno", no)


func _fonte_com_cor_do_contorno(no: Control) -> void:
	if not is_instance_valid(no):
		return
	no.remove_meta("g3_reaplicar")
	var cor = no.get_color("font_outline_modulate") if no.has_color_override("font_outline_modulate") else Color(0, 0, 0, 1)
	var e = estilo_de(no)
	no.add_font_override("font", fonte_para(e[0], e[1], e[2], cor))


# ------------------------------------------------ carga em segundo plano
func pedir_carga(caminho: String) -> int:
	if _prontos.has(caminho) or _fila.has(caminho):
		return OK
	if not ResourceLoader.exists(caminho):
		return ERR_FILE_NOT_FOUND
	_fila.append(caminho)
	return OK


func estado_carga(caminho: String) -> int:
	if _prontos.has(caminho):
		return CARGA_PRONTA if _prontos[caminho] != null else CARGA_FALHOU
	if _fila.has(caminho):
		return CARGA_EM_ANDAMENTO
	return CARGA_INVALIDA


func pegar_carga(caminho: String):
	if not _prontos.has(caminho):
		# Pediram antes da vez dele: termina agora (é o que o Godot 4 faz).
		if not _fila.empty() and _fila[0] == caminho and _carga_atual != null:
			_terminar_carga_atual()
		else:
			_fila.erase(caminho)
			_prontos[caminho] = load(caminho)
	var r = _prontos[caminho]
	_prontos.erase(caminho)
	return r


func _terminar_carga_atual() -> void:
	var caminho: String = _fila.pop_front()
	var erro = OK
	while erro == OK:
		erro = _carga_atual.poll()
	_prontos[caminho] = _carga_atual.get_resource() if erro == ERR_FILE_EOF else null
	_carga_atual = null


func _process(_delta: float) -> void:
	if _fila.empty():
		return
	var fim_do_quadro = OS.get_ticks_msec() + ORCAMENTO_CARGA_MS
	while not _fila.empty() and OS.get_ticks_msec() < fim_do_quadro:
		var caminho: String = _fila[0]
		if _carga_atual == null:
			_carga_atual = ResourceLoader.load_interactive(caminho)
			if _carga_atual == null:
				_fila.pop_front()
				_prontos[caminho] = null
				continue
		var erro = _carga_atual.poll()
		if erro == OK:
			continue
		_fila.pop_front()
		_prontos[caminho] = _carga_atual.get_resource() if erro == ERR_FILE_EOF else null
		_carga_atual = null


# ------------------------------------------------------------ miudezas
func randi_range(a: int, b: int) -> int:
	if b < a:
		var t = a
		a = b
		b = t
	return a + int(randi() % (b - a + 1))


func roundi(x: float) -> int:
	return int(round(x))


func floori(x: float) -> int:
	return int(floor(x))


func ceili(x: float) -> int:
	return int(ceil(x))


func contem(texto, parte) -> bool:
	return str(texto).find(str(parte)) >= 0


func filhos_do_tipo(no: Node, classe: String) -> Array:
	var r = []
	for f in no.get_children():
		if f.is_class(classe):
			r.append(f)
		r += filhos_do_tipo(f, classe)
	return r


## Fases do brilho da pista, calculadas aqui (ver shaders/brilho_pista.shader).
func avancar_brilho(mat: ShaderMaterial, delta: float) -> void:
	if mat == null:
		return
	var vel = mat.get_shader_param("velocidade")
	vel = float(vel) if vel != null else 1.2
	var t = float(mat.get_meta("g3_t")) if mat.has_meta("g3_t") else 0.0
	t = fposmod(t + delta * vel, 3600.0)
	mat.set_meta("g3_t", t)
	mat.set_shader_param("f_sobe", fposmod(t * 0.28, 1.0))
	mat.set_shader_param("f_pulso", fposmod(t * 1.8, TAU))
	mat.set_shader_param("f_ouro", fposmod(t * 2.6, TAU))


## z_index de qualquer CanvasItem. No Godot 3 só o Node2D tem a
## propriedade; num Control (Label, Panel...) vai direto no VisualServer.
func z(no: CanvasItem, valor) -> void:
	if no == null:
		return
	if no is Node2D:
		no.z_index = int(valor)
	else:
		no.set_meta("g3_z", int(valor))
		VisualServer.canvas_item_set_z_index(no.get_canvas_item(), int(valor))


## Nome da propriedade para tween_property: num Control do Godot 3,
## position/size/scale/... chamam rect_position/rect_size/rect_scale.
const _PROPS_CONTROL := {
	"position": "rect_position", "size": "rect_size", "scale": "rect_scale",
	"pivot_offset": "rect_pivot_offset", "rotation_degrees": "rect_rotation",
	"global_position": "rect_global_position",
}


func prop(no: Object, nome: String) -> String:
	if not (no is Control):
		return nome
	var partes = nome.split(":", true, 1)
	if _PROPS_CONTROL.has(partes[0]):
		partes[0] = _PROPS_CONTROL[partes[0]]
	return ":".join(partes)
