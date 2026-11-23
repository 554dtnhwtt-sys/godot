shader_type canvas_item;
// Karibiskt hav: turkosa nyanser, långsamma strömmar och glittrande vågtoppar.

uniform vec2 size = vec2(9200.0, 6800.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * size;
	float t = TIME;
	float big = noise(p * 0.0015 + vec2(t * 0.01, t * 0.004));
	float mid = noise(p * 0.006 + vec2(-t * 0.03, t * 0.02));
	vec3 deep = vec3(0.02, 0.36, 0.52);
	vec3 turq = vec3(0.04, 0.58, 0.66);
	vec3 col = mix(deep, turq, clamp(big * 0.8 + mid * 0.3, 0.0, 1.0));
	// Vågor
	float w1 = sin(p.x * 0.035 + p.y * 0.012 + t * 1.3 + noise(p * 0.01) * 6.0);
	float w2 = sin(p.x * -0.018 + p.y * 0.03 + t * 1.0 + noise(p * 0.013 + 5.0) * 5.0);
	float crest = smoothstep(0.82, 1.0, w1 * 0.6 + w2 * 0.6);
	col += vec3(0.55, 0.9, 1.0) * crest * 0.16;
	// Glitter
	float g = noise(p * 0.08 + vec2(t * 0.6, -t * 0.4));
	col += vec3(1.0) * smoothstep(0.93, 1.0, g) * 0.35;
	// Kanten av världen mörknar
	vec2 e = min(UV, 1.0 - UV);
	float edge = smoothstep(0.0, 0.08, min(e.x, e.y));
	col *= mix(0.55, 1.0, edge);
	COLOR = vec4(col, 1.0);
}
