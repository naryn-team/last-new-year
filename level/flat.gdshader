shader_type spatial;
// Плоское (low-poly) затенение: каждая грань одного цвета, без сглаживания.

uniform vec4 albedo : source_color = vec4(0.1, 0.25, 0.15, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
}
