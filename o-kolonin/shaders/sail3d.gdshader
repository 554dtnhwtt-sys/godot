shader_type spatial;
// Segel som buktar och fladdrar i vinden. NORMAL pekar åt det håll seglet buktar;
// side vänder skonare- och slupsegel efter vindens sida.
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled, shadows_disabled;

uniform vec4 sail_color : source_color = vec4(0.96, 0.93, 0.84, 1.0);
uniform float billow = 6.0;
uniform float side = 1.0;
uniform float glow = 0.0;
uniform float waterline = 0.0;

varying vec3 wpos;

void vertex() {
	float b = sin(UV.x * PI) * (0.3 + 0.7 * sin(UV.y * PI));
	float flutter = 1.0 + 0.06 * sin(TIME * 3.1 + UV.x * 5.0 + UV.y * 3.0);
	vec3 dir = vec3(NORMAL.x, 0.0, NORMAL.z * side);
	VERTEX += dir * b * billow * flutter;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (wpos.y < waterline) {
		discard;
	}
	float shade = mix(0.82, 1.0, UV.y) * (0.92 + 0.08 * sin(UV.x * 40.0));
	ALBEDO = sail_color.rgb * shade;
	EMISSION = sail_color.rgb * (glow + 0.1);
	ROUGHNESS = 1.0;
}
