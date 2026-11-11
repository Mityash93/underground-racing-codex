shader_type spatial;
render_mode cull_disabled;

varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 grid = floor(world_position.xz * 14.0);
	float grain = fract(sin(dot(grid, vec2(127.1, 311.7))) * 43758.5453);
	float patch = sin(world_position.x * 0.21) * sin(world_position.z * 0.13);
	ALBEDO = vec3(0.105, 0.13, 0.16) * (0.83 + grain * 0.25 + patch * 0.08);
	ROUGHNESS = 0.52 + grain * 0.15;
	METALLIC = 0.18;
}
