shader_type canvas_item;
// 角色轮廓光（`03_美术/16` §3.2）：在不透明边缘外描一圈，阿针青、阿绫品红。
// width 按源稿像素算：512 源稿缩到 128 显示是 4 倍，8 px ≈ 屏幕 2 px。
// modulate 已在 COLOR 里，只乘到角色本体，不乘到轮廓。

uniform vec4 outline_color : source_color = vec4(0.247, 0.878, 0.816, 1.0);
uniform float width = 8.0;

void fragment() {
	vec4 tint = COLOR;
	vec4 c = texture(TEXTURE, UV);
	float edge = 0.0;
	if (width > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE * width;
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.7853982;
			edge = max(edge, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a);
		}
	}
	float rim_a = outline_color.a * step(0.5, edge) * (1.0 - c.a);
	float a = c.a + rim_a;
	vec3 rgb = (c.rgb * tint.rgb * c.a + outline_color.rgb * rim_a) / max(a, 0.0001);
	COLOR = vec4(rgb, a * tint.a);
}
