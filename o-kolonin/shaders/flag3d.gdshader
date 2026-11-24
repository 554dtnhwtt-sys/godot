shader_type spatial;
// Flagga som vajar. UV.x = 0 vid stången, 1 vid flaggans ände.
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 color_a : source_color = vec4(0.2, 0.3, 0.6, 1.0);
uniform vec4 color_b : source_color = vec4(0.9, 0.8, 0.3, 1.0);

void vertex() {
	VERTEX.z += sin(TIME * 6.0 - UV.x * 7.0) * UV.x * 2.2;
	VERTEX.y += sin(TIME * 4.0 - UV.x * 5.0) * UV.x * 0.6;
}

void fragment() {
	float stripe = step(0.38, UV.y) * step(UV.y, 0.62);
	ALBEDO = mix(color_a.rgb, color_b.rgb, stripe);
	ROUGHNESS = 1.0;
}
