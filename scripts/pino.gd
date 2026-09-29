extends Node2D


export var deslocamento_empurrao_max_x: float = 28.0
export var deslocamento_empurrao_max_y: float = 22.0
export var duracao_empurrao: float = 0.080
export var duracao_tombo: float = 0.17
export var arrasto_no_chao: float = 0.90

export var rotacao_max_queda: float = 138.0
export var distancia_voo_max: float = 70.0

export var atrito_plano: float = 0.94
export var atrito_rotacional: float = 0.91
export var limiar_deslocamento: float = 0.08
export var limiar_colisao_em_cadeia: float = 0.12
export var ganho_rotacao_impacto: float = 108.0
export var ganho_deslocamento_impacto: float = 68.0
export var deslocamento_maximo_sem_cair: float = 12.0


export var largura_visual_alvo: float = 76.0
export var altura_visual_alvo: float = 144.0
export var largura_visual_down: float = 148.0
export var altura_visual_down: float = 116.0
export var largura_visual_strike: float = 144.0
export var altura_visual_strike: float = 114.0

export var largura_colisao_base: float = 48.0
export var altura_colisao_base: float = 88.0

export var escala_idle: float = 1.00
export var escala_down_left: float = 1.03
export var escala_down_rt: float = 1.03
export var escala_strike: float = 1.02

export var limiar_queda: float = 0.15
export var limiar_quase_queda: float = 0.07


export var numero: int = 1

export var fator_profundidade: float = 1.0
export var mistura_profundidade_down: float = 0.46
export var mistura_profundidade_strike: float = 0.50

export var animacao_base: String = "idle"

export var offset_idle: Vector2 = Vector2(0, 0)
export var offset_down_left: Vector2 = Vector2(6, 3)
export var offset_down_rt: Vector2 = Vector2(6, 3)
export var offset_strike: Vector2 = Vector2(1, 2)

export var linha_base_local: float = 26.0

export var amortecimento_idle: float = 0.72
export var duracao_queda: float = 0.22
export var duracao_voo: float = 0.10

export var duracao_quique: float = 0.20
export var intensidade_quique: float = 1.32
export var deslocamento_quique_y: float = 20.0
export var deslocamento_quique_x: float = 8.0
export var rotacao_quique: float = 11.0
export var usar_quique_no_tatame: bool = true


export var tempo_espera_apos_queda: float = 0.85
export var tempo_fade_apos_queda: float = 0.28

onready var sprite: AnimatedSprite = $AnimatedSprite2D
onready var numero_label: Label = $Label


var derrubado: bool = false
var hover: bool = false
var game_ref: Node = null

var empurrando: bool = false
var velocidade_plano: Vector2 = Vector2.ZERO
var velocidade_rotacional: float = 0.0
var origem_ultimo_impacto: Vector2 = Vector2.ZERO
var posicao_base_local: Vector2 = Vector2.ZERO
var animacao_atual_nome: String = "idle"
var escala_fx: float = 1.0
var escala_travada_queda: Vector2 = Vector2.ZERO
var travar_escala_na_queda: bool = false

var sumindo_apos_queda: bool = false
var finalizando_queda: bool = false
var em_quase_queda: bool = false
var forca_acumulada: Vector2 = Vector2.ZERO

var ref_idle: Vector2 = Vector2(64, 128)
var ref_down_left: Vector2 = Vector2(96, 96)
var ref_down_rt: Vector2 = Vector2(96, 96)
var ref_strike: Vector2 = Vector2(96, 96)


func _ready() -> void:
	if numero_label != null:
		numero_label.text = str(numero)
		Compat.tamanho(numero_label, 24)
		numero_label.add_color_override("font_color", Color(1.0, 0.97, 0.35))
		numero_label.add_color_override("font_outline_modulate", Color(0.05, 0.05, 0.10))
		Compat.contorno(numero_label, 5)
		numero_label.align = Label.ALIGN_CENTER
		numero_label.valign = Label.VALIGN_CENTER
		numero_label.rect_size = Vector2(56, 32)
		Compat.z(numero_label, 1000)
		numero_label.visible = true

	if sprite != null and sprite.frames != null:
		for nome in sprite.frames.get_animation_names():
			sprite.frames.set_animation_loop(nome, nome == "idle")

	if sprite != null and not sprite.is_connected("animation_finished", self, "_on_anim_finished"):
		sprite.connect("animation_finished", self, "_on_anim_finished")

	if sprite != null and not sprite.is_connected("frame_changed", self, "_on_frame_changed"):
		sprite.connect("frame_changed", self, "_on_frame_changed")

	aplicar_shader_borda_suave()
	cachear_referencias_animacoes()
	atualizar_posicao_base()
	resetar()


