class_name FireSites
extends RefCounted
## Burning wreck sites (art stretch, extended by feel X4): every kill leaves a fire that flickers for BURN_SECONDS, fed
## into the pooled BurstSystem: flames licking up from a few points across the wreck, a column of black smoke, and now
## and then a cook-off (ammunition popping: a flash, sparks, a small fireball), plus a low-priority pooled light that
## flickers with it. No new draw calls or nodes. How many burn at once follows the tier; the oldest goes out first.
## Visual only: a site is just where a kill explosion happened. (Keeping a wreck MODEL there needs rules to leave the
## dead unit visible: requested from combat in streams/feel.md.)

const BURN_SECONDS := 30.0
const FLAME_EVERY := 0.25
const SMOKE_EVERY := 0.7
## Cook-offs come at random intervals in this range (seconds), fewer as the fire burns down.
const COOK_OFF_EVERY := Vector2(2.5, 5.0)
const PER_TIER := {FxQuality.Tier.LOW: 3, FxQuality.Tier.MEDIUM: 6, FxQuality.Tier.HIGH: 10}

## [{position: Vector3, start: float, next: float, next_smoke: float, next_pop: float}]
var sites: Array = []
## Totals since load (tests and the bench).
var smoke_puffs := 0
var cook_offs := 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 97


func ignite(position: Vector3, now: float, bursts: BurstSystem) -> void:
	sites.append({"position": position, "start": now, "next": now + 0.6, "next_smoke": now + 0.5,
			"next_pop": now + _rng.randf_range(1.2, 2.5)})
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
			# Flames lick up from anywhere along a hull-sized patch, not one point.
			var jitter := Vector3(_rng.randf_range(-1.4, 1.4), _rng.randf_range(0.8, 2.6), _rng.randf_range(-1.8, 1.8))
			bursts.spawn(BurstSystem.Kind.FIREBALL, position + jitter, _rng.randf_range(2.6, 3.8) * (0.5 + 0.5 * strength),
					_rng.randf_range(0.8, 1.2), Color(1.0, 0.75, 0.55), now, Vector3.ZERO, 0.0, 0.0, _rng.randf_range(0.5, 1.2))
		if now >= float(site["next_smoke"]):
			site["next_smoke"] = now + SMOKE_EVERY * _rng.randf_range(0.8, 1.2) / maxf(strength, 0.4)
			bursts.spawn(BurstSystem.Kind.SMOKE, position + Vector3(_rng.randf_range(-1.0, 1.0), 2.5, _rng.randf_range(-1.0, 1.0)),
					_rng.randf_range(3.5, 5.0) * (0.6 + 0.4 * strength), _rng.randf_range(3.5, 4.5), Color(0.12, 0.11, 0.11, 0.9), now,
					Vector3(_rng.randf_range(-0.4, 0.4), 0.0, _rng.randf_range(-0.4, 0.4)), 0.2, 0.0, 2.2)
			smoke_puffs += 1
		if now >= float(site["next_pop"]) and strength > 0.3:
			site["next_pop"] = now + _rng.randf_range(COOK_OFF_EVERY.x, COOK_OFF_EVERY.y) / strength
			var spot := position + Vector3(_rng.randf_range(-1.0, 1.0), 1.4, _rng.randf_range(-1.2, 1.2))
			bursts.spawn(BurstSystem.Kind.STAR, spot, 3.0, 0.1, Color(1.0, 0.85, 0.6), now)
			bursts.spawn(BurstSystem.Kind.SPARKS, spot, 5.0, 0.8, Color(1.0, 0.55, 0.18), now)
			bursts.spawn(BurstSystem.Kind.FIREBALL, spot + Vector3.UP * 0.5, 2.4, 0.5, Color(1.0, 0.75, 0.55), now)
			lights.flash(spot, Color(1.0, 0.6, 0.25), 5.0, 10.0, 0.25, LightPool.PRIORITY_EXPLOSION - 0.5, now)
			cook_offs += 1
		var flicker := 0.75 + 0.25 * sin(now * 13.0 + position.x) * sin(now * 7.3 + position.z)
		lights.request(position + Vector3(0, 1.8, 0), Color(1.0, 0.45, 0.12), 3.5 * flicker * strength, 9.0, LightPool.PRIORITY_VEHICLE)


func burning_count() -> int:
	return sites.size()
