shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.22, 0.17, 0.14, 1.0);
uniform float brick_pattern : hint_range(0.0, 1.0) = 1.0;
varying vec3 world_position;
varying vec3 world_normal;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
void fragment() {
	vec2 wall = abs(world_normal.x) > abs(world_normal.z) ? world_position.zy : world_position.xy;
	if (abs(world_normal.y) > 0.8) { wall = world_position.xz; }
	float row = floor(wall.y / 0.24);
	vec2 grid = vec2(wall.x / 0.62 + mod(row, 2.0) * 0.5, wall.y / 0.24);
	vec2 cell = fract(grid);
	vec2 edge = min(cell, 1.0 - cell);
	vec2 aa = max(fwidth(grid), vec2(0.002));
	float face = smoothstep(0.018, 0.018 + aa.x, edge.x) * smoothstep(0.035, 0.035 + aa.y, edge.y);
	float variation = hash21(floor(grid));
	float grain = hash21(floor(wall * 65.0));
	float streak = 0.92 + 0.08 * noise2(wall * vec2(0.35, 0.12));
	float dirt = mix(0.64, 1.0, smoothstep(0.1, 3.2, world_position.y));
	vec3 brick = base_color.rgb * (0.80 + variation * 0.30);
	vec3 mortar = base_color.rgb * 0.80 + vec3(0.012);
	vec3 masonry = mix(mortar, brick, face);
	vec3 plaster = base_color.rgb * streak;
	ALBEDO = mix(plaster, masonry, brick_pattern) * dirt * (0.94 + grain * 0.08);
	ROUGHNESS = 0.88;
	METALLIC = 0.0;
}
