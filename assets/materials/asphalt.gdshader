shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_size_meters : hint_range(0.5, 8.0) = 3.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.25;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The circuit is flat; world-space X/Z texture coordinates have a fixed tangent basis.
	TANGENT = vec3(1.0, 0.0, 0.0);
	BINORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 uv = world_position.xz / tile_size_meters;
	vec2 detail_uv = uv * 1.137 + vec2(0.371, 0.619);
	float patches = 0.5 + 0.5 * sin(world_position.x * 0.17) * sin(world_position.z * 0.11);
	float damp = wetness * smoothstep(0.25, 0.85, patches);
	// Two incommensurate scales soften the repeating crack grid without extra texture assets.
	ALBEDO = mix(texture(albedo_texture, uv).rgb, texture(albedo_texture, detail_uv).rgb, 0.45) * mix(0.83, 0.60, damp);
	vec3 fine_normal = normalize(mix(texture(normal_texture, uv).rgb * 2.0 - 1.0,
		texture(normal_texture, detail_uv).rgb * 2.0 - 1.0, 0.45));
	NORMAL_MAP = fine_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = mix(0.40, 0.28, damp);
	float surface_roughness = mix(texture(roughness_texture, uv).r, texture(roughness_texture, detail_uv).r, 0.45);
	ROUGHNESS = mix(clamp(surface_roughness, 0.45, 0.95), 0.24, damp);
	METALLIC = 0.0;
}
