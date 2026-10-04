# Sound-effect ledger (ElevenLabs)

Every paid sound-effect run, appended by tools/audio/sfx_generate.py. Lead gate 1 (round 5): approved; pilot first, then the batch.

| Date | Client | Model | Requests | Seconds | Est. credits | Credits before → after | Spent | Note |
|---|---|---|---|---|---|---|---|---|
| 2026-09-17 | ElevenLabs | eleven_text_to_sound_v2 | 10 | 23.0 | 920 | 124963 → 124733 | 230 | pilot: cannon, 25 mm, MG stream, shell on armour. The balance lags: it read 124963 straight after the run, 124733 a few minutes later (~10 credits per generated second) |
| 2026-09-17 | ElevenLabs | eleven_text_to_sound_v2 | 35 | 51.8 | 518 | 114076 → 113558 | 518 | batch: the other guns and every impact (lead approved 2026-09-17) |
| 2026-09-17 | ElevenLabs | eleven_text_to_sound_v2 | 2 | 1.0 | 10 | 112035 → 112019 | 16 | re-roll of two failed takes (near-silent masters refused by sfx_layer) |
| 2026-09-17 | ElevenLabs | eleven_text_to_sound_v2 | 2 | 1.5 | 15 | 112019 → 112004 | 15 | re-roll of near-silent takes |
| 2026-09-17 | ElevenLabs | eleven_text_to_sound_v2 | 2 | 1.5 | 15 | 112004 → 111989 | 15 | re-roll of near-silent takes |
| 2026-09-17 | ElevenLabs | eleven_text_to_sound_v2 | 2 | 1.5 | 15 | 111989 → 111974 | 15 | re-roll of near-silent takes |
| 2026-09-17 | ElevenLabs | eleven_text_to_sound_v2 | 7 | 15.8 | 158 | 111974 → 111868 | 106 | Syndicate energy pilot: railgun, energy beam, plasma stream (physical-event prompts) |
| 2026-09-18 | ElevenLabs | eleven_text_to_sound_v2 | 7 | 28.0 | 280 | 111816 → 111536 | 280 |  |
| 2026-09-18 | ElevenLabs | eleven_text_to_sound_v2 | 3 | 12.0 | 120 | 111536 → 111416 | 120 |  |
| 2026-09-19 | ElevenLabs | eleven_text_to_sound_v2 | 2 | 25.0 | 250 | 111416 → 111166 | 250 |  |
| 2026-09-19 | ElevenLabs | eleven_text_to_sound_v2 | 10 | 16.6 | 166 | 111166 → 111000 | 166 |  |
| 2026-09-19 | ElevenLabs | eleven_text_to_sound_v2 | 2 | 8.0 | 80 | 111000 → 110920 | 80 |  |
| 2026-10-03 | ElevenLabs | eleven_text_to_sound_v2 | 49 | 157.4 | 1574 | 38274 → 37212 | 1062 | round 17 G3 batch 1: layered sources for the tank, 25 mm, heavy MG and the kill (spend authorised by the lead, C17.5) |
| 2026-10-03 | ElevenLabs | eleven_text_to_sound_v2 | 41 | 51.0 | 510 | 36700 → 36195 | 505 | round 17 G5 batch 2: impacts by surface and calibre, the small-arms snap (C17.5) |
| 2026-10-03 | ElevenLabs | eleven_text_to_sound_v2 | 21 | 52.0 | 520 | 36190 → 35670 | 520 | round 17 G6 batch 3: skids, track squeal, burning wreck, shield recharge, incoming round (C17.5) |
| 2026-10-03 | ElevenLabs | eleven_text_to_sound_v2 | 13 | 27.6 | 276 | 35670 → 35394 | 276 | round 17 G3 batch 4: the other factions brought up (railgun, mortar, missiles, pulse cannon) (C17.5) |
| 2026-10-03 | ElevenLabs | eleven_text_to_sound_v2 | 28 | 51.6 | 516 | 35394 → 35158 | 236 | round 17 G6 batch 5: second tries at the four sounds he marked redo (incoming round, shield up, track skid, track squeal), two directions each (C17.5) |
| 2026-10-03 | ElevenLabs | eleven_text_to_sound_v2 | 10 | 18.3 | 183 | 34878 → 34695 | 183 | round 17 batch 6: the mortar redo he asked for (a hollow heavy thunk, the pressure pop, the round away), three sources for two directions (C17.5) |
| 2026-10-04 | ElevenLabs | eleven_text_to_sound_v2 | 13 | 20.5 | 205 | 34695 → 34490 | 205 | round 17 batch 7: the mortar's fourth design - the shot itself (the propellant report), no handling; he heard the last two as a mortar being loaded (C17.5) |

**Correction at the round-17 close (2026-10-04, guns' read-only balance check, recorded by the orchestrator):** batch 5
settled late. Its row shows 35,394 → 35,158 (236), but batch 6 began at 34,878: a further 280 credits left between the
two with no request of ours, and 236 + 280 = 516, batch 5's dry-run estimate exactly. Batches 6 and 7 settled at their
estimates (183, 205). So **batch 5's true cost is 516 credits**, the round's sound spend is **2,879 credits** (not
2,599), and the balance after batch 7 is **34,490** (read again at the close: unchanged).
