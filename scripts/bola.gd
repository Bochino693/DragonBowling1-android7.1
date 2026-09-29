extends Node2D

signal impacto_no_deck(dados)
signal jogada_finalizada

export var sumir_apos_impacto: bool = false
export var duracao_sumico_impacto: float = 0.045
var player_roll_solto_atual: AudioStreamPlayer = null


export var duracao_base: float = 1.08
export var escala_perto: float = 0.82
export var escala_longe: float = 0.58
export var escala_impacto: float = 0.16
export var opacidade_longe: float = 0.90

export var margem_spawn_inferior: float = 180.0
export var y_impacto_base: float = 745.0
export var y_cacapa_base: float = 500.0
export var deslocamento_cacapa_x: float = 12.0

# ÁUDIO DO ROLL
export var caminho_audio_roll: String = "res://songs/bola-roll_.wav"
export var volume_audio_roll_db: float = 18.0
export var inicio_audio_roll_em_segundos: float = 2.0

onready var sprite: AnimatedSprite = $AnimatedSprite2D

var audio_roll_player: AudioStreamPlayer = null
var audio_roll_stream: AudioStream = null
var tween_audio_roll: SceneTreeTween = null

var token_audio_roll: int = 0
var usar_audio_roll_nesta_jogada: bool = true

var pos_inicial: Vector2 = Vector2.ZERO
var pos_final_base: Vector2 = Vector2.ZERO

var em_movimento: bool = false
var tempo: float = 0.0
var duracao_atual: float = 1.0

var p0: Vector2 = Vector2.ZERO
var p1: Vector2 = Vector2.ZERO
var p2: Vector2 = Vector2.ZERO
var p3: Vector2 = Vector2.ZERO

var forca_atual: float = 1.0
var spin_atual: float = 0.0
var lateral_alvo: float = 0.0

var impacto_visual_rodando: bool = false
var escala_inicial_sprite: Vector2 = Vector2.ONE


func _ready() -> void:
	if sprite != null:
		escala_inicial_sprite = Vector2(escala_perto, escala_perto)

	_configurar_audio_roll()

	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.is_connected("size_changed", self, "_on_viewport_size_changed"):
		viewport.connect("size_changed", self, "_on_viewport_size_changed")

	atualizar_posicoes_base()
	resetar_bola()


func configurar_audio_por_jogada(tecla: String) -> void:
	# Todas as jogadas usam o som de rolamento.
	# O Game decide depois qual som de resultado tocar.
	usar_audio_roll_nesta_jogada = true


func _configurar_audio_roll() -> void:
	audio_roll_player = AudioStreamPlayer.new()
	audio_roll_player.name = "AudioRollPlayer"
	audio_roll_player.bus = "Master"
	audio_roll_player.volume_db = volume_audio_roll_db
	add_child(audio_roll_player)

	if ResourceLoader.exists(caminho_audio_roll):
		audio_roll_stream = load(caminho_audio_roll)
		audio_roll_player.stream = audio_roll_stream
	else:
		push_warning("Áudio da bola não encontrado em: " + caminho_audio_roll)



func tocar_passagem_por_cima_dos_pinos(alvo_pos: Vector2, alvo_z: int = 40, intensidade: float = 1.0) -> void:
	if impacto_visual_rodando:
		return

	em_movimento = false
	tempo = 0.0
	impacto_visual_rodando = true
	visible = true

	var base_scale: Vector2 = sprite.scale if sprite != null else Vector2.ONE
	var y_mid: float = lerp(alvo_pos.y, y_cacapa_base, 0.45)

	var x_mid: float = clamp_x_na_pista(
		alvo_pos.x + lateral_alvo * 10.0 + spin_atual * 0.4,
		y_mid
	)

	var x_end: float = clamp_x_na_pista(
		alvo_pos.x + lateral_alvo * deslocamento_cacapa_x,
		y_cacapa_base
	)

	var meio: Vector2 = Vector2(x_mid, y_mid)
	var destino: Vector2 = Vector2(x_end, y_cacapa_base)

	z_index = max(1, alvo_z - 8)

	if sprite != null and sprite.frames and sprite.frames.has_animation("roll"):
		sprite.play("roll")

	var tw: SceneTreeTween = create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)

	tw.tween_property(self, Compat.prop(self, "global_position"), meio, 0.070)
	tw.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0.92), 0.070)
	if sprite != null:
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "scale"), base_scale * 0.84, 0.070)

	tw.tween_property(self, Compat.prop(self, "global_position"), destino, 0.115)
	tw.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0.42), 0.115)
	if sprite != null:
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "scale"), base_scale * 0.52, 0.115)

	tw.tween_property(self, "modulate", Color(1, 1, 1, 0.0), 0.040)
	if sprite != null:
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "scale"), base_scale * 0.34, 0.040)

	yield(tw, "finished")

	if sprite != null:
		sprite.stop()

	visible = false
	impacto_visual_rodando = false
	emit_signal("jogada_finalizada")

