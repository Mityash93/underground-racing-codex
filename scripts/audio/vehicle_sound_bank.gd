class_name VehicleSoundBank
extends RefCounted
## Small original PCM effects, shared by all cars. No external samples.
const RATE := 22050
static var _cache: Dictionary = {}

static func get_sound(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var looping := kind in ["nitro_loop", "tires"]
	var duration := 1.0 if looping else (0.28 if kind == "nitro_start" else 0.36)
	var count := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 73819 + kind.hash()
	var filtered := 0.0
	var chirp_phase := 0.0
	for i in count:
		var time := float(i) / RATE
		var progress := float(i) / (count - 1)
		var noise := rng.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.22)
		var wave := 0.0
		match kind:
			"nitro_loop":
				wave = (noise - filtered) * 0.30 + filtered * 0.18
				wave *= 0.87 + 0.13 * sin(TAU * 17.0 * time)
			"nitro_start":
				chirp_phase += TAU * (180.0 + progress * 650.0) / RATE
				wave = (filtered * 0.9 + sin(chirp_phase) * 0.12) * pow(sin(PI * progress), 1.2)
			"tires":
				var phase := TAU * 660.0 * time + sin(TAU * 11.0 * time) * 0.35
				wave = sin(phase) * 0.22 + sin(phase * 2.0) * 0.08 + filtered * 0.28
				wave *= 0.85 + 0.15 * sin(TAU * 19.0 * time)
			"impact":
				wave = (sin(TAU * 72.0 * time) * 0.65 + filtered * 1.3) * exp(-time * 20.0)
		# Short edge ramps avoid DC clicks on both loops and one-shot starts/stops.
		var edge := minf(1.0, minf(float(i) / 64.0, float(count - 1 - i) / 64.0))
		data.encode_s16(i * 2, roundi(clampf(wave * edge, -0.95, 0.95) * 32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
	sound.loop_end = count
	sound.data = data
	_cache[kind] = sound
	return sound
