# The wedged deaths on main: a measurement-only read of traffic's T5 rows (round 34, manoeuvre)

Source: traffic's T5 jam-death census, `~/overnight-traffic/r34/t5/jam-fda16c670/` (builder2, native, main fda16c670,
seeds 1200–1247 × terminus/locks/random, 144 fights, 180 s, 5984 `JAM_DEATH` rows, each a crew lost with what it was doing
the tick before: `cause` by far_census.gd's `death_cause`). No new run; `table.txt` is the script's output. A row carries
speed (signed), still time, hits taken in the last 10 s, terrain, position and distance from base; it does NOT carry
whether `unstick` fired, so that is read from the rule (movement.gd: the stall rule counts only under |throttle| > 0.5
with speed < STUCK_SPEED 0.8 m/s for STUCK_SECONDS 1.0; `wedged` = avoidance shaped the velocity on > 50 % of the last 2 s
and the hull moved less than its own length).

| what | reads |
|---|---|
| wedged deaths | 499 of 5984 = 8.3 %, 3.5 a fight; every one in phase `driving`, none `blocked_by` anyone (avoidance, not a blocker) |
| which hulls (wedged / that hull's deaths) | law_suppressor 15.6 %, burner 15.8 %, ifv 14.3 %, tank 13.6 %, law_ifv 13.5 %, lancer 13.3 %, gang_support 11.6 %, gang_tank 11.2 %, gang_ifv 8.5 % (68, the most), law_tank 7.3 %; scouts 2–3 %, artillery 2–4 % |
| where | lanes 377 (8.8 % of lane deaths), dense 74 (6.7 %), open 48 (8.0 %); Locks 195 (10.2 % of its deaths), random 153 (7.6 %), Terminus 151 (7.3 %); on the Locks the x ≈ 0 column (the lanes' mouths, cells (0,−20)…(0,20)) holds 57 of 195; 55–111 m from base (p10–p90), i.e. at the enemy, median 33 s into the fight (open:driving 46 s) |
| was it moving | speed at death median 1.2 m/s, p90 6.0; 58 % at ≥ 0.5 m/s, 104 of 499 reversing; still ≥ 1 s only 17 %, ≥ 2 s 51 |
| under fire | 85 % took a hit in the last 10 s (median 5 hits, p90 27) |
| could unstick fire | 130 (26 %) were under STUCK_SPEED at death, 53 of those still ≥ 1 s: the stall rule could have been counting on at most a quarter; on the other three quarters it cannot run, since the hull is moving (avoidance-shaped) above 0.8 m/s |

Reading: a wedged death is a mid-weight hull (IFV, tank, suppressor, burner) in a lane mouth at the enemy, under fire,
being pushed around at walking pace by its own avoidance rather than driving or stopped; it is not a parked crew and not a
crew held by a blocker. The unstick stall rule never sees most of them because they never drop under 0.8 m/s. A second
trigger on `wedged` itself (round 35 candidate, traffic's view agreed in round 34's Status) would act on these; whether a
back-off helps a crew that is being shot (85 %) is the bar that candidate must file first.
