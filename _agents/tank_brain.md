# Tank Brain: the Deterministic CPU Middle Layer

> **Status: v1 implemented and measured (2026-09-13).** Results are at the bottom. The squad-command UI is the open question for the lead.
> This is the concrete engineering plan behind [squad_ai_design.md](squad_ai_design.md)
> (the *why*) and [vision.md](vision.md) (the *where*).

## The lead's framing (2026-09-13), which this doc answers

> "Video games have existed for decades before AI came along, so I basically need
> tank heuristics so that they can respond to AI directives… directives would still
> be structured data… commanding a squad of tanks against another squad… every tank
> should still be completely autonomous… the real value of the player is if he can
> make the tanks act as a team much better than they can work in isolation… weights
> in a tree that drive behavior… different weapon types (i.e. short range flame
> throwers)… a robust, deterministic middle layer that allows strictly CPU to drive
> behavior."

Every clause maps onto a layer:

```
 COMMANDER   player UI  |  CPU commander  |  LLM (optional, later)
     │  emits DIRECTIVES: structured data, validated, never code
     ▼
 SQUAD       shared intel, squad objective + stance → per-tank directive defaults
     ▼
 TANK BRAIN  autonomous utility AI ("weights in a tree"): senses, scores options,
     │       picks one, explains why. Deterministic: same inputs → same choice.
     ▼  emits ORDERS (move_to / target / fire_at_will / reverse …)
 ORDERS      OrderController: pathing, steering, aiming, firing discipline (exists)
     ▼  emits TankCommand every tick
 SIMULATION  Tank physics, weapons, armor, damage (exists; server-authoritative)
```

**Nothing below the commander needs an LLM.** A match can be played entirely by
CPU (both commanders CPU), which is what the match runner and experiments do. The
LLM only ever writes directives, the same structured data a UI produces.

## Principle: competent individuals, myopic by design

If brains coordinate perfectly on their own, the player has nothing to add. If
they're stupid, the game is babysitting. The target is:

- **Individually competent:** each tank fights well on its own. It uses its weapon's range, prefers cover when hurt, backs away with the front armor forward, and doesn't wander into walls.
- **Locally myopic:** a tank reasons about *itself and what its team can see*. It does not plan multi-tank maneuvers (bait here while that one flanks there) or trade its life for the team.
- **Team value comes from directives:** the commander supplies what individuals can't: *who goes where, when, in what role, and who sacrifices*. That's the lead's thesis, and it is **testable**: the same tanks with coordinated directives must beat the same tanks with default directives (experiment T1 below).

## Teamwork mechanics (why coordination beats isolation)

The rules must *reward* coordination, or the thesis fails. Current and planned:

| Mechanic | Rewards | Status |
|---|---|---|
| Armor facing (front ×0.5, side ×1, rear ×1.5) | A second tank hitting the side while the target faces the first | ✅ exists |
| **Shared team vision** (anything one tank sees, the team knows) | Scouts spotting for long guns; flankers knowing where the enemy faces | v1 |
| Focus fire | Several tanks on one target kill it before it kills anyone | emerges from `target_priority` directives |
| **Weapon roles** (long-range cannon vs short-range flamethrower) | A flamethrower must be escorted or approach from cover; cannons must keep it off them | v1 |
| Suppression / morale, smoke, artillery that needs a spotter | Combined arms | later |

## Determinism contract (the "robust" part)

The whole match runner is already reproducible: the same seed three times gave a
byte-identical result (2026-09-13, same binary and machine). The brain must keep
it that way, and must be deterministic *on its own* so it can be unit-tested
without physics:

1. **Clock = physics ticks.** Brains think every `THINK_EVERY_TICKS` physics ticks, staggered by a stable per-tank index. Never `Time.get_ticks_msec()` for decisions.
2. **Snapshot in, decision out.** At each think, a `Situation` is built (self, weapon, directives, known contacts from team intel, allies, objective), iterating tanks **sorted by name**. `TankBrain.decide(situation) → Decision` is a pure function.
3. **Seeded randomness only.** Any randomness uses a per-tank RNG seeded from `(match seed, tank name)`. (v1 uses none.)
4. **Stable tie-breaking.** Equal scores → the earlier option in a fixed option order.
5. **Explainable.** Every decision records the top options and their scores. Shown in observations and the in-game overlay.
6. **Guarded.** Unit tests on hand-built Situations; a whole-match determinism check (same seed twice → identical result) in `make check`.

Godot physics isn't guaranteed identical across CPUs/OSes, so cross-machine lockstep
isn't a goal: the server stays authoritative. Determinism serves **testing,
replays on one server, and experiments**.

