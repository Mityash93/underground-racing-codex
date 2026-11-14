shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float shape = length(p) + (noise2(UV * 7.0) - 0.5) * 0.4;
	ALBEDO = vec3(0.018, 0.024, 0.030);
	ROUGHNESS = 0.19;
	METALLIC = 0.03;
	ALPHA = (1.0 - smoothstep(0.55, 0.98, shape)) * 0.48;
}
