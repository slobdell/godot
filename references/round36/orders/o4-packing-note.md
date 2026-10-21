# O4: packing toward the click (design note, orders, 2026-10-20)

**His words (round 34):** "isn't there enough spacing where we could intersect two wedges basically?" Several squads
clicked to one point should end up AROUND the click, not pushed away from it.

**Round 35's record:**
- D3 (`--pack=on`) packed the HALTS: five coils took 64 m against the ranks' 74 m. But arriving wedges mixed.
- D3b kept arrivals apart (a file arrival), and the spread GREW in every click cell (Crossing 3 64 v 34 m), with two
  river crossings (R35.43).
- game_design.md asked round 36 for "pack toward the click first; treat arrival overlap as transient".

## What the pack refuses (the measurement this note rests on)

`SelectionSquads.pack_refused` (`0409345d1`) is measurement only. In the pack's LAST compaction pass, every candidate
place cheaper than a squad's current place (nearer the click) is counted against the FIRST test that refused it. Laptop
GDScript, seed 34 (dev), `--pack=on`, the 6 click cells, one pack each:

| cell | halt seats < 9 m | inside an outline | ground | travel shapes | travel outline | reach |
|---|---|---|---|---|---|---|
| crossing 3 | 1368 | 591 | 1313 | 90 | 15 | 24 |
| crossing 5 | 5165 | 2060 | 1798 | 725 | 171 | 0 |
| locks 3 | 1259 | 649 | 763 | 71 | 15 | 0 |
| locks 5 | 4589 | 1804 | 623 | 175 | 54 | 0 |
| terminus 3 | 937 | 394 | 1464 | 79 | 3 | 0 |
| terminus 5 | 3893 | 1538 | 903 | 173 | 35 | 0 |

Arrival overlap (the two travel tests) is **3–8 % of refusals**. Dropping it frees almost no place nearer the click:
- What binds is the **halts' own clearance**: HALT_CLEAR_M = 9 m between any two squads' seats, and no seat inside
  another squad's outline.
- Then **ground** (a seat must be standable within 4 m). It is the first test in the 3-squad Terminus and nearly so on
  the Crossing.

"Treat arrival overlap as transient" is not the lever this objective needs.

## What that leaves

1. **The halt clearance is a spacing decision, not a bug.** 9 m seat to seat between squads is under one spacing (lanes
   11, open 14). Packing tighter means squads standing closer than a crew stands to its own squadmate. That is a design
   pillar question (survivability against splash and artillery v "around the click"), so it is the lead's.
2. **Ground** refuses seats that land on buildings or water. D3b's spread came from honouring this strictly. Relaxing it
   only moves the problem to Element's grounding (seats snapped onto the nearest standable point), which is where seats
   mixed in D3.
3. **The objective is already "toward the click".** The pack's cost is each squad's farthest seat from the click. The
   compaction passes move squads nearer whenever a place fits.

## Recommendation

**Park O4 with this reading. No switch, no series.** Today's ranks (74 m for five coils) are within ~14 % of what any
pack that keeps 9 m between squads reached (64 m). The rest is the clearance itself. One question for the lead, in
player terms:

> When you send five squads to one spot, they end up spread about 70 m across. They could stand about 10 m tighter if
> squads were allowed to park as close to each other as crews in one squad do (about 9 m apart), at the cost of one
> shell catching two squads. **Recommendation: keep today's spacing.** Ask for tighter only if the spread bothers you
> in play.

Falsifier for this reading, if he asks for tighter: the same `pack_refused` count with HALT_CLEAR_M at 6 m should show
"halt" refusals fall and the 5-squad cells' `end far max m` fall by >= 15 % on builder0 fresh seeds. If the spread
doesn't move, ground binds next, and the clearance was never the cost.