func cachear_referencias_animacoes() -> void:
	ref_idle = obter_maior_tamanho_animacao("idle")
	ref_down_left = obter_maior_tamanho_animacao("down_left")
	ref_down_rt = obter_maior_tamanho_animacao("down_rt")
	ref_strike = obter_maior_tamanho_animacao("strike")

	var ref_down_unificada = Vector2(
		max(ref_down_left.x, ref_down_rt.x),
		max(ref_down_left.y, ref_down_rt.y)
	)
	ref_down_left = ref_down_unificada
	ref_down_rt = ref_down_unificada


func obter_maior_tamanho_animacao(nome: String) -> Vector2:
	var max_sz = Vector2(64, 128)
	if sprite == null or sprite.frames == null:
		return max_sz
	if not sprite.frames.has_animation(nome):
		return max_sz

	var total = sprite.frames.get_frame_count(nome)
	max_sz = Vector2.ZERO
	var achou := false

	for i in range(total):
		var tex = sprite.frames.get_frame(nome, i)
		if tex != null:
			var sz = tex.get_size()
			max_sz.x = max(max_sz.x, sz.x)
			max_sz.y = max(max_sz.y, sz.y)
			achou = true

	return max_sz if achou else Vector2(64, 128)


func _process(delta: float) -> void:
	if sprite == null or not empurrando:
		return

	simular_empurrao(delta)


func _draw() -> void:
	if hover and not derrubado:
		draw_line(Vector2(-14, linha_base_local), Vector2(14, linha_base_local), Color(1, 0.9, 0.2, 0.65), 3.0)


func obter_referencia_animacao() -> Vector2:
	match animacao_atual_nome:
		"idle":
			return ref_idle
		"down_left":
			return ref_down_left
		"down_rt":
			return ref_down_rt
		"strike":
			return ref_strike
	return ref_idle


func obter_fator_animacao() -> float:
	match animacao_atual_nome:
		"idle":
			return fator_profundidade
		"down_left", "down_rt":
			return lerp(1.0, fator_profundidade, mistura_profundidade_down)
		"strike":
			return lerp(1.0, fator_profundidade, mistura_profundidade_strike)
	return fator_profundidade


func obter_box_animacao() -> Vector2:
	var f = obter_fator_animacao()
	match animacao_atual_nome:
		"idle":
			return Vector2(largura_visual_alvo, altura_visual_alvo) * f
		"down_left", "down_rt":
			return Vector2(largura_visual_down, altura_visual_down) * f
		"strike":
			return Vector2(largura_visual_strike, altura_visual_strike) * f
	return Vector2(largura_visual_alvo, altura_visual_alvo) * f


func obter_multiplicador_animacao() -> float:
	match animacao_atual_nome:
		"idle":
			return escala_idle
		"down_left":
			return escala_down_left
		"down_rt":
			return escala_down_rt
		"strike":
			return escala_strike
	return 1.0


func obter_offset_animacao() -> Vector2:
	match animacao_atual_nome:
		"idle":
			return offset_idle
		"down_left":
			return offset_down_left
		"down_rt":
			return offset_down_rt
		"strike":
			return offset_strike
	return Vector2.ZERO


func atualizar_posicao_base() -> void:
	posicao_base_local = position


func recalcular_visual() -> void:
	atualizar_tamanho_base()

