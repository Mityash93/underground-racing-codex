shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void vertex() {
	// Camera-facing quads, no texture downloads and no lights/shadows.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}
void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.48, 0.52, 0.58);
	ALPHA = (1.0 - smoothstep(0.05, 1.0, radius)) * 0.12 * COLOR.a;
}