## Directives v1 (structured data)

Per tank, inheriting from its squad, inheriting from role presets:

```json
{
  "role": "assault",            // preset bundle: assault | anchor | flanker | scout | support
  "aggression": 0.6,            // 0..1  engage vs hold back
  "caution": 0.5,               // 0..1  cover/retreat weight; also sets the retreat HP threshold
  "flanking": 0.3,              // 0..1  preference for side/rear firing positions
  "cohesion": 0.5,              // 0..1  pull toward squad-mates
  "objective": {"right": 0, "forward": 0, "radius": 12},  // team-relative (see below), or null
  "leash": 25,                  // max distance from objective (0 = free roam)
  "target_priority": "nearest"  // nearest | weakest | most_exposed | threatening_allies
}
```

**Team-relative coordinates** (`right`, `forward`) make one doctrine valid for
both sides and keep experiments fair: `forward` points at the enemy base, and the
origin is the arena center. Green: world `(right, -forward)`. Rust: `(-right, +forward)`.

## Options the brain scores (v1)

| Option | Does | Scores high when |
|---|---|---|
| `ENGAGE target` | Go to the weapon's preferred range with line of sight; face the target; fire | aggression; target known and in reach; weapon range fits; target weak/exposed |
| `FLANK target` | Move to a point beside the target's facing, at preferred range | flanking; target is busy facing someone else (its hull points at an ally) |
| `TAKE_COVER` | Move to a nearby reachable point hidden from known threats | caution × (1 − health) × threats that can see me |
| `RETREAT` | Back away (reverse, front armor forward) toward the rally point | health below the caution-derived threshold; outnumbered |
| `ADVANCE` | Move to the objective | objective set and I'm outside its radius; no pressing threat |
| `HOLD` | Stay (or return inside the leash); fire at anything visible | at objective; anchor role; no reachable target |
| `INVESTIGATE contact` | Go to a contact's last known position | contact recently lost; aggression |

Commitment: the current option gets ×1.15 and at least 1 s before switching.

## Weapons v1 (data-driven)

| Weapon | Kind | Range | Damage | Reload / rate | Armor effect | Implies |
|---|---|---|---|---|---|---|
| `cannon` | projectile, 70 m/s | 110 m (preferred 25–60) | 34 per hit | 2.0 s | front ×0.5 / side ×1 / rear ×1.5 | Long-range duels; positioning for side shots |
| `flamethrower` | cone 30°, line of sight | 20 m (preferred 6–16) | 45 per second while in cone | continuous | armor matters less: ×0.8 / ×1 / ×1.2 | Must close distance: needs cover, flanks, or escorts; devastating on campers |

## Squad command UI (open: needs the lead)

Everything above works without a UI (the match runner uses doctrine files). The
player-facing question is how a human emits directives *during* a match. Options
to prototype, from least to most RTS-like:

1. **Playbook cards:** pre-match, pick a formation play ("Pincer", "Anvil & Hammer", "Bait & Ambush") that fills squad objectives and roles; live, a few "calls" (e.g. "Execute flank", "Fall back") on a cooldown. Fewest decisions, most phone-friendly.
2. **Tactical map + stances:** a top-down map; drag a squad's objective marker; choose a stance chip (Aggressive / Hold / Flank / Bait). Tanks remain autonomous inside the stance. Closest to Company of Heroes.
3. **Phase timeline:** pre-match, author conditions → directive changes per squad ("when Left squad loses a tank, Right squad falls back"); live, watch and occasionally override. Closest to the doctrine / LLM vision.

All three produce the **same directive data**, so the brain doesn't care which
wins. Recommendation: build (2) first as a debug tool (it's also how we'll
inspect brains), and evaluate (1) for phones.

## Experiments for v1

| # | Question | Pass if |
|---|---|---|
| T0 | Is the brain deterministic? | Same seed twice → identical result; golden Situation tests pass |
| T1 | **Does coordination add value?** Same 5v5 loadouts; "Individuals" (default directives) vs a coordinated doctrine | The coordinated doctrine wins clearly, *with* the swap-bases control |
| T2 | Is the brain better than BotController? | The brain team beats the BotController team |
| T3 | Do weapons create strategy? A flamethrower-heavy doctrine vs cannons in open vs cover-rich approaches | Results depend on doctrine (an approach via cover), not a flat winner |

## Results (2026-09-13)

All series: 5v5, first to 10 kills or 300 s, 60 seeded matches per row, doctrines in `doctrines/`.
"Swapped" = the `--swap-bases` control. Raw per-match JSON: `build/experiments/` (not committed;
re-run with `build/experiments/run.sh`-style commands shown in verification.md).

