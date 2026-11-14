shader_type spatial;
render_mode cull_disabled, alpha_to_coverage;
varying vec3 leaf_tint;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	leaf_tint = COLOR.rgb;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.x += sin(TIME * 0.8 + world.x * 0.11 + world.z * 0.08) * 0.035;
}
void fragment() {
	vec2 cells = UV * vec2(8.0, 7.0);
	vec2 id = floor(cells);
	float random = hash21(id);
	vec2 p = fract(cells) - vec2(0.5);
	p -= vec2(random - 0.5, hash21(id + 12.4) - 0.5) * 0.26;
	float angle = random * 6.28;
	p = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * p;
	float leaf = 1.0 - smoothstep(0.36, 0.43, length(p * vec2(0.78, 1.55)));
	float cluster = 1.0 - smoothstep(0.68, 1.03, length((UV * 2.0 - 1.0) * vec2(1.0, 0.9)));
	ALPHA = leaf * cluster;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 dark = vec3(0.035, 0.073, 0.044);
	vec3 light = vec3(0.070, 0.115, 0.060);
	ALBEDO = mix(dark, light, random) * leaf_tint;
	ROUGHNESS = 0.9;
}