func atualizar_tamanho_base(mult_hover: float = 1.0) -> void:
	if sprite == null:
		return

	if derrubado:
		fixar_tamanho_visual_derrubado()
		return

	var ref: Vector2 = obter_referencia_animacao()
	if ref.x <= 0.0 or ref.y <= 0.0:
		return

	var alvo: Vector2 = obter_box_animacao()
	var ex: float = alvo.x / ref.x
	var ey: float = alvo.y / ref.y
	var eb: float = min(ex, ey)
	var ef: float = eb * obter_multiplicador_animacao() * mult_hover * escala_fx

	sprite.scale = Vector2(ef, ef)
	ajustar_ancora_visual(ref, ef)
	atualizar_posicao_numero(ref, ef)


func ajustar_ancora_visual(ref_size: Vector2, escala_final: float) -> void:
	if sprite == null:
		return
	var ofs = offset_idle if travar_escala_na_queda else obter_offset_animacao()
	sprite.position = Vector2(ofs.x, linha_base_local - ref_size.y * escala_final + ofs.y)
	sprite.offset = Vector2.ZERO


func atualizar_posicao_numero(ref_size: Vector2, escala_final: float) -> void:
	if numero_label == null:
		return

	var topo_y = sprite.position.y
	var centro_x = sprite.position.x
	numero_label.rect_position = Vector2(
		centro_x - numero_label.rect_size.x * 0.5,
		topo_y + ref_size.y * escala_final * 0.12
	)

	if derrubado:
		numero_label.rect_position.x += clamp(sprite.rotation_degrees * 0.10, -7.0, 7.0)


func obter_area_colisao() -> Vector2:
	var box: Vector2 = Vector2(largura_colisao_base, altura_colisao_base)

	match animacao_atual_nome:
		"idle":
			box *= 1.0
		"down_left", "down_rt":
			box = Vector2(box.x * 1.24, box.y * 0.72)
		"strike":
			box = Vector2(box.x * 1.18, box.y * 0.76)

	box *= fator_profundidade

	match numero:
		1:
			box *= Vector2(1.06, 1.08)
		2, 3:
			box *= Vector2(1.03, 1.04)
		7, 10:
			box *= Vector2(0.98, 1.00)

	return box

func foi_clicado(mouse_global: Vector2) -> bool:
	var area = obter_area_colisao()
	var rect = Rect2(global_position + Vector2(-area.x * 0.5, -area.y * 0.5), area)
	return rect.has_point(mouse_global)


func atualizar_hover(mouse_global: Vector2) -> void:
	var novo_hover: bool = not derrubado and foi_clicado(mouse_global)
	if hover != novo_hover:
		hover = novo_hover
		if sprite != null:
			sprite.modulate = Color(1.06, 1.06, 1.0, sprite.modulate.a) if hover else Color(1, 1, 1, sprite.modulate.a)
		atualizar_tamanho_base(1.015 if hover else 1.0)
		update()


func receber_forca(forca_vec: Vector2, magnitude: float, origem: Vector2) -> void:
	if derrubado:
		return

	# ── Proteção: ignora força se este pino está na lista de sobreviventes ──
	if game_ref != null and "pinos_protegidos_sobreviventes" in game_ref:
		if numero in game_ref.pinos_protegidos_sobreviventes:
			return

	var dir = forca_vec.normalized()
	if dir.length() <= 0.001:
		dir = (global_position - origem).normalized()

	origem_ultimo_impacto = origem

	var peso_local: float = 1.0
	match numero:
		1:
			peso_local = 0.92
		2, 3:
			peso_local = 0.95
		4, 5, 6:
			peso_local = 1.00
		7, 10:
			peso_local = 1.03

	var ganho: float = magnitude / peso_local

	forca_acumulada += dir * ganho
	velocidade_plano += Vector2(dir.x * 1.05, -abs(dir.y) * 0.62) * ganho * ganho_deslocamento_impacto
	velocidade_rotacional += dir.x * ganho * ganho_rotacao_impacto
	empurrando = true

	var magnitude_total: float = forca_acumulada.length()

	var limiar_efetivo: float = limiar_queda
	if numero in [7, 8, 9, 10]:
		limiar_efetivo = limiar_queda * 0.70
	elif numero in [4, 5, 6]:
		limiar_efetivo = limiar_queda * 0.82

	if magnitude_total >= limiar_efetivo:
		var lado: String = "down_rt" if forca_acumulada.x >= 0.0 else "down_left"
		if abs(forca_acumulada.x) < 0.05:
			lado = "strike"

		cair_voando(lado, clamp(magnitude_total, 0.98, 1.72), origem)
		forca_acumulada = Vector2.ZERO
	elif magnitude_total >= limiar_quase_queda * 0.85:
		if not em_quase_queda and not finalizando_queda:
			_oscilar(dir, magnitude_total)


