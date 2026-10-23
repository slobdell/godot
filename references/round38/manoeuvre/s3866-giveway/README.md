# s3866 (crossing, 5-squad click, squad 4): why a squad-1 tank ends 20 m into squad 4's lane

Settle's case (`references/round38/settle/s2-neverin-trace-builder0/` on stream/settle). builder0 light, native, n 1 per arm,
`make settle-trace SETTLE_TRACE_CASES=crossing:5:click:3866:4` + `--element-trace=all --arrive-trace`, 2026-10-23.
- BASE trees: lab `lab/manoeuvre-r38-s3866` d81472918 = settle e5a7f60b3 + a GIVEWAY row per probe give-way (lab only, never merged).
- SEATSTEP trees: lab `lab/manoeuvre-r38-s3866on` 5a4158505 = the same + `lab/manoeuvre-r38-m5on` (M5a + native pair, seatstep ON).

| squad 4 arrived | main | `--deploy-latch=on` | `--deploy-latch=anchor` |
|---|---|---|---|
| base (seatstep OFF, as shipped) | 33.9 s | never (90 s) | never (90 s) |
| seatstep ON | 44.8 s | 39.9 s | 39.9 s |

**The 20 m is not one pick and not a lead-out.** Under the latch (and anchor: identical rows), Alpha_3 gives way FOUR times in 10 s,
each asked by a squad-4 crew, each from where the last one left it: t=30.5 spot(5,-9) 10.3 m (seat 2.9 m) -> t=36.5 spot(5,9) 10.3 m
(seat 7.5) -> t=37.5 spot(3,6) 6.7 m (seat 8.5) -> t=40.3 spot(3,-6) 6.7 m (seat 15.6) -> ~20 m off its seat. None is a straight-
ahead (10/16/24, 0) lead-out, so seatstep's lead-out refusal is not what catches it. Each spot is legal on its own; the chain is
the fault: a yielder already pushed off its seat by a give-way is asked again by the same squad and pushed further along its way.

With seatstep ON the case arrives in every arm (the nearest-to-seat choice breaks the chain: in main Alpha_3 gives way once and
then holds), but n = 1 and seatstep failed its judged bar (M5 v2, R38.24), and main's arrival is later (44.8 s vs 33.9 s).

**Lever (a candidate, not built):** chain-aware give-way: a crew already more than SEAT_NEAR_M-ish off its seat because of a
give-way does not take a spot farther from its seat (hold, or the nearest-to-seat legal spot). The give-way's spot test is
mirrored in C++ (drive_native.cpp begin_yield, N5.Y), so it needs native's twin first. A bar would read the chained give-ways'
seat drift on the jam census before any series.
