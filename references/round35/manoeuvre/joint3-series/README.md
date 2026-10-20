# Joint M6/T9 (W1c stallintent + T9 yieldfit2), joint3 series: FAILS as filed on one deciding line

**Run:** builder0, 2026-10-20 ~03:30–09:30 PDT, 33/33 `make remote` calls exited 0 (`series-summary.txt`). Two native trees (R35.53/59):
ON **lab/joint3-on 872f82ae5** (pair/native-joint3 7a1435cdd + STALL_INTENT_DEFAULT true + yieldfit2 on + a probe counter), base
**lab/joint3-base 2a2682560** (the same code, both switches off). Both on main 5f05c997c: **T7 ON, E1 in, E4 in**. The base carries T6b
(R35.19). Gate: `make native check` 2931/0 on 872f82ae5, base 13/13 sim-baseline unmoved.
Seeds as filed: hull-rest 901–932 drawn × 4 factions × 6 tasks (768 runs an arm, 128 pairs a task, `--turn-states`); fights,
wedge probe and jam census on locks/terminus/sumps × 940–963 (72 fights an arm, SEED_TWINS kept 72/72).
Readers: `tests/manoeuvre/joint_judge.py` (`joint_judge.txt`), traffic's `tests/traffic/jam_ab.py` at 5f2210a8c `--any-arms`
(`jam_ab.txt`), `tests/manoeuvre/cpf_judge.py` (`cpf_judge.txt`, the series' own se, for reference), and (f) squads arrived, summed
from screen.json `squads[].arrived`, paired by run.

| line | read | verdict |
|---|---|---|
| (0) counters, ON | stall_intent_ticks 235 766, H1 hull escapes 2005, asks 1977, yields_unfinished 573 (base 0 / 0) | PASS |
| **(d) attack-move movers, deciding** | **16 → 17 (+1); line ≤ −21.8** (−1.645 × 1.17 × √128) | **FAIL** |
| (d) other tasks, M3's A/A guards | ambush −5, move −2, right +3 (≤ +11.9), screen −1, SBF +0 | PASS |
| (e) attack-move never settled, deciding | 48 → 23 (−25), ≤ 0 | PASS |
| (e) other tasks (≤ +4.9) | ambush −9, move −25, right −12, screen −21, SBF −14 | PASS |
| crews > 25 m off goal with a live move at the judge, deciding | 105 → 59, new ≤ base (768 pairs) | PASS |
| (f) squads arrived | 1631 → 1649 (+18; 1.645 se 9.3) | PASS |
| (i) kills / hit rate team 0 | +28 (57.1) / +0.0016 (0.0167) | PASS |
| (i) kills / hit rate team 1 | +26 (46.5) / +0.0011 (0.0222) | PASS |
| deaths per team ≤ base + 1.645 se | team 0 +22 (45.9), team 1 +26 (58.4) | PASS |
| (q) open / stuck / jam deaths | +34 (74.1) / +11 (38.5) / +3 (24.8) | PASS |
| (r) far loops | 35 → 39 (29.4) | PASS |
| (s) friendly contact ticks | −28 601 (71 098) | PASS |
| give-ways started | 12 536 → 12 744 (+208; 492) | PASS |
| jam-under-fire deaths ≤ base + 1.645 se (R35.53) | 114 → 122 (limit 136.8) | PASS |
| jam:yielding deaths ≤ base + 1.645 se (R35.53) | 124 → 125 (line 146.3) | PASS |
| (t) asks / retries capped | 1425 → 1977 / 0 → 11 | REPORTED |
| all deaths | 3022 → 3070 (+48; 65.6) | REPORTED |

(jam_ab prints its own "G FAIL" and "T6/T7 FAIL". G is T6/T7's deciding gain. It isn't a line of this bar; the joint bar reads
jam-under-fire as a guard.)

## The failing line, read as filed

The filed (d) asks the attack-move task to lose at least 21.8 crews moving at the judge. **The base had only 16 such crews** over
the 128 pairs, so on these seeds the line could not pass even with every one of them still. The line was sized (R35.13, n raised
before any number) from the joint dev read on tuning seeds 460–467, which had 14 base movers in 32 pairs, about 56 at 128. The
fresh block's base is far lower: main moved under the series (E1, E4, T7 ON, M2's arrival hold). That is an observation about the
base, **not a loosening**: the line stays as filed and this series FAILS it.

What the candidate did change on the attack-move task:
- never-settled roughly halved (48 → 23);
- the settle median fell from 68.5 to 44.0 s (cpf_judge, runs holding wheels/turret);
- crews still trying to reach a goal more than 25 m away at the judge fell from 105 to 59, across all tasks.

The stuck asker does get out, and the guards hold. The gain just isn't in the quantity (d) counts.

## Merge notes (if the lead or orchestrator re-files)

- Native (R35.62): stream/native 44b2e04b5 carries W1c's mirror as inert code (byte-identical to pair/native-joint3 7a1435cdd),
  green on builder2 2953/0. Once that is on main, a joint merge is T9's half plus flipping STALL_INTENT_DEFAULT and yieldfit2.
- Any re-run needs a new bar filed before numbers and fresh seeds (901–932 / 940–963 are spent).