func simular_empurrao(delta: float) -> void:
	if derrubado:
		return
	if not empurrando:
		return
		
		
	# ── Proteção: cancela empurrão se protegido ──
	if game_ref != null and "pinos_protegidos_sobreviventes" in game_ref:
		if numero in game_ref.pinos_protegidos_sobreviventes:
			empurrando = false
			velocidade_plano = Vector2.ZERO
			velocidade_rotacional = 0.0
			forca_acumulada = Vector2.ZERO
			position = posicao_base_local
			return

	position += velocidade_plano * delta
	velocidade_plano *= pow(atrito_plano, delta * 60.0)

	if sprite != null:
		sprite.rotation_degrees += velocidade_rotacional * delta

	velocidade_rotacional *= pow(atrito_rotacional, delta * 60.0)

	var deslocamento: float = position.distance_to(posicao_base_local)

	if deslocamento >= deslocamento_maximo_sem_cair or forca_acumulada.length() >= limiar_colisao_em_cadeia:
		var lado: String = "down_rt" if velocidade_plano.x >= 0.0 else "down_left"
		if abs(velocidade_plano.x) < 1.2:
			lado = "strike"

		cair_voando(lado, clamp(max(forca_acumulada.length(), 0.98), 0.98, 1.60), origem_ultimo_impacto)
		forca_acumulada = Vector2.ZERO
		return

	if velocidade_plano.length() < limiar_deslocamento and abs(velocidade_rotacional) < 1.0:
		empurrando = false
		velocidade_plano = Vector2.ZERO
		velocidade_rotacional = 0.0

		if not derrubado:
			var tw = create_tween()
			tw.set_trans(Tween.TRANS_SINE)
			tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(self, Compat.prop(self, "position"), posicao_base_local, 0.08)
			if sprite != null:
				tw.parallel().tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), 0.0, 0.08)


func _oscilar(direcao: Vector2, magnitude: float) -> void:
	if derrubado or sprite == null:
		return

	em_quase_queda = true

	var lado_x: float = direcao.x
	if abs(lado_x) < 0.05:
		lado_x = 1.0 if randf() > 0.5 else -1.0

	var forca_local: float = clamp(magnitude, 0.65, 1.15)

	var amp_rot: float = lerp(8.0, 18.0, inverse_lerp(0.65, 1.15, forca_local)) * sign(lado_x)
	var amp_x: float = lerp(3.0, 7.0, inverse_lerp(0.65, 1.15, forca_local)) * sign(lado_x)

	var base_pos: Vector2 = sprite.position
	var base_rot: float = sprite.rotation_degrees

	var tw: SceneTreeTween = create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)

	tw.tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), base_rot + amp_rot, 0.055)
	tw.parallel().tween_property(sprite, Compat.prop(sprite, "position"), base_pos + Vector2(amp_x, -abs(amp_x) * 0.25), 0.055)

	tw.tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), base_rot - amp_rot * 0.82, 0.095)
	tw.parallel().tween_property(sprite, Compat.prop(sprite, "position"), base_pos + Vector2(-amp_x * 0.72, 0.0), 0.095)

	tw.tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), base_rot + amp_rot * 0.26, 0.055)
	tw.parallel().tween_property(sprite, Compat.prop(sprite, "position"), base_pos + Vector2(amp_x * 0.20, 0.0), 0.055)

	tw.tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), base_rot, 0.070)
	tw.parallel().tween_property(sprite, Compat.prop(sprite, "position"), base_pos, 0.070)

	tw.connect("finished", self, "_fim_quase_queda")


func _fim_quase_queda() -> void:
	em_quase_queda = false
	forca_acumulada = Vector2.ZERO


func cair(animacao: String, intensidade: float = 1.0, origem_impacto: Vector2 = Vector2.ZERO) -> void:
	if derrubado:
		return
	cair_voando(animacao, intensidade, origem_impacto)


