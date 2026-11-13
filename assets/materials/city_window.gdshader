shader_type spatial;
render_mode cull_disabled;
uniform vec4 room_tint : source_color = vec4(0.72, 0.53, 0.31, 1.0);
uniform float lit = 1.0;
varying vec3 eye_local;
varying float room_seed;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	eye_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	eye_local.z *= length(MODEL_MATRIX[2].xyz) / max(length(MODEL_MATRIX[0].xyz), 0.1);
	eye_local *= 2.0;
	room_seed = hash21(MODEL_MATRIX[3].xz);
}
void fragment() {
	vec2 uv = UV;
	vec3 origin = vec3(uv * 2.0 - 1.0, 1.0);
	vec3 ray = normalize(vec3(origin.xy - eye_local.xy, -max(abs(eye_local.z), 0.5)));
	vec3 ray_sign = sign(ray + vec3(0.000001));
	vec3 inv_ray = ray_sign / max(abs(ray), vec3(0.0001));
	vec3 times = (ray_sign - origin) * inv_ray;
	float travel = min(min(times.x, times.y), times.z);
	vec3 hit = origin + ray * travel;
	float back = step(times.z, min(times.x, times.y));
	float floor_wall = step(times.y, min(times.x, times.z));
	vec3 room = room_tint.rgb * mix(0.34, 0.62, back);
	room *= mix(1.0, 0.48 + 0.42 * step(0.0, hit.y), floor_wall);
	float cabinet = back * step(0.18, hit.x) * step(hit.y, -0.22);
	room *= 1.0 - cabinet * 0.65;
	float curtain = max(1.0 - smoothstep(0.06, 0.17, uv.x), smoothstep(0.83, 0.94, uv.x));
	float folds = 0.75 + 0.25 * sin(uv.x * 95.0);
	room = mix(room, room_tint.rgb * folds * 0.47, curtain);
	float blinds = step(0.7, room_seed) * step(uv.y, 0.6);
	float slat = smoothstep(0.30, 0.48, fract(uv.y * 14.0));
	room = mix(room, room_tint.rgb * (0.20 + slat * 0.30), blinds * 0.8);
	float edge = smoothstep(0.0, 0.035, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	room *= mix(0.25, 1.0, edge);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	vec3 reflection = vec3(0.035, 0.070, 0.11);
	ALBEDO = mix(room * mix(0.09, 1.0, lit), reflection, 0.18 + fresnel * 0.42);
	EMISSION = room * lit * 0.28;
	ROUGHNESS = 0.29;
	METALLIC = 0.12;
}
