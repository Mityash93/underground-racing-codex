shader_type spatial;
render_mode cull_disabled;
varying vec2 world_xz;
void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	float ripples = sin(world_xz.x * 1.7 + world_xz.y * 2.3 + TIME * 1.2);
	float crest = pow(max(0.0, ripples), 12.0);
	ALBEDO = vec3(0.006, 0.025, 0.045) + crest * vec3(0.002, 0.005, 0.007);
	EMISSION = vec3(0.004, 0.014, 0.025) + crest * 0.004;
	ROUGHNESS = 0.42;
	SPECULAR = 0.12;
	METALLIC = 0.0;
}