func tocar_empurrao_no_deck(alvo_pos: Vector2, alvo_z: int = 40, intensidade: float = 1.0) -> void:
	# Sem pausa, sem dash e sem reposicionamento extra.
	# A bola segue direto o fluxo normal.
	impacto_visual_rodando = false
	return


func _tocar_audio_roll_imediato() -> void:
	if not usar_audio_roll_nesta_jogada:
		return
	if audio_roll_stream == null:
		return

	# Para evitar sobreposição entre uma jogada e outra,
	# uma nova jogada interrompe o roll solto anterior.
	_parar_player_roll_solto()

	var player: AudioStreamPlayer = _criar_player_roll_solto()
	if player == null:
		return

	player.play()

	# começa 2 segundos à frente no ARQUIVO,
	# mas no instante do lançamento
	if inicio_audio_roll_em_segundos > 0.0:
		var duracao: float = 0.0
		if player.stream != null and player.stream.has_method("get_length"):
			duracao = float(player.stream.get_length())

		if duracao > 0.05 and inicio_audio_roll_em_segundos < duracao:
			player.seek(inicio_audio_roll_em_segundos)

func _agendar_audio_roll_apos_lancamento() -> void:
	token_audio_roll += 1
	if not usar_audio_roll_nesta_jogada:
		return
	var esta_jogada = token_audio_roll
	# O rolar começa quando a bola já está na tela, não antes dela.
	yield(VisualServer, "frame_post_draw")
	if GameConfig.atraso_som_jogada > 0.0:
		yield(get_tree().create_timer(GameConfig.atraso_som_jogada), "timeout")
	if esta_jogada != token_audio_roll or not is_inside_tree():
		return
	_tocar_audio_roll_imediato()


func _fade_out_audio_roll(tempo_fade: float = 0.18) -> void:
	if audio_roll_player == null:
		return
	if not audio_roll_player.playing:
		return

	if tween_audio_roll != null:
		tween_audio_roll.kill()

	tween_audio_roll = create_tween()
	tween_audio_roll.tween_property(audio_roll_player, "volume_db", -32.0, tempo_fade)
	yield(tween_audio_roll, "finished")

	if audio_roll_player != null:
		audio_roll_player.stop()
		audio_roll_player.volume_db = volume_audio_roll_db

	tween_audio_roll = null


func _stop_audio_roll_imediato(parar_roll_solto: bool = true) -> void:
	token_audio_roll += 1

	if tween_audio_roll != null:
		tween_audio_roll.kill()
		tween_audio_roll = null

	if audio_roll_player != null and audio_roll_player.playing:
		audio_roll_player.stop()

	if audio_roll_player != null:
		audio_roll_player.volume_db = volume_audio_roll_db

	if parar_roll_solto:
		_parar_player_roll_solto()


func encerrar_audio_roll_para_resultado(tempo_fade: float = 0.10) -> void:
	# Não bloqueia mais o fluxo visual.
	return


func _on_viewport_size_changed() -> void:
	atualizar_posicoes_base()

	if not em_movimento and not impacto_visual_rodando:
		global_position = pos_inicial


func sumir_no_impacto() -> void:
	em_movimento = false
	impacto_visual_rodando = true
	visible = true

	var tw: SceneTreeTween = create_tween()
	tw.set_trans(Tween.TRANS_LINEAR)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0.0), duracao_sumico_impacto)

	yield(tw, "finished")

	if sprite != null:
		sprite.stop()

	visible = false
	modulate = Color(1, 1, 1, 0.0)
	rotation_degrees = 0.0
	impacto_visual_rodando = false
	emit_signal("jogada_finalizada")


