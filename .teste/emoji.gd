extends SceneTree
## Emojis em todos os tamanhos do jogo, numa foto (giro da TV Box).
##   DRAGON_GIRO=1 FOTO=/x.png godot3 --path . --resolution 1920x1080 -s res://.teste/emoji.gd
var q = 0
func _idle(_d):
	q += 1
	if q == 2:
		var tela = root.get_node("Tela")
		var compat = root.get_node("Compat")
		var raiz = Control.new()
		root.add_child(raiz)
		tela.cobrir(raiz)
		var fundo = ColorRect.new()
		fundo.color = Color(0.03, 0.04, 0.09)
		fundo.rect_size = tela.TAMANHO
		raiz.add_child(fundo)
		var y = 40
		for item in [["res://fonts/painel_arcade.ttf", 22, 6], ["res://fonts/padrao_opensans.ttf", 30, 0], ["res://fonts/padrao_opensans.ttf", 34, 6], ["res://fonts/painel_arcade.ttf", 40, 0], ["res://fonts/padrao_opensans.ttf", 44, 6], ["res://fonts/arcade_impact.ttf", 46, 14]]:
			var l = Label.new()
			l.text = "%d  🎳🏆🎮🤝👀✅✔ PLAY" % item[1]
			l.rect_position = Vector2(30, y)
			compat.fonte(l, item[0])
			compat.tamanho(l, item[1])
			l.add_color_override("font_outline_modulate", Color.black)
			compat.contorno(l, item[2])
			raiz.add_child(l)
			y += item[1] * 2
	if q == 8:
		var img = root.get_texture().get_data()
		img.flip_y()
		img.save_png(OS.get_environment("FOTO"))
		quit()
	return false
