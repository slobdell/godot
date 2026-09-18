# Arena's measurement records (round 6, 2026-09-18)

The raw `make nav-maze` results behind the numbers quoted in [arenas.md](../../../arenas.md) *The Maze* and in
arena's brief. They are here so nav (and whoever re-measures after nav's Movement API lands) can **compare a new
result against the world before it, without re-running the machine time**.

**All five runs: the lead's laptop, commit `38c15f77`, seed 1, 180 s, all `tank`, hold-fire.** Hold-fire matters:
these measure *driving only*, with no enemy and nothing to do but reach a destination. Nothing here is frame-rate
sensitive — the probe runs under `--fixed-fps 30`, so the laptop being ~2.75× slower than builder0 changes how long
you wait, not the result.

| File | What it holds | Headline | Reproduce with |
|---|---|---|---|
| `nav-maze-30-2026-09-18.json` | 30 vehicles one way across The Maze | **15 of 30 arrived**; t50 60 s, t90 never; **all 30 stalled**; 47% of the route travelled | `make nav-maze NAV_UNITS=30` |
| `nav-maze-60-2026-09-18.json` | 60 vehicles one way across The Maze | **36 of 60 arrived**; t50 56 s, t90 never; **all 60 stalled**; 49% travelled | `make nav-maze NAV_UNITS=60` |
| `nav-yard-60-2026-09-18.json` | 60 vehicles one way across **yard** — the control | **33 of 60 arrived**; t50 31 s, t90 never; 27 of 60 stalled; 91% travelled | `make nav-maze NAV_UNITS=60 ARENA=yard` |
| `nav-maze-60-both-2026-09-18.json` | 60 vehicles, **head-on** (half from each base), The Maze | **23 of 60 arrived**; t50 **never**; all 60 stalled; 39% travelled | `make nav-maze NAV_UNITS=60 NAV_BOTH=1` |
| `nav-yard-60-both-2026-09-18.json` | 60 vehicles, **head-on**, yard — the control | **35 of 60 arrived**; t50 37 s; 30 of 60 stalled; 93% travelled | `make nav-maze NAV_UNITS=60 NAV_BOTH=1 ARENA=yard` |

## What they say, and what they do not

**The yard control is the finding, not the maze.** On a shipping arena, with no enemy and nothing to do but drive,
**45% of a 60-vehicle force never reaches its destination in three minutes** and 27 of them stall outright. That is
the lead's *"a bunch of cars just get stuck or blocked by other cars"*, reproduced headlessly without a shot fired.
The maze sharpens it — every unit stalls, half the route goes untravelled — but it does not invent it.

**Head-on traffic is where the maze earns its keep.** Splitting the force between both bases barely moves yard
(55% → 58% arrived, inside noise) and collapses the maze (60% → 38%, and t50 stops being reached at all). Narrow
corridors are where two streams meeting matters, which is the point of the fixture and the reason its two gates
share one corridor instead of running as separate pipes.

**Do not read these as a comparison between arenas.** The maze's route is ~409 m per unit against yard's ~223 m, so
"travelled 49% vs 91%" is a statement about *jamming*, not about speed. The comparable columns are arrivals, whether
t90 is ever reached, and how many units stall at all.

**One seed, one probe, one unit type.** Before any of this becomes a claim about a *change*, re-run the pair — the
same arena with and without — rather than adding seeds (lesson 22: a control that cancels the cause, not more
repetitions).

**Two of these files are missing a field, and it is not a defect.** `both_ways` was added to the probe's output
after the two one-way maze runs and the one-way yard run were taken, so those three files have no `both_ways` key.
They *are* one-way runs; a file with no key predates the key. Every later run records it.

## Two numbers that were wrong before they were right

Kept here because both would have been handed to nav as findings about *movement*:

1. **`off_navmesh` was a 3D distance.** A hull's centre sits ~0.7 m above the navmesh, and charging that height to
   every unit turned "hugging a wall" into "off the map": it reported **17 of 60 units off the navmesh** where the
   flat x/z distance reports **0**. The probe measures flat now.
2. **The make target read `UNITS`, and `mk/ai.mk` sets `UNITS ?= 60` globally.** A run whose help text and console
   output both said "30 units" was silently running 60. It reads `NAV_UNITS` now. Any new bare variable name added
   to a shared Makefile is exposed to this.
