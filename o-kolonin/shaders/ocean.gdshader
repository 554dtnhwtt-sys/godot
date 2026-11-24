shader_type canvas_item;
// Karibiskt hav: djupa och turkosa nyanser, solkatter (kaustik) och glitter.

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Kaustik: ljusa nätmönster som solljus gör på grunt vatten.
float caustic(vec2 p, float t) {
	vec2 q = p + vec2(fbm(p + t * 0.1), fbm(p - t * 0.08)) * 2.0;
	float a = abs(sin(q.x * 1.6 + t * 0.6) + sin(q.y * 1.7 - t * 0.5));
	return pow(clamp(1.0 - a * 0.5, 0.0, 1.0), 3.0);
}

void fragment() {
	vec2 p = UV * size;
	float t = TIME;
	float big = fbm(p * 0.0009 + vec2(t * 0.006, t * 0.003));
	vec3 deep = vec3(0.03, 0.31, 0.48);
	vec3 mid = vec3(0.04, 0.47, 0.6);
	vec3 turq = vec3(0.1, 0.62, 0.68);
	vec3 col = mix(deep, mid, smoothstep(0.25, 0.6, big));
	col = mix(col, turq, smoothstep(0.55, 0.85, big) * 0.6);
	// Mjuka dyningar
	float swell = sin(p.x * 0.004 + p.y * 0.002 + t * 0.7 + fbm(p * 0.002) * 4.0);
	col += vec3(0.02, 0.05, 0.06) * swell;
	// Kaustik
	float c = caustic(p * 0.006, t * 0.7);
	col += vec3(0.55, 0.9, 0.95) * c * 0.045;
	// Små vågor som glittrar i solen
	float g = noise(p * 0.09 + vec2(t * 0.7, -t * 0.5)) * noise(p * 0.05 - vec2(t * 0.3, t * 0.2));
	col += vec3(1.0, 0.98, 0.9) * smoothstep(0.7, 0.86, g) * 0.18;
	// Mörkare mot världens kant
	vec2 e = min(UV, 1.0 - UV);
	float edge = smoothstep(0.0, 0.1, min(e.x, e.y));
	col *= mix(0.6, 1.0, edge);
	COLOR = vec4(col, 1.0);
}
