# P5: the face-keep tail re-measured after the flicker fix (planner, 2026-10-19; diagnosis, NOT a judged series)

Tree 15f5980ac = main with M2 (the k-turn arrival flicker, 75a1d8c51) and M1 (the new hull-rest ruler) + planner's
tools; builder0, native; hull-rest gangs, both modes, dev seeds 96-107 (old tuning seeds; the stage now shifts with the
seed); base = --planner-face-keep=0, candidate = 1 (the shipped default); FIFO. `make planner-judge-face` per arm.

**The tail v3 was meant to cut is gone.** Round 33's miss was a clicked face only the candidate planned (12.4 m, the
attack-move face asked mid-k-turn). Here: faces planned by the candidate only, 0 drawn and 0 clicked (face_pairs
CAND_ONLY). No tail remains on faces planned by one arm, so a v3 slot cap has no target.

What remains is reported, not judged (n 19 faces, dev seeds): clicked faces BOTH arms planned, median 2.5 v 2.0 m
(se 0.26), p90 4.0 v 3.9, max 9.1 v 4.0 (one face). Drawn: 9 both-planned faces, too few to read.
FACE_KEEP_FAR (reported only, R34.5): clicked max 16.6 v 21.0, drawn p90 8.7 v 6.7.

**Recommendation: P5 closes with no v3.** Watch the one 9.1 m both-planned clicked face in the next series that
reads face_pairs.
