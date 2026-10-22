# S2's failed guard traced: crossing 5 click s3866, squad 4 never in under the deploy latch (builder0 light, native, e42ff30eb tree)

`make settle-trace SETTLE_TRACE_CASES=crossing:5:click:3866:4` with `--element-trace=all --arrive-trace`, main v `--deploy-latch=on`;
n 1 each (reproduces the judged rows: main squad 4 arrived 33.9 s, latch never). `all-*` = every element once a second.

- **The place:** the probe's squad 4 (element Echo; crews Delta_1/4/5 + Echo_4 after the untangle) is laid at (-71.9, 27.0) with a
  seat at (-79.7, 33.7), 0.4 m from squad 3's (Charlie) back seat (-80.0, 34.0), where Charlie_3 has stood parked since t~20. Same
  in both arms: squad 4 must squeeze in among a parked squad.
- **The divergence:** Charlie's halt is re-spaced once between t=22 and t=26 in main (Charlie_1's seat (-82.5, 45.7) -> (-83.4, 47.3));
  under the latch its spacing is the deploy's, so the seat is (-83.4, 47.3) from t=22. Every other seat of Charlie and Alpha is
  identical in both arms.
- **What follows:** main: Charlie_1 stands 7 m off its seat at t=36 and squad 4 gets its centre within 12 m (arrived 33.9 s). latch:
  Alpha_3 (squad 1) moves off its seat from t=33, 20 m west by t=45 (back at t=54), into the lane squad 4 uses; squad 4's crews sit
  at (-82, 42)-(-86, 36), its centre never within 12 m in 90 s.
- **Reading:** a pre-existing contention case (orders' lay puts a place on another squad's parked tank; manoeuvre's give-way leads
  the yielder far, M5's domain) flipped by a 1.5 m seat difference. Not a shape the latch chose: the first shape is the same.
