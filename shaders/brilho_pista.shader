// BRILHO DA PISTA: canaletas azuis subindo e dourado pulsando.
// As máscaras vêm prontas em sprites/pista_mascara.png.
//
// Godot 3 / Mali-450: a conta do pixel é feita em 16 bits. `TIME` cresce
// sem parar e, depois de alguns minutos, `sin(TIME * x)` anda aos saltos.
// Por isso as FASES vêm prontas do GDScript (Compat.avancar_brilho), já
// reduzidas a uma volta: f_sobe em [0,1), f_pulso e f_ouro em [0, 2*PI).
shader_type canvas_item;
uniform sampler2D mascara;
uniform float intensidade : hint_range(0.0, 2.0) = 0.55;
uniform float velocidade : hint_range(0.0, 5.0) = 1.2;
uniform float erro_forca : hint_range(0.0, 1.0) = 0.0;
uniform float frenesi = 0.0;
uniform vec3 cor_canaleta = vec3(0.0, 0.95, 1.0);
uniform float f_sobe = 0.0;
uniform float f_pulso = 0.0;
uniform float f_ouro = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 m = texture(mascara, UV).rg;
	COLOR = tex;
	// Longe das canaletas e do dourado (a maior parte da tela) não há luz
	// para animar: o pixel sai direto, sem a conta do brilho.
	if (m.r + m.g >= 0.004) {
		float mascara_c = m.r;
		float luz_subindo = fract(UV.y * 1.5 - f_sobe);
		float pulso_canaleta = smoothstep(0.0, 0.18, luz_subindo) * (1.0 - smoothstep(0.18, 0.55, luz_subindo));
		float pulso_global = 0.70 + 0.30 * sin(f_pulso + UV.y * 12.0 + UV.x * 5.0);
		float pulso_gold = pulso_global * (0.55 + 0.45 * sin(f_ouro + UV.x * 18.0));
		float brilho_canaleta = mascara_c * pulso_canaleta * intensidade * (1.0 + frenesi);
		float brilho_gold = m.g * pulso_gold * intensidade * 0.45 * (1.0 - erro_forca);
		vec3 cor_base = tex.rgb;
		cor_base.g *= 1.0 - (mascara_c * erro_forca * 0.65);
		cor_base.b *= 1.0 - (mascara_c * erro_forca * 0.85);
		vec3 luz_normal = cor_canaleta * brilho_canaleta + vec3(1.0, 0.88, 0.30) * brilho_gold;
		vec3 luz_erro = vec3(1.0, 0.0, 0.0) * (brilho_canaleta * 2.2 + mascara_c * 0.10);
		COLOR = vec4(cor_base + mix(luz_normal, luz_erro, erro_forca), tex.a);
	}
}
