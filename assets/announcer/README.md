# The announcer's text library

Owner: the announcer stream ([_agents/streams/announcer.md](../../_agents/streams/announcer.md)). Design:
[_agents/game_design.md](../../_agents/game_design.md) *The arena announcer* and its **humor direction**.

| File | What |
|---|---|
| `lines.json` | every line the booth can say, tagged; the text we'd send to ElevenLabs (lead gate: approved first) |
| `beats.json` | the grammar: what each moment is worth and the shapes a call can take |
| `transcripts/` | review transcripts: every fixture × director seeds 1 and 2 (`make announcer-transcripts`) |

## The voices

| Speaker | Who | Voice (ElevenLabs) | Writing rule |
|---|---|---|---|
| `caller` | play-by-play | `JR1` | authentic fight-night hype, played straight; he's this excited about armored buses |
| `color` | the Veteran, a former arena champion | not made yet | dry, slow, expert; understated; the dark past comes out flat |
| `pa` | Celeste Vance, arena PA and sponsor reads | `corporate2` | a believable professional; one detail is slightly off, buried mid-sentence, never a punchline |

## A line

```json
{"id": "caller.kill.18", "speaker": "caller", "act": "call", "tags": ["kill", "upset"], "intensity": 3,
 "text": "Are you kidding me? The {killer_unit} takes out the {victim_unit}!"}
```

| Field | Meaning |
|---|---|
| `id` | the clip id; never renumber or reuse once audio exists |
| `speaker`, `act` | who says it and what it does. caller: `hype call button interrupt setup_question stat reaction`; color: `analysis roast answer_agree answer_disagree callback prediction lore`; pa: `welcome notice sponsor_read result` |
| `tags` | **all** must be on the moment; one of them names the moment kind (below) or is `any` |
| `without` | none of these may be on the moment |
| `intensity` | 1 calm … 3 screaming; a line is used within ±1 of the moment's intensity (omit = any) |
| `topic` | setup questions and their answers pair by topic (`any` answers anything) |
| `sets` / `needs` | memory flags: a prediction sets `predicted_friendly_fire`; a callback needs it. The director also sets `said_<kind>_<team>` and `said_friendly_<team>` when a moment was actually called, so "again!" only follows a first time the audience heard |
| `unless_flags` | the line is skipped while any of these flags is set (only one "welcome to the Foundry" per intro: welcome lines set and exclude `welcomed`) |
| `text` | plain words, no digits or symbols; `{slots}` below |

**More specific lines win:** each matched tag beyond the moment kind multiplies a line's chance by 8, so a "first
blood" line beats a generic kill call, and a beat can `require` a tag outright.

## Moments (what the director notices) and their tags

| Kind | From | Tags it can carry |
|---|---|---|
| `intro` | match_start | `arena_<name>`, `control_point` |
| `army` | match_start, per team | `main_<unit>`, `all_same`/`all_<unit>`, `heavy`/`heavy_<unit>` (3+), `mixed`, `several` (2+ of the main unit) |
| `tape` | match_start (tale of the tape) | `outnumbers`, `even_numbers` |
| `preview` | match_start | `counter` (one army's main unit beats the other's), `mirror` |
| `contact` | first_contact | `unit_<unit>`, `target_<unit>` |
| `big_hit` | damage (critical and a weak spot, 30%+, or low hull) | `shooter_<unit>`, `victim_<unit>`, `weak_spot`, `rear`, `hurt` |
| `kill` | unit_destroyed by an enemy | `killer_<unit>`, `victim_<unit>`, `first_blood`, `counter`, `upset` (once per matchup), `mirror`, `streak` (3+ unanswered), `last_unit`, `final_kill`, `even`, `lead_change`, `comeback`, `weak_spot`, `rear`; the director adds `another` (same team, while the last kill is still being called), `flurry` and `trade` (kills that piled up merge) |
| `friendly_kill` | unit_destroyed by a teammate | `killer_<unit>`, `victim_<unit>`, `repeat`, `last_unit`, `final_kill` |
| `hazard_kill` | unit_destroyed by the arena | `victim_<unit>`, `last_unit`, `final_kill` |
| `friendly_fire` | friendly_fire (not fatal) | `shooter_<unit>`, `victim_<unit>`, `repeat` |
| `close_call` | close_call | `unit_<unit>`, `last_unit` |
| `control` | control_changed | `taken`, `stolen`, `neutral`, `again` (3+ changes) |
| `squad_wiped` | squad_wiped | |
| `momentum` | momentum (army health lead changes) | `edge`, `shift`, `rout` |
| `lull` | the director, when it's quiet | `waiting` (before contact), `level` |
| `result` | match_end | `win_elimination`/`win_control`/`win_time`, `draw`, `flawless`, `close`, `comeback`, `quick`, `long` |
| `outro` | match_end (after the result call) | same as result |

Every moment also carries `phase_early|mid|late|final|post`, and when it has a team: `team_green|rust`,
`team_leading|trailing|even` (by units alive), `faction_<id>` and `other_faction_<id>` (K4: `condemned`, `gangs`,
`law`, `syndicate`; army moments add `introduce`). While a beat runs, the line after another speaker's also sees
`after_caller|color|pa` ("Thank you, Celeste" needs `after_pa`).

## Slots

| Slot | Speaks | Example |
|---|---|---|
| `{team}` `{other_team}` | team names | Green, Rust |
| `{team_s}` `{other_team_s}` | possessive | Green's |
| `{unit}` `{killer_unit}` `{victim_unit}` `{target_unit}` | unit names | scout, IFV |
| `{units}` `{other_units}` | plural | scouts, IFVs |
| `{count}` `{other_count}` `{streak}` `{kills}` | number words | two |
| `{arena}` | arena names | the Foundry |

Never write "a {unit}" (it reads "a IFV"): use "the" or "that". The audit (`make announcer-audit`) checks this and more.

## Beats (`beats.json`)

Per moment kind: `priority` (what wins the queue; tags add `tag_priority`), `stale_s` (dropped if not started by then),
`cooldown_s`, `intensity` (plus `tag_intensity`), and `beats`: weighted shapes with `when`/`unless` tags. A step is
`{speaker, act (or list), chance?, optional?, answers?, require?}`. The first step of a beat is the call; later steps
are follow-ups that a new, bigger moment skips or cuts off.