# ─────────────────────────────────────────────────────────────────────────────
# cair_voando
#
# O delay_s simula o tempo que a onda de impacto leva até este pino.
# TODOS os efeitos visuais (flash, squash, rotação, skew) ficam DEPOIS
# do await — o pino só reage quando a "onda" fisicamente chega nele.
# ─────────────────────────────────────────────────────────────────────────────
func cair_voando(animacao: String, intensidade: float = 1.0, origem_impacto: Vector2 = Vector2.ZERO, delay_s: float = 0.0) -> void:
	if derrubado:
		return
		
	if delay_s > 0.001:
		yield(get_tree().create_timer(delay_s), "timeout")
		if derrubado:
			return

	# ── Proteção pós-delay: se virou sobrevivente durante o delay, aborta ──
	if game_ref != null and "pinos_protegidos_sobreviventes" in game_ref:
		if numero in game_ref.pinos_protegidos_sobreviventes:
			return

	# Pausa silenciosa — o pino fica completamente estático até aqui.
	# Nada pisca, nada se move. A reação só começa após o delay.
	if delay_s > 0.001:
		yield(get_tree().create_timer(delay_s), "timeout")
		if derrubado:
			return

	# ── A partir daqui a bola tocou este pino ────────────────
	derrubado = true
	hover = false
	escala_fx = 1.0
	sumindo_apos_queda = false
	finalizando_queda = false
	em_quase_queda = false
	empurrando = false
	forca_acumulada = Vector2.ZERO
	velocidade_plano = Vector2.ZERO
	velocidade_rotacional = 0.0

	if numero_label != null:
		numero_label.modulate = Color(1, 1, 1, 1)
		numero_label.visible = true
		var tw_num: SceneTreeTween = create_tween()
		tw_num.tween_property(numero_label, "modulate", Color(1, 1, 1, 0.0), 0.05)
		tw_num.connect("finished", self, "_esconder_numero")

	var tipo_queda: String = animacao
	if not (tipo_queda in ["down_left", "down_rt", "strike"]):
		tipo_queda = "strike"

	animacao_atual_nome = tipo_queda
	travar_escala_na_queda = true

	if sprite != null:
		escala_travada_queda = sprite.scale
		if sprite.frames != null and sprite.frames.has_animation("idle"):
			sprite.play("idle")
			sprite.stop()
			sprite.frame = 0
		fixar_tamanho_visual_derrubado()

	# ── Flash de contato — dispara AQUI, depois do delay ─────
	# O pino "acende" exatamente quando é tocado, nunca antes.
	if sprite != null:
		var tw_flash: SceneTreeTween = create_tween()
		tw_flash.set_parallel(true)
		tw_flash.tween_property(sprite, "modulate", Color(1.55, 1.45, 1.30, 1.0), 0.020)
		tw_flash.chain().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.052)

	# ── Parâmetros de trajetória ──────────────────────────────
	var dir: Vector2 = global_position - origem_impacto
	if dir.length() < 0.5:
		dir = Vector2(1.0 if randf() > 0.5 else -1.0, -0.06)
	dir = dir.normalized()

	var forca: float = clamp(intensidade, 0.90, 1.28)
	var t_forca: float = inverse_lerp(0.90, 1.65, forca)

	# Voo levemente maior que o original
	var lateral_base: float = lerp(12.0, deslocamento_empurrao_max_x * 1.12, t_forca)
	var frente_base: float  = lerp(9.0,  deslocamento_empurrao_max_y * 1.18, t_forca)
	var voo_base: float     = lerp(20.0, distancia_voo_max * 1.12, t_forca)

	var empurrao_x: float = dir.x * lateral_base
	var empurrao_y: float = -lerp(2.5, 8.0, t_forca)
	var deslizamento_x: float = dir.x * voo_base
	var deslizamento_y: float = frente_base

	if tipo_queda == "down_left":
		deslizamento_x = -abs(deslizamento_x)
	elif tipo_queda == "down_rt":
		deslizamento_x = abs(deslizamento_x)

	var lado_rot: float = sign(deslizamento_x)
	if lado_rot == 0.0:
		lado_rot = sign(dir.x) if dir.x != 0.0 else 1.0
	if tipo_queda == "down_left":
		lado_rot = -1.0
	elif tipo_queda == "down_rt":
		lado_rot = 1.0

	# Rotação levemente mais dramática + variação individual
	var rot_pico: float  = lado_rot * lerp(20.0, 40.0, t_forca)
	var rot_final: float = lado_rot * lerp(90.0, rotacao_max_queda, t_forca)
	rot_final += rand_range(-14.0, 14.0)   # cada pino cai diferente

	# Pitch — inclinação para frente (skew do sprite)
	var pitch_alvo: float = 0.0
	match tipo_queda:
		"strike":
			pitch_alvo = rand_range(-0.30, -0.18)
		"down_left", "down_rt":
			pitch_alvo = rand_range(-0.16, -0.06)

	# Squash no hit — acontece AQUI, depois do delay
	var squash_x: float = lerp(1.10, 1.18, t_forca)
	var squash_y: float = lerp(0.90, 0.82, t_forca)

	var base_pos: Vector2 = position
	var base_mod: Color   = Color(1, 1, 1, 1)
	if sprite != null:
		base_mod = sprite.modulate

	# ── Tween da queda ────────────────────────────────────────
	var tw: SceneTreeTween = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)

	# Squash imediato no momento do contato
	if sprite != null:
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "scale"),
			Vector2(escala_travada_queda.x * squash_x, escala_travada_queda.y * squash_y),
			0.032)

	# Fase 1 — empurrão explosivo
	tw.tween_property(self, Compat.prop(self, "position"), base_pos + Vector2(empurrao_x, empurrao_y), duracao_empurrao)

	if sprite != null:
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), rot_pico, duracao_empurrao)
		tw.parallel().tween_interval(duracao_empurrao)  # Godot 3: sem skew no Node2D
		tw.parallel().tween_property(sprite, "modulate", Color(1.08, 1.06, 1.04, 1.0), duracao_empurrao)
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "scale"), escala_travada_queda, duracao_empurrao + 0.035)

	# Fase 2 — tombo (QUART: desacelera suavemente até o chão)
	tw.set_trans(Tween.TRANS_QUART)
	tw.tween_property(self, Compat.prop(self, "position"), base_pos + Vector2(deslizamento_x, deslizamento_y), duracao_tombo)

	if sprite != null:
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), rot_final, duracao_tombo)
		tw.parallel().tween_interval(duracao_tombo)  # Godot 3: sem skew no Node2D
		tw.parallel().tween_property(sprite, "modulate", base_mod, duracao_tombo)

	tw.connect("finished", self, "_fim_do_tombo", [forca])