func atualizar_posicoes_base() -> void:
	var tela: Vector2 = Tela.retangulo().size
	if tela.x <= 0.0 or tela.y <= 0.0:
		return

	pos_inicial = Vector2(tela.x * 0.5, tela.y + margem_spawn_inferior)
	pos_final_base = Vector2(tela.x * 0.5, y_impacto_base)


func lancar_bola(direcao: Vector2, forca: float = 1.0, spin: float = 0.0) -> void:
	if em_movimento:
		return

	atualizar_posicoes_base()

	em_movimento = true
	impacto_visual_rodando = false
	tempo = 0.0
	forca_atual = forca
	spin_atual = spin
	lateral_alvo = clamp(direcao.x, -0.78, 0.78)

	var fator_forca: float = inverse_lerp(0.96, 1.14, clamp(forca, 0.96, 1.14))
	duracao_atual = lerp(0.82, 0.68, fator_forca)
	duracao_atual = clamp(duracao_atual, 0.68, 0.82)

	p0 = pos_inicial

	var y1: float = lerp(pos_inicial.y, pos_final_base.y, 0.20)
	var y2: float = lerp(pos_inicial.y, pos_final_base.y, 0.56)
	var y3: float = pos_final_base.y

	var alvo1: float = lateral_alvo
	var alvo2: float = lateral_alvo
	var alvo3: float = lateral_alvo

	if lateral_alvo <= -0.58:
		alvo1 = -0.16
		alvo2 = -0.44
		alvo3 = -0.58
	elif lateral_alvo >= 0.58:
		alvo1 = 0.16
		alvo2 = 0.44
		alvo3 = 0.58
	elif lateral_alvo < -0.12:
		alvo1 = lateral_alvo * 0.40
		alvo2 = lateral_alvo * 0.70
		alvo3 = lateral_alvo * 0.84
	elif lateral_alvo > 0.12:
		alvo1 = lateral_alvo * 0.40
		alvo2 = lateral_alvo * 0.70
		alvo3 = lateral_alvo * 0.84
	else:
		alvo1 = spin * 0.002
		alvo2 = spin * 0.005
		alvo3 = spin * 0.007

	var x1: float = clamp_x_na_pista(pos_inicial.x + alvo1 * meia_largura_pista_em_y(y1), y1)
	var x2: float = clamp_x_na_pista(pos_inicial.x + alvo2 * meia_largura_pista_em_y(y2), y2)
	var x3: float = clamp_x_na_pista(pos_inicial.x + alvo3 * meia_largura_pista_em_y(y3), y3)

	p1 = Vector2(x1, y1)
	p2 = Vector2(x2, y2)
	p3 = Vector2(x3, y3)

	global_position = p0
	visible = true
	modulate = Color(1, 1, 1, 1)
	rotation_degrees = 0.0

	if sprite != null:
		sprite.scale = Vector2(escala_perto, escala_perto)

	z_index = 300

	if sprite != null and sprite.frames and sprite.frames.has_animation("roll"):
		sprite.play("roll")

	_stop_audio_roll_imediato()
	_agendar_audio_roll_apos_lancamento()


func _process(delta: float) -> void:
	if not em_movimento:
		return

	tempo += delta
	var t: float = clamp(tempo / duracao_atual, 0.0, 1.0)

	var pos: Vector2 = bezier(p0, p1, p2, p3, t)
	global_position = pos

	atualizar_visual(t)

	if t >= 1.0:
		finalizar_no_impacto()


func bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return (
		u * u * u * a +
		3.0 * u * u * t * b +
		3.0 * u * t * t * c +
		t * t * t * d
	)


func atualizar_visual(t: float) -> void:
	if sprite == null:
		return

	var escala: float = lerp(escala_perto, escala_longe, t)
	sprite.scale = Vector2(escala, escala)

	var alpha: float = lerp(1.0, opacidade_longe, t)
	modulate = Color(1, 1, 1, alpha)

	rotation_degrees = lerp(0.0, lateral_alvo * 14.0, t)
	z_index = int(300 - t * 220.0)


func finalizar_no_impacto() -> void:
	if not em_movimento:
		return

	em_movimento = false

	var dados: Dictionary = {
		"impact_x": global_position.x,
		"impact_y": global_position.y,
		"forca": forca_atual,
		"spin": spin_atual,
		"lateral": lateral_alvo
	}

	emit_signal("impacto_no_deck", dados)
	

