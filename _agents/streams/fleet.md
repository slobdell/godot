# Stream: fleet, round 15 (tanks and IFVs that read apart from the play camera)

> Read [`art_direction.md`](../art_direction.md), the archived round-12 fleet brief `archive/round12/fleet.md` and its
> Status (the fire engine; the pipeline fix; the bus that came back a van; how a review page with `db` is made and how
> `art-apply-decisions` reads it), `assets/meshy_ledger.md`, and garage's round-14 G7 item 5
> (`archive/round14/garage.md`): *"My tanks and IFVs look the same in the fight."* **You own** round 12's fleet paths:
> `game/theme/factions/**`, `game/theme/roster/**`, `game/theme/prison_dozer/**`, `game/theme/cyberpunk/dozer_part.gd`,
> `game/theme/gallery/**`, `assets/pipeline/**`, `assets/review/**`, `assets/meshy_ledger.md`, `tools/assets/**`,
> `mk/assets.mk`, `mk/scale.mk`, the gallery/audit/probe targets in `mk/fx.mk`, `tools/roster_scale.py`,
> `tests/test_theme_unit_scale.gd`, `tests/test_units_*.gd`. **NOT this round:** `hull_size` / `muzzle_height` /
> `turret_mount` values in `game/units/units.gd` (a box change moves the sim baseline and needs a CP; only with the
> orchestrator's call and never blind).

## The lead's direction

2026-10-01: *"playin right now feels good, so we should go ahead and set up a bunch of workstreams I can kick off for
the night."* Standing (memory: *production quality over credits*; *concept choices review page*): paid generation is
best quality, the lead limits scope not spend — **but every paid image-to-3D needs his tap on a review page first**,
and he is asleep. Standing (round 12): *"there was nothing wrong with the tank"* — the Condemned tank stays the dozer.

## Where things stand (verify on main)

- The Condemned `tank` and `ifv` both draw from the dozer-bus family; from his play camera (pitch 21°, 72 m, FOV 35°)
  garage's tour frames show them as the same long bus. The turntable tells them apart (different turrets, lengths
  8.62 vs the IFV's), the fight does not.
- Round 12's pipeline: concept images → the review page (`db`) → his tap → image-to-3D → the hull's own art, the
  −Z test, `test_theme_unit_scale`. Meshy ledger at 779 credits after round 12.
- `make remote T=formation-shots` and `tactics-shots … --pose=his` give frames at his pose; `make gallery` the roster.

## Backlog (in order)

**F1. Measure the confusion.** At his pose, the Condemned tank and IFV side by side and in a mixed squad (the frames
garage saw), at desktop and phone: what differs in pixels — silhouette (length, turret, gun), colour, markings, lights?
A contact sheet with the two outlined. Then the same for the other factions' tank/IFV pairs (Law, Gangs, Syndicate): is
this a Condemned problem or a roster problem? Numbers: the pair's silhouette IoU at his pose, drawn length ratio.

**F2. What is FREE first.** Without new generation: a faction-consistent marking that reads at 72 m (a roof stripe,
a turret band, a number plate the dozer family already has slots for), a lamp colour per class, the IFV's turret
scale/profile from the art already in the repo, the paint slots the garage exposes (`PAINT` is per unit already).
Build the cheapest one that moves F1's number, frames before/after at his pose, `test_theme_unit_scale` and the −Z
test green, the gallery re-shot. **No hull_size change.**

**F3. The paid route, prepared not spent.** If F1 says silhouette is the problem (a marking cannot fix a shape at 72 m),
prepare the review page for his morning: 2–3 concept directions per slot (the Condemned IFV as its own vehicle — an
armoured troop bus is the catalogue's word; the Law/Gangs pairs if F1 names them), the first line of every card saying
what APPROVE costs in credits and what it changes (lesson 222), the page with `db`, the URL and the last-read time in
Status. **Concept images are the only paid step allowed tonight** (log every one in the ledger); image-to-3D waits for
his tap.

**F4 (stretch).** The gallery as a lineup at his pose (every faction's tank/IFV/scout in one frame at 72 m) as a
standing test of readability: a measured silhouette-distance floor per pair, failing when a future mesh makes two
classes alike.

## How to verify

`make remote T=check`; the frames looked at; `test_theme_unit_scale`, `test_units_*` green; sim baseline
`6313a38d7ecd99bb` pre-registered UNMOVED (art only; no box changes). The ledger updated for every paid call.

## Don't touch

`game/units/units.gd` values; `game/tank/tank.gd`; `game/garage/**`; `game/arena/**`; `game/theme/arena_kit/airship/**`.

## Waiting on the lead

F3's page, if it is built — his morning. Nothing blocks F1–F2.

## Status

_(the worker keeps this current)_
