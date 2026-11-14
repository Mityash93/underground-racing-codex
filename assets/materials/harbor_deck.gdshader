shader_type spatial;
render_mode cull_disabled;
uniform bool metric_uv = false;
varying vec2 plank_uv;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	// Local box coordinates + scale keep boards aligned along each quay segment.
	plank_uv = metric_uv ? UV : VERTEX.xz * vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
}
void fragment() {
	vec2 grid = plank_uv / vec2(0.18, 2.4);
	vec2 edge = min(fract(grid), 1.0 - fract(grid));
	vec2 aa = max(fwidth(grid), vec2(0.002));
	float board = smoothstep(0.014, 0.014 + aa.x, edge.x) * smoothstep(0.004, 0.004 + aa.y, edge.y);
	float grain = 0.92 + 0.08 * sin(plank_uv.y * 140.0 + sin(plank_uv.x * 35.0) * 3.0);
	float variation = hash21(floor(grid));
	ALBEDO = mix(vec3(0.025), vec3(0.19, 0.155, 0.11) * (0.82 + variation * 0.32), board) * grain;
	ROUGHNESS = 0.85;
}