func _efeito_impacto_visual_bola() -> void:
	if sprite == null:
		return

	var base_pos: Vector2 = global_position
	var base_scale: Vector2 = sprite.scale
	var base_rot: float = rotation_degrees

	var intensidade: float = clamp(forca_atual, 0.9, 1.2)

	var squash_y: float = lerp(0.90, 0.82, intensidade - 0.9)
	var squash_x: float = lerp(1.05, 1.12, intensidade - 0.9)

	var impacto_y: float = lerp(4.0, 10.0, intensidade - 0.9)
	var impacto_x: float = lateral_alvo * 6.0

	var rot: float = lateral_alvo * 6.0

	var tw: SceneTreeTween = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)

	# 👉 compressão no impacto
	tw.tween_property(sprite, Compat.prop(sprite, "scale"), Vector2(base_scale.x * squash_x, base_scale.y * squash_y), 0.045)
	tw.parallel().tween_property(self, Compat.prop(self, "global_position"), base_pos + Vector2(impacto_x, impacto_y), 0.045)
	tw.parallel().tween_property(self, Compat.prop(self, "rotation_degrees"), base_rot + rot, 0.045)

	# 👉 retorno
	tw.tween_property(sprite, Compat.prop(sprite, "scale"), base_scale, 0.060)
	tw.parallel().tween_property(self, Compat.prop(self, "global_position"), base_pos, 0.060)
	tw.parallel().tween_property(self, Compat.prop(self, "rotation_degrees"), base_rot, 0.060)

	yield(tw, "finished")


func mover_ate_contato_real(alvo_pos: Vector2, alvo_z: int = 40, intensidade: float = 1.0) -> void:
	# Mantida só por compatibilidade.
	# Não faz mais "encostar" para evitar efeito de kique.
	impacto_visual_rodando = false
	return

func tocar_efeito_acerto_e_sair(alvo_pos: Vector2, alvo_z: int = 40, intensidade: float = 1.0) -> void:
	var _g3_estado = null
	em_movimento = false
	tempo = 0.0
	impacto_visual_rodando = false

	# Não corta mais o roll aqui.
	_g3_estado = tocar_passagem_ate_cacapa(alvo_z, intensidade)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")


func tocar_saida_apos_acerto(alvo_pos: Vector2, alvo_z: int = 40, intensidade: float = 1.0) -> void:
	var _g3_estado = null
	em_movimento = false
	tempo = 0.0
	impacto_visual_rodando = false
	_g3_estado = tocar_passagem_ate_cacapa(alvo_z, intensidade)
	if _g3_estado is GDScriptFunctionState:
		_g3_estado = yield(_g3_estado, "completed")


func tocar_passagem_ate_cacapa(alvo_z: int = 40, intensidade: float = 1.0) -> void:
	if impacto_visual_rodando:
		return

	em_movimento = false
	tempo = 0.0
	impacto_visual_rodando = true
	visible = true
	rotation_degrees = 0.0

	var base_pos: Vector2 = global_position
	var base_scale: Vector2 = sprite.scale if sprite != null else Vector2.ONE

	var pico: Vector2 = base_pos + Vector2(lateral_alvo * 12.0, -38.0)
	var destino: Vector2 = Vector2(
		base_pos.x + lateral_alvo * deslocamento_cacapa_x,
		y_cacapa_base
	)

	z_index = 2

	if sprite != null and sprite.frames and sprite.frames.has_animation("roll"):
		sprite.play("roll")

	var tw: SceneTreeTween = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)

	tw.tween_property(self, Compat.prop(self, "global_position"), pico, 0.070)
	tw.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0.90), 0.070)

	if sprite != null:
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "scale"), base_scale * 0.74, 0.070)

	tw.tween_property(self, Compat.prop(self, "global_position"), destino, 0.138)
	tw.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0.42), 0.138)

	if sprite != null:
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "scale"), base_scale * 0.38, 0.138)

	tw.tween_property(self, "modulate", Color(1, 1, 1, 0.0), 0.048)

	if sprite != null:
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "scale"), base_scale * 0.20, 0.048)

	yield(tw, "finished")

	if sprite != null:
		sprite.stop()

	visible = false
	impacto_visual_rodando = false
	emit_signal("jogada_finalizada")
	

func _aguardar_audio_roll_terminar_completo() -> void:
	if not usar_audio_roll_nesta_jogada:
		return
	if audio_roll_player == null:
		return
	if not audio_roll_player.playing:
		return

	yield(audio_roll_player, "finished")