func _esconder_numero() -> void:
	if numero_label != null:
		numero_label.visible = false


func _fim_do_tombo(forca: float) -> void:
	fixar_tamanho_visual_derrubado()
	_aplicar_quique_no_tatame(forca)


func _aplicar_quique_no_tatame(forca: float = 1.0) -> void:
	if sprite == null:
		return
	if finalizando_queda:
		return

	finalizando_queda = true

	var base_rot_sprite: float = sprite.rotation_degrees
	var base_pos_no: Vector2 = position

	var intensidade: float = clamp(forca * intensidade_quique, 0.90, 1.55)
	var lado: float = 1.0

	match animacao_atual_nome:
		"down_left":
			lado = -1.0
		"down_rt":
			lado = 1.0
		_:
			lado = -1.0 if randf() < 0.5 else 1.0

	var qy: float = deslocamento_quique_y * intensidade
	var qx: float = deslocamento_quique_x * intensidade * lado
	var qr: float = rotacao_quique * intensidade * lado

	var tw: SceneTreeTween = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)

	if usar_quique_no_tatame:
		# Squash no chão antes de ricochetear
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "scale"),
			Vector2(escala_travada_queda.x * 1.15, escala_travada_queda.y * 0.86), 0.030)

		tw.tween_property(self, Compat.prop(self, "position"), base_pos_no + Vector2(qx, -qy * 0.38), 0.042)
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), base_rot_sprite + qr, 0.042)
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "scale"), escala_travada_queda, 0.055)

		tw.tween_property(self, Compat.prop(self, "position"), base_pos_no + Vector2(qx * 0.54, qy * 0.27), 0.080)
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), base_rot_sprite - qr * 0.40, 0.080)

		tw.tween_property(self, Compat.prop(self, "position"), base_pos_no + Vector2(qx * 0.17, -qy * 0.09), 0.055)
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), base_rot_sprite + qr * 0.15, 0.055)

		tw.tween_property(self, Compat.prop(self, "position"), base_pos_no, 0.088)
		tw.parallel().tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), base_rot_sprite, 0.088)
	else:
		tw.tween_interval(0.04)

	tw.connect("finished", self, "_fim_do_quique")


