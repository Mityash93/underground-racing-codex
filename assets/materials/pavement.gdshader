shader_type spatial;
render_mode cull_disabled;
uniform vec4 stone_color : source_color = vec4(0.31, 0.32, 0.31, 1.0);
varying vec2 world_xz;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 grid = world_xz / vec2(0.60, 0.45);
	grid.x += mod(floor(grid.y), 2.0) * 0.5;
	vec2 cell = fract(grid);
	vec2 edge = min(cell, 1.0 - cell);
	vec2 aa = max(fwidth(grid), vec2(0.002));
	float tile = smoothstep(0.012, 0.012 + aa.x, edge.x) * smoothstep(0.016, 0.016 + aa.y, edge.y);
	float variation = hash21(floor(grid));
	float grain = hash21(floor(world_xz * 80.0));
	vec3 stone = stone_color.rgb * (0.84 + variation * 0.26);
	ALBEDO = mix(stone_color.rgb * 0.48, stone, tile) * (0.94 + grain * 0.10);
	ROUGHNESS = 0.84 + grain * 0.12;
	METALLIC = 0.0;
}
