class_name Cortina
extends CanvasLayer

## TROCA DE TELA LEVE, SEM TELA CINZA E SEM TRAVAR.
##
## A tela antiga escurece rápido (na cor da abertura), a cena nova é
## montada por baixo do véu e o véu se abre enquanto a cena nova faz a
## animação de montagem dela.
##
## Antes a troca tirava uma FOTO da tela (ler a imagem de volta da placa de
## vídeo). Na TV Box essa leitura para tudo por um bom tempo — e a foto
## podia voltar girada. O véu é só um retângulo: nenhum custo.

const ESCURECER := 0.18
const CLAREAR := 0.35
const COR := Color(0.024, 0.031, 0.086)
const QUADRO_RAPIDO_MS := 50

var _veu: ColorRect
var _tween: SceneTreeTween


func _init() -> void:
	name = "Cortina"
	layer = 126
	pause_mode = Node.PAUSE_MODE_PROCESS
	_veu = ColorRect.new()
	_veu.color = COR
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Grande o bastante para cobrir a tela em qualquer giro.
	_veu.rect_position = Vector2(-4000, -4000)
	_veu.rect_size = Vector2(12000, 12000)
	_veu.modulate.a = 0.0
	add_child(_veu)


# Godot 3: a classe não pode citar o próprio nome (class_name) dentro dela.
static func _obter(arvore: SceneTree):
	var c = arvore.root.get_node_or_null("Cortina")
	if c == null:
		c = load("res://scripts/cortina.gd").new()
		arvore.root.add_child(c)
	return c


## Escurece a tela. Use com await antes de trocar a cena.
static func fechar(arvore: SceneTree) -> void:
	var c = _obter(arvore)
	if c._tween != null:
		c._tween.kill()
	c._tween = c.create_tween()
	c._tween.tween_property(c._veu, "modulate:a", 1.0, ESCURECER * (1.0 - c._veu.modulate.a))
	yield(c._tween, "finished")


## Abre o véu depois que a cena nova já desenhou (a montagem dela aparece).
static func abrir(arvore: SceneTree) -> void:
	var c = _obter(arvore)
	# Os primeiros quadros da cena nova são longos (montagem, primeiras
	# letras desenhadas). O véu só abre quando a TV Box volta ao ritmo: dois
	# quadros seguidos rápidos (ou no máximo 2 s), senão a abertura do véu
	# sairia aos trancos.
	var inicio = Time.get_ticks_msec()
	var ultimo = inicio
	var rapidos := 0
	while rapidos < 2 and Time.get_ticks_msec() - inicio < 2000:
		yield(arvore, "idle_frame")
		var agora = Time.get_ticks_msec()
		rapidos = rapidos + 1 if agora - ultimo < QUADRO_RAPIDO_MS else 0
		ultimo = agora
	if c._tween != null:
		c._tween.kill()
	c._tween = c.create_tween()
	c._tween.tween_property(c._veu, "modulate:a", 0.0, CLAREAR)


## Troca de cena completa: escurece, troca, abre.
static func trocar_para(arvore: SceneTree, cena) -> void:
	var _g3_estado = null
	_g3_estado = fechar(arvore)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")
	if cena is PackedScene:
		arvore.change_scene_to(cena)
	else:
		arvore.change_scene(str(cena))
	abrir(arvore)
