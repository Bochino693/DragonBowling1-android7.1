// O BRILHO QUE PASSA PELA PLACA "Lazer & Sport" na abertura.
//
// No Godot 4 era um polígono somado por cima, recortado pela placa
// (clip_children). O Godot 3 não recorta filho pela imagem do pai: aqui a
// faixa inclinada é desenhada pela própria placa, só onde ela tem cor.
// Medidas em pixels da imagem (centro = 0), iguais às do polígono antigo.
shader_type canvas_item;
uniform float brilho_x = -2000.0;
uniform vec2 tamanho = vec2(1280.0, 376.0);
uniform float alto = 451.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = (UV - vec2(0.5)) * tamanho;
	float t = clamp((p.y + alto) / (2.0 * alto), 0.0, 1.0);
	float esq = brilho_x + mix(-60.0, -100.0, t);
	float dir = brilho_x + mix(20.0, -20.0, t);
	float dentro = step(esq, p.x) * step(p.x, dir);
	c.rgb += vec3(0.55) * dentro * c.a;
	COLOR = c;
}