func _fim_do_quique() -> void:
	finalizando_queda = false
	_sumir_apos_queda()


func _sumir_apos_queda() -> void:
	if sumindo_apos_queda:
		return

	sumindo_apos_queda = true

	var tw = create_tween()
	tw.tween_interval(tempo_espera_apos_queda)

	if sprite != null:
		tw.tween_property(sprite, "modulate", Color(1, 1, 1, 0.0), tempo_fade_apos_queda)

	if numero_label != null:
		tw.parallel().tween_property(numero_label, "modulate", Color(1, 1, 1, 0.0), tempo_fade_apos_queda)


func sumir_apos_queda() -> void:
	_sumir_apos_queda()


func impacto_visual(intensidade: float = 1.0, origem_impacto: Vector2 = Vector2.ZERO) -> void:
	if sprite == null:
		return

	var ganho: float = clamp(intensidade, 0.92, 1.50)
	var base_mod: Color = sprite.modulate
	var base_rot: float = sprite.rotation_degrees
	var base_pos: Vector2 = sprite.position

	var lado: float = sign(global_position.x - origem_impacto.x)
	if lado == 0.0:
		lado = 1.0

	var dx: float = lado * lerp(1.2, 2.8, clamp((ganho - 0.9) / 0.6, 0.0, 1.0))
	var dy: float = -lerp(2.4, 4.6, clamp((ganho - 0.9) / 0.6, 0.0, 1.0))
	var rot: float = lado * lerp(2.0, 4.4, clamp((ganho - 0.9) / 0.6, 0.0, 1.0))

	var tw: SceneTreeTween = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, Compat.prop(sprite, "position"), base_pos + Vector2(dx, dy), 0.040)
	tw.parallel().tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), base_rot + rot, 0.045)
	tw.parallel().tween_property(sprite, "modulate", Color(1.14, 1.14, 1.14, 1.0), 0.040)

	var tw2: SceneTreeTween = create_tween()
	tw2.tween_property(self, "escala_fx", 1.04, 0.035)
	tw2.tween_property(self, "escala_fx", 1.0, 0.070)

	tw.tween_property(sprite, Compat.prop(sprite, "position"), base_pos, 0.065)
	tw.parallel().tween_property(sprite, "modulate", base_mod, 0.065)


func abalo_lateral(intensidade: float = 1.0) -> void:
	if derrubado or sprite == null:
		return

	var dir_x: float = 1.0 if randf() > 0.5 else -1.0
	var mag: float = clamp(intensidade * 0.35, 0.0, limiar_queda - 0.05)
	receber_forca(Vector2(dir_x, -0.2), mag, global_position + Vector2(-dir_x * 60.0, 0.0))

	var base_pos: Vector2 = sprite.position
	var base_rot: float = sprite.rotation_degrees
	var f: float = clamp(intensidade, 0.7, 1.25)

	var tw: SceneTreeTween = create_tween()
	tw.tween_property(sprite, Compat.prop(sprite, "position"), base_pos + Vector2(rand_range(-1.6, 1.6) * f, 0), 0.018)
	tw.parallel().tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), base_rot + rand_range(-2.8, 2.8) * f, 0.018)
	tw.tween_property(sprite, Compat.prop(sprite, "position"), base_pos + Vector2(rand_range(-0.8, 0.8) * f, 0), 0.018)
	tw.parallel().tween_property(sprite, Compat.prop(sprite, "rotation_degrees"), base_rot, 0.018)
	tw.tween_property(sprite, Compat.prop(sprite, "position"), base_pos, 0.024)

	var brilho: Color = sprite.modulate
	var tw2: SceneTreeTween = create_tween()
	tw2.tween_property(sprite, "modulate", Color(1.08, 1.08, 1.08, sprite.modulate.a), 0.02)
	tw2.tween_property(sprite, "modulate", brilho, 0.05)


