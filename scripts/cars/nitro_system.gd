class_name NitroSystem
extends RefCounted
## Normalized reservoir; an empty tank must be released before reuse.
var charge := 1.0
var active := false
var blend := 0.0
var exhausted := false
var _recharge_delay := 0.0

func update(delta: float, wanted: bool, eligible: bool, running: bool, tuning: CarTuning) -> void:
	if not running:
		stop()
		return
	if not wanted:
		exhausted = false
	active = wanted and eligible and not exhausted and charge > 0.0
	if active:
		charge = maxf(0.0, charge - delta / maxf(tuning.nitro_duration, 0.1))
		_recharge_delay = tuning.nitro_recharge_delay
		if charge <= 0.0:
			exhausted = true
			active = false
	else:
		_recharge_delay = maxf(0.0, _recharge_delay - delta)
		if not wanted and _recharge_delay <= 0.0:
			charge = minf(1.0, charge + tuning.nitro_recharge_rate * delta)
	blend = move_toward(blend, 1.0 if active else 0.0, delta * (4.0 if active else 3.0))

func stop() -> void:
	active = false
	blend = 0.0

func reset() -> void:
	charge = 1.0
	exhausted = false
	_recharge_delay = 0.0
	stop()