| # | Series | Normal bases | Swapped bases | Combined | Verdict |
|---|---|---|---|---|---|
| T0 | Same seed twice (`make determinism`) | identical | | | ✅ deterministic |
| T0b | **Mirror:** Individuals vs Individuals | Green 24 : 36 Rust | Green 26 : 34 Rust | **Rust 58%** (p ≈ 0.07) | ⚠ possible team-identity bias, not base. See below |
| T1 | **Anvil & Hammer (Green) vs Individuals**: same 5 cannons, coordinated vs not | 38 : 22 | 37 : 23 | **Coordinated 62.5%** | ✅ **Coordination adds value** (the lead's thesis) |
| T2 v0 | Brains (Individuals, Green) vs 5 BotControllers | 23 : 37 | 19 : 41 | Brains 35% | ❌ bug found (below) |
| T2 | Same, after the fallback fix | 47 : 13 | 37 : 23 | **Brains 70%** | ✅ brains beat the old bot |
| T3 | Flame Rush (Green) vs Individuals | 4 : 56 | 3 : 57 | Flame 6% | Charging flamethrowers across open ground is suicide |
| T3b | **Anvil & Burners** vs Individuals: T1's structure with the 2 flankers as flamethrowers; played as Green, then as Rust (team-identity counterbalance) | as Green 0 : 60 | as Rust 0 : 60 | **Burners 0%** | ❌ **the flamethrower is a dominated weapon under current rules** |

### What T2 v0 taught us: measure the mechanism, not just the winner

Brains first **lost** 35% to BotController. Shot counts showed brains firing ~15% fewer shells
with equal accuracy, so the gap was in firing, not aiming. A new stat, **idle guns** (a loaded
gun with an enemy in the tank's *own* sight and range, not firing, sampled every 6 ticks), showed brains
idle **95–97%** of those samples (bots 69–91%), and in that state 4–5× as often. Cause: a brain
chose its target from *team* intel, so the target was often visible to a teammate but not to itself,
and the `target` order refused to shoot anything else. Fix: `target` orders take `"fallback": true`
(shoot the nearest visible enemy meanwhile). Brains went from 35% to 70%. Regression test:
`test_brain_shoots_what_it_can_see_while_its_target_is_hidden` (mutation-checked: it fails without the fallback).
`tools/match_series.py` now prints idle-gun rates for every series.

### The T0b warning and the experiment rule it adds

Identical doctrines should split 50/50. Rust won 58% from **both** bases, so it isn't the map;
if real, it's ordering (Green brains spawn, think, and sort before Rust's). Not significant yet.
Every doctrine in T1–T3 played as **Green**, so a Rust advantage would only *understate* their
results, and the conclusions stand. **New rule:** counterbalance *team identity* as well as bases
(run a doctrine as Green and as Rust), and investigate with `--rust-first` and larger N before
any close comparison (E2/E3).

### T3: weapons don't create strategy yet, because the flamethrower has no upside

Swapping T1's two flanking *cannons* for *flamethrowers* took the doctrine from 62.5% to 0%.
The flamers averaged only ~130 flame damage per match (the naive Flame Rush managed 332), meaning they
die crossing open ground long before reaching 20 m. A flamethrower tank today has the same
hull, speed, and health as a cannon tank with a sixth of the range, which makes it strictly worse.
**A weapon only creates strategy if it has a real upside** (this is E3's "no dominant option"
criterion showing up at the weapon level). Candidate trade-offs, for the lead to choose:
- Flame tanks are **faster** (e.g. 13 m/s) and/or **tougher** (e.g. 150 HP), buying the approach.
- **Smoke** (a utility that blocks line of sight for a few seconds) lets anything close distance.
- Maps with **more close cover / chokepoints** so flamers can approach unseen; arena variety becomes a strategic layer.
- Cannon tanks get a **minimum effective range** or slow turret traverse up close.
Re-run T3/T3b after any change; the goal is "depends on doctrine and map", not "flamers win".

### Observations worth carrying forward

- Everyone's idle-gun rate is ~72% even when working correctly: most of the time a loaded tank with an enemy in sight is still swinging its turret (110°/s) or waiting for the 2.5° aim tolerance. That's a combat-feel knob (turret speed, tolerance) to revisit with the lead's playtest feedback.
- Hits are still ~83% front / 17% side / ~0% rear. Flanking happens but rarely *completes* a rear shot; FLANK standoff positions and cover-seeking are the obvious next heuristics to tune.
