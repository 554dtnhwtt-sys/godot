shader_type canvas_item;
// Skepp: färgar om de ljusa seglen (t.ex. svarta segel för pirater).

uniform vec4 sail_color : source_color = vec4(1.0);
uniform float tint_strength = 0.0;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float mx = max(t.r, max(t.g, t.b));
	float mn = min(t.r, min(t.g, t.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float sail = smoothstep(0.6, 0.78, mx) * (1.0 - smoothstep(0.16, 0.32, sat));
	vec3 tinted = t.rgb * sail_color.rgb * mix(1.0, 1.15, step(0.5, sail_color.r));
	vec3 c = mix(t.rgb, tinted, sail * tint_strength);
	COLOR = vec4(c, t.a) * vcol;
}