func fixar_tamanho_visual_derrubado() -> void:
	if sprite == null:
		return

	var escala_base_queda: Vector2 = escala_travada_queda
	if escala_base_queda == Vector2.ZERO:
		escala_base_queda = sprite.scale

	sprite.scale = escala_base_queda
	ajustar_ancora_visual(ref_idle, escala_base_queda.y)
	atualizar_posicao_numero(ref_idle, escala_base_queda.y)


func destacar_acerto() -> void:
	if numero_label == null:
		return

	var brilho = numero_label.modulate
	var escala = numero_label.rect_scale

	var tw = create_tween()
	tw.tween_property(numero_label, "rect_scale", escala * 1.12, 0.05)
	tw.parallel().tween_property(numero_label, "modulate", Color(1.18, 1.18, 0.70, 1.0), 0.04)
	tw.tween_property(numero_label, "rect_scale", escala, 0.10)
	tw.parallel().tween_property(numero_label, "modulate", brilho, 0.10)


func resetar() -> void:
	derrubado = false
	hover = false
	animacao_atual_nome = "idle"
	escala_fx = 1.0
	sumindo_apos_queda = false
	finalizando_queda = false
	em_quase_queda = false
	forca_acumulada = Vector2.ZERO
	position = posicao_base_local
	rotation_degrees = 0.0
	modulate = Color(1, 1, 1, 1)
	travar_escala_na_queda = false
	escala_travada_queda = Vector2.ZERO

	if sprite != null:
		sprite.visible = true
		sprite.material = null
		pass  # G3 (filtro na importação): sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.modulate = Color(1, 1, 1, 1)
		sprite.rotation_degrees = 0.0
		pass  # Godot 3: sem skew no Node2D
		sprite.position = Vector2.ZERO
		sprite.offset = Vector2.ZERO
		sprite.scale = Vector2.ONE

	if numero_label != null:
		numero_label.modulate = Color(1, 1, 1, 1)
		numero_label.rect_scale = Vector2.ONE
		numero_label.visible = true

	if sprite != null and sprite.frames != null:
		if sprite.frames.has_animation("idle"):
			sprite.play("idle")
			sprite.frame = 0
		else:
			var nomes = sprite.frames.get_animation_names()
			if nomes.size() > 0:
				sprite.play(nomes[0])
				sprite.frame = 0

	atualizar_tamanho_base()


func _on_frame_changed() -> void:
	if derrubado:
		return

	atualizar_tamanho_base(1.015 if hover and not derrubado else 1.0)


func aplicar_shader_borda_suave() -> void:
	if sprite == null:
		return

	sprite.material = null
	# Os frames de 200 a 1024 px sao reduzidos na pista; mipmaps
	# evitam serrilhado e cintilacao nas bordas dos pinos.
	pass  # G3 (filtro na importação): sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func forcar_queda_imediata(animacao: String, intensidade: float = 3.0, origem_impacto: Vector2 = Vector2.ZERO) -> void:
	if derrubado:
		return

	em_quase_queda = false
	finalizando_queda = false
	empurrando = false
	forca_acumulada = Vector2.ZERO
	velocidade_plano = Vector2.ZERO
	velocidade_rotacional = 0.0

	if sprite != null:
		sprite.rotation_degrees = 0.0
		pass  # Godot 3: sem skew no Node2D
		sprite.modulate = Color(1, 1, 1, 1)

	cair_voando(animacao, intensidade, origem_impacto, 0.0)


func _on_anim_finished() -> void:
	if derrubado and sprite != null and sprite.animation != "idle":
		var total = sprite.frames.get_frame_count(sprite.animation)
		if total > 0:
			sprite.stop()
			sprite.frame = total - 1
			escala_fx = 1.0
			fixar_tamanho_visual_derrubado()
			if not finalizando_queda:
				_aplicar_quique_no_tatame(1.0)
