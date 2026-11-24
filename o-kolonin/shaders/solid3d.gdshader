shader_type spatial;
// 3D-modeller med färg per hörn. Allt under vattenytan (y < waterline) syns inte,
// så skrov ligger i vattnet och sjunkande skepp försvinner ned i havet.
// sway > 0 får palmer och träd att vaja i vinden (mer ju högre upp).
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform float waterline = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float glow = 0.0;
uniform float sway = 0.0;
uniform vec2 wind = vec2(1.0, 0.0);

varying vec3 wpos;

void vertex() {
	if (sway > 0.0) {
		float h = max(VERTEX.y, 0.0);
		vec3 origin = MODEL_MATRIX[3].xyz;
		float s = sin(TIME * 1.4 + origin.x * 0.013 + origin.z * 0.011) * 0.6 + 0.4;
		vec3 push = vec3(wind.x, 0.0, wind.y) * s * sway * h * h * 0.01;
		VERTEX += (inverse(mat3(MODEL_MATRIX)) * push);
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (wpos.y < waterline) {
		discard;
	}
	// Hörnfärgerna omvandlas redan till linjärt ljus av motorn.
	vec3 c = COLOR.rgb * tint.rgb;
	ALBEDO = c;
	EMISSION = c * glow;
	ROUGHNESS = 0.9;
}