func sumir_imediatamente_no_impacto() -> void:
	em_movimento = false
	impacto_visual_rodando = false
	tempo = 0.0
	visible = false
	modulate = Color(1, 1, 1, 0)
	rotation_degrees = 0.0
	z_index = -100

	if sprite != null:
		sprite.stop()

	emit_signal("jogada_finalizada")


func tocar_passagem_reta() -> void:
	if impacto_visual_rodando:
		return

	em_movimento = false
	tempo = 0.0
	impacto_visual_rodando = true
	visible = true
	rotation_degrees = 0.0

	var base_pos: Vector2 = global_position
	var base_scale: Vector2 = sprite.scale if sprite != null else Vector2.ONE

	var pico: Vector2 = base_pos + Vector2(lateral_alvo * 6.0, -34.0)
	var destino: Vector2 = Vector2(
		base_pos.x + lateral_alvo * 12.0,
		y_cacapa_base
	)

	z_index = 2

	if sprite != null and sprite.frames and sprite.frames.has_animation("roll"):
		sprite.play("roll")

	var tw: SceneTreeTween = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)

	tw.tween_property(self, Compat.prop(self, "global_position"), pico, 0.060)
	tw.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0.90), 0.060)

	if sprite != null:
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "scale"), base_scale * 0.72, 0.060)

	tw.tween_property(self, Compat.prop(self, "global_position"), destino, 0.130)
	tw.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0.46), 0.130)

	if sprite != null:
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "scale"), base_scale * 0.40, 0.130)

	tw.tween_property(self, "modulate", Color(1, 1, 1, 0.0), 0.055)

	if sprite != null:
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "scale"), base_scale * 0.20, 0.055)

	yield(tw, "finished")

	if sprite != null:
		sprite.stop()

	visible = false
	impacto_visual_rodando = false
	emit_signal("jogada_finalizada")
	
	

func resetar_bola() -> void:
	atualizar_posicoes_base()

	em_movimento = false
	impacto_visual_rodando = false
	tempo = 0.0
	forca_atual = 1.0
	spin_atual = 0.0
	lateral_alvo = 0.0
	usar_audio_roll_nesta_jogada = true

	# NÃO corta o roll solto aqui,
	# senão X/V/C continuam perdendo o final do som.
	_stop_audio_roll_imediato(false)

	global_position = pos_inicial
	visible = false
	modulate = Color(1, 1, 1, 1)
	rotation_degrees = 0.0

	if sprite != null:
		sprite.scale = Vector2(escala_perto, escala_perto)

	if sprite != null and sprite.frames:
		if sprite.frames.has_animation("idle"):
			sprite.play("idle")
		elif sprite.frames.has_animation("roll"):
			sprite.play("roll")
			sprite.stop()

func _parar_player_roll_solto() -> void:
	if is_instance_valid(player_roll_solto_atual):
		player_roll_solto_atual.stop()
		player_roll_solto_atual.queue_free()
	player_roll_solto_atual = null


func _criar_player_roll_solto() -> AudioStreamPlayer:
	if audio_roll_stream == null:
		return null

	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root

	var player := AudioStreamPlayer.new()
	player.name = "AudioRollSolto"
	player.bus = "Master"
	player.stream = audio_roll_stream
	player.volume_db = volume_audio_roll_db
	raiz.add_child(player)

	player_roll_solto_atual = player

	player.connect("finished", self, "_fim_do_roll_solto", [player])

	return player


func _fim_do_roll_solto(player: AudioStreamPlayer) -> void:
	if player_roll_solto_atual == player:
		player_roll_solto_atual = null
	if is_instance_valid(player):
		player.queue_free()


func meia_largura_pista_em_y(y: float) -> float:
	var y_spawn: float = pos_inicial.y
	var y_topo: float = y_impacto_base

	var t: float = inverse_lerp(y_spawn, y_topo, y)
	t = clamp(t, 0.0, 1.0)

	var meia_base: float = 236.0
	var meia_topo: float = 166.0

	return lerp(meia_base, meia_topo, t)


func clamp_x_na_pista(x: float, y: float) -> float:
	var centro: float = pos_inicial.x
	var meia: float = meia_largura_pista_em_y(y)
	return clamp(x, centro - meia, centro + meia)
