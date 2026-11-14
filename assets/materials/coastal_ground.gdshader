shader_type spatial;
uniform sampler2D coast_mask : filter_linear, repeat_disable;
varying vec2 world_xz;
void vertex() { world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	if (texture(coast_mask, world_xz / 1300.0 + vec2(0.5)).r > 0.5) { discard; }
	ALBEDO = vec3(0.006, 0.012, 0.020);
	ROUGHNESS = 0.95;
}
