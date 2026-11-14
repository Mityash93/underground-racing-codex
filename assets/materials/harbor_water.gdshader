shader_type spatial;
render_mode cull_disabled, ambient_light_disabled;
varying vec2 world_xz;
void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	TANGENT = vec3(1.0, 0.0, 0.0);
	BINORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	float a = world_xz.x * 1.25 + world_xz.y * 0.65 + TIME * 0.7;
	float b = world_xz.x * -0.75 + world_xz.y * 1.5 + TIME * 0.94;
	float c = world_xz.x * 3.4 - world_xz.y * 2.3 + TIME * 1.3;
	vec2 slope = cos(a) * vec2(1.25, 0.65) * 0.045 + cos(b) * vec2(-0.75, 1.5) * 0.028 + cos(c) * vec2(3.4, -2.3) * 0.008;
	NORMAL_MAP = normalize(vec3(-slope.x, -slope.y, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.65;
	ALBEDO = vec3(0.007, 0.019, 0.023);
	// The street HDR panorama is suitable for cars, but paints open sea orange.
	// Keep direct moon/quay-light specular, with a restrained night-water floor.
	EMISSION = vec3(0.002, 0.006, 0.009);
	ROUGHNESS = 0.29 + 0.025 * sin(a + b);
	SPECULAR = 0.25;
	METALLIC = 0.0;
}
