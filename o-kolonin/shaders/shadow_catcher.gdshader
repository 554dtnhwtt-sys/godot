shader_type spatial;
// Osynlig yta på havs- och marknivå som bara visar skuggorna från 3D-modellerna,
// så att skepp och städer kastar riktiga skuggor på den målade världen under.
render_mode shadow_to_opacity, blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled;

uniform float strength = 0.38;
uniform vec3 ambient_linear = vec3(0.5);

void fragment() {
	ALBEDO = vec3(1.0);
	// Släck omgivningsljuset så att skuggan blir mörk (ljusa delar blir genomskinliga ändå).
	EMISSION = -ambient_linear;
	ALPHA = strength;
}
