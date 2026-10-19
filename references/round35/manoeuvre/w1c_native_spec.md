# W1c native mirror spec (round 35, manoeuvre; R35.12 / R35.14). GDScript reference: stream/manoeuvre f9b3bb7f3+

**What:** in `Movement._unstick`, the stall rule's throttle test reads `Manoeuvre.stall_throttle(self, cmd, order)` instead of
`absf(cmd.throttle)`. Default OFF (`Manoeuvre.STALL_INTENT_DEFAULT := false`); `--nav-off=stallintent` flips it. With it OFF, the
function returns `absf(cmd.throttle)`, so nothing changes.

**GDScript (game/ai/movement.gd, `_unstick`):**
```gdscript
	var reading := ctl.tank.real_velocity if honest else ctl.tank.estimated_velocity
	# Round 35 (W1c, R35.12, `stallintent`): against a friendly hull, the throttle test reads the drive's intent.
	if Manoeuvre.stall_throttle(self, cmd, order) > 0.5 and reading.length() < STUCK_SPEED:
```
**The rule (game/ai/manoeuvre.gd, `stall_throttle` / `_against_friend`):**
```
command = |cmd.throttle|
return command if  command > 0.5  or not stall_intent_on()  or mover.pace_now >= 1.0
return command if  order.type != "move_to"  or order.direct  or order.reverse
return command if  not against_friend(mover)
intent = command / max(mover.pace_now, STALL_INTENT_MIN_PACE)      # STALL_INTENT_MIN_PACE = 0.05
if intent > 0.5: Manoeuvre.stall_intent_ticks += ctl._step          # static counter (stride ticks by their stride)
return intent

against_friend(mover):
  for each slide collision of the tank: collider is a Tank and collider.team == tank.team -> true
  if mover.phase == "blocked" and mover.blocked_by != "" and ctl.tanks_root != null:
      blocker = tanks_root.get_node_or_null(blocked_by) as Tank
      return blocker != null and blocker.team == tank.team
  false
```
**drive_native.cpp (the port's `unstick`, ~line 1710–1713 at f9b3bb7f3):** replace
```cpp
		const double throttle = cmd->get(k.throttle);
		...
		if (std::fabs(throttle) > 0.5 && (double)velocity.length() < c.STUCK_SPEED) {
```
with a `stall_throttle(cmd, order)` that does the above on the mover's own members: `pace_now` (already a field), `phase`,
`blocked_by`, the tank's slide collisions (as `honest_blocker` walks them, plus a `team` compare), `ctl.tanks_root` lookup by name,
the switch read once at configure (`Manoeuvre.stall_intent_on()` → a config bool, as `c.UNSTICK_BACK`), `STALL_INTENT_MIN_PACE`
as a constant, and `Manoeuvre.stall_intent_ticks` incremented with `sadd` (a Manoeuvre static, as other Manoeuvre counters).

**Order of tests matters for the counter only:** `stall_intent_ticks` counts ticks where the intent (not the command) passed 0.5;
with the command already > 0.5 the function returns early and counts nothing.

**Twins:** tests/test_manoeuvre_stall_intent.gd (2 tests, the rule) and the drive twins under both arms (OFF must be bit-identical
to today; ON: the twin case of a routed hull blocked by a friend at pace 0.05, command 0.05 → the stall clock runs in both).
**Counters the series reads (M6's (0)):** `Manoeuvre.stall_intent_ticks`, `Movement.esc_fires_hull`, `Movement.esc_asks`, plus T9's
`yields_unfinished` (traffic's spec, `_agents/streams/references/round35/traffic/t9_native_spec.md`).
