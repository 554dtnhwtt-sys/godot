shader_type canvas_item;
// Dimman: mjuka, drivande kanter ovanpå en låg-upplöst täckningsbild.

uniform vec2 grid = vec2(180.0, 120.0);

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
	float a = texture(TEXTURE, UV).a;
	vec2 p = UV * grid * 0.35 + vec2(TIME * 0.05, TIME * 0.02);
	float n = noise(p) * 0.5 + noise(p * 2.3 + 7.0) * 0.3 + noise(p * 5.1 + 3.0) * 0.2;
	float fog = smoothstep(0.3, 0.7, a + (n - 0.5) * 0.55);
	vec3 col = mix(vec3(0.72, 0.8, 0.84), vec3(0.93, 0.95, 0.96), n);
	COLOR = vec4(col, fog * 0.97);
}
