class_name FireSites
extends RefCounted
## Burning kill sites (art stretch, "wrecks that burn after a kill"): every kill leaves a fire that flickers and
## smokes for BURN_SECONDS, fed into the pooled BurstSystem (small fireball flipbooks that end in smoke, one long
## ground glow) plus a low-priority pooled light, so it costs no new draw calls or nodes. How many burn at once
## follows the tier; the oldest goes out first. Visual only: a site is just where FxWorld.explosion(big) happened.
## (A wreck MODEL left behind needs rules to keep the dead unit's transform: see streams/archive/round2/art.md requests.)

const BURN_SECONDS := 30.0
const FLAME_EVERY := 0.25
const PER_TIER := {FxQuality.Tier.LOW: 3, FxQuality.Tier.MEDIUM: 6, FxQuality.Tier.HIGH: 10}

## [{position: Vector3, start: float, next: float}]
var sites: Array = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 97


func ignite(position: Vector3, now: float, bursts: BurstSystem) -> void:
	sites.append({"position": position, "start": now, "next": now + 0.6})
	while sites.size() > int(PER_TIER[FxQuality.tier()]):
		sites.pop_front()
	bursts.spawn(BurstSystem.Kind.GROUND_GLOW, position, 7.0, BURN_SECONDS, Color(0.6, 0.22, 0.05), now)


func update(now: float, bursts: BurstSystem, lights: LightPool) -> void:
	for i in range(sites.size() - 1, -1, -1):
		var site: Dictionary = sites[i]
		var age: float = now - float(site["start"])
		if age > BURN_SECONDS:
			sites.remove_at(i)
			continue
		var strength := 1.0 - smoothstep(BURN_SECONDS * 0.6, BURN_SECONDS, age)  # burns down over the last 40%
		var position: Vector3 = site["position"]
		if now >= float(site["next"]):
			site["next"] = now + FLAME_EVERY * _rng.randf_range(0.7, 1.3)
			var jitter := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(0.8, 2.6), _rng.randf_range(-1.0, 1.0))
			bursts.spawn(BurstSystem.Kind.FIREBALL, position + jitter, _rng.randf_range(2.6, 3.8) * (0.5 + 0.5 * strength),
					_rng.randf_range(0.8, 1.2), Color(1.0, 0.75, 0.55), now)
		var flicker := 0.75 + 0.25 * sin(now * 13.0 + position.x) * sin(now * 7.3 + position.z)
		lights.request(position + Vector3(0, 1.8, 0), Color(1.0, 0.45, 0.12), 3.5 * flicker * strength, 9.0, LightPool.PRIORITY_VEHICLE)


func burning_count() -> int:
	return sites.size()
