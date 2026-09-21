# External research: the raw material

These three files are **primary sources, kept as close to verbatim as this machine allows**. They are not the plan.

> **⚠ One redaction, applied automatically, recorded here because a file that CLAIMS to be verbatim and is not is
> worse than one that says what changed.** A commit hook on this machine rewrites the name of a third-party tool:
> in `response_a_verbatim.md`, six occurrences of the service's own engine name were replaced with
> **`external audit`**. It reads oddly in places as a result — *"Running `external audit audit_space`"* is the hook's
> output, not the service's prose. **Nothing technical was altered**: no reference, number, formula, technique or
> verdict is affected, and the substitution is confined to that one tool name. The unmodified original is on the
> lead's Desktop at `~/Desktop/response_synth.md` if a byte-exact copy is ever needed.
>
> Noticed because the hook **amended a commit after it was made** and `main`'s tip hash stopped matching what the
> commit had reported — which is its own small lesson: *a hook that edits content on commit makes the file you
> reviewed and the file you shipped two different files.* The plan — what we adopt, in
what order, on whose evidence — is [`../research_catalog.md`](../research_catalog.md), and **that file is the
authority**. These exist so anyone can check the curation against what was actually said.

| File | What it is |
|---|---|
| `brief.md` | The research brief the orchestrator wrote and the lead approved, 2026-09-19. Sent to two external planning services. Abstract by instruction — no product names, no repository access, a proprietary boundary assumed. Originally written to `/tmp/prompt.md`, which does not survive a reboot; this is the copy of record |
| `response_a_verbatim.md` | Service A's reply. ~10,200 words. 30 named techniques across 11 areas, plus a formal strategy-space audit, an architecture tournament, a per-pathology derivation, and five evaluation metrics. **Mathematics in readable LaTeX** |
| `brief2.md` | The second brief, 2026-09-20 evening: sixteen abstract questions written from round 9's negative results (the seam, the yaw freeze, articulation, clearance, the player's order, balance under rescaling, lighting, commentary, hygiene). Sent by the lead to the same service that produced Service A's style of reply |
| `response2_verbatim.md` | The reply to `brief2.md`, ~7,000 words, ten sections mirroring the brief plus a composition-hazard table. **Verbatim except that it carries the same mid-sentence truncations as the first replies** (at least five: a falsifier line that reads "Met time", "attributarchitectural", "passain", "parametan", "Htic banality"); nothing load-bearing is lost, and where a sentence reads as nonsense it is truncation. Its falsifier NUMBERS (85 %, 90 %, 6.5 s, 35 %) are the service's proposals, not our bars: the catalog's round-10 addendum sets ours |
| `response_b_verbatim_images_stripped.md` | Service B's reply. ~8,250 words, ~20 named techniques. **The original (`~/Desktop/response_g.md`, 451 KB) carries every formula as an embedded base64 PNG — 191 of them, 387 KB of the file.** This copy is the text with those payloads removed, so it is readable and greppable and **all of its mathematics is missing.** The original stays on the lead's Desktop; it is not in the repo because 387 KB of base64 in version control buys us nothing we can read |

## Three cautions for anyone reading the sources

1. **Neither service has seen this repository.** Both reason only from `brief.md`. Every architectural claim
   about our code is an inference from our own prose, and where the prose was loose the inference is loose.
2. **Numbers in these files are not measurements.** Service A reports a satisfiability audit (counts of valid
   technique combinations) and an Elo tournament between candidate architectures. Neither could have been run
   against our simulation. Treat those figures as *arguments*, never as evidence, and never relay them to the
   lead as results. The reasoning is usable; the digits are not.
3. **Both files contain mid-sentence truncation.** Service A in roughly six places, Service B in seven or
   more — a cost line becomes `"takes $<the simulation by 70-85%"`, a determinism line stops mid-word. Nothing
   load-bearing was lost, but **if a sentence reads as nonsense it is corruption, not a subtlety.** The
   catalogue's rows are reconstructed from context and marked where that was necessary.
