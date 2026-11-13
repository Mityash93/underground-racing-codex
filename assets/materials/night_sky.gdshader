shader_type sky;

uniform sampler2D reflection_panorama : filter_linear_mipmap, repeat_enable;
uniform float reflection_energy : hint_range(0.0, 2.0) = 0.28;

void sky() {
	if (AT_CUBEMAP_PASS) {
		vec2 uv = vec2(atan(EYEDIR.x, EYEDIR.z) / (2.0 * PI) + 0.5,
			acos(clamp(EYEDIR.y, -1.0, 1.0)) / PI);
		COLOR = texture(reflection_panorama, uv).rgb * reflection_energy;
	} else {
		// Preserve the original skyline rather than putting a photographed street behind the track.
		float elevation = pow(clamp(abs(EYEDIR.y), 0.0, 1.0), 0.45);
		vec3 horizon = vec3(0.006, 0.012, 0.024);
		vec3 pole = EYEDIR.y >= 0.0 ? vec3(0.001, 0.003, 0.008) : vec3(0.002, 0.005, 0.010);
		COLOR = mix(horizon, pole, elevation);
	}
}
