# External research: the raw material

These three files are **primary sources, kept verbatim**. They are not the plan. The plan — what we adopt, in
what order, on whose evidence — is [`../research_catalog.md`](../research_catalog.md), and **that file is the
authority**. These exist so anyone can check the curation against what was actually said.

| File | What it is |
|---|---|
| `brief.md` | The research brief the orchestrator wrote and the lead approved, 2026-09-19. Sent to two external planning services. Abstract by instruction — no product names, no repository access, a proprietary boundary assumed. Originally written to `/tmp/prompt.md`, which does not survive a reboot; this is the copy of record |
| `response_a_verbatim.md` | Service A's reply. ~10,200 words. 30 named techniques across 11 areas, plus a formal strategy-space audit, an architecture tournament, a per-pathology derivation, and five evaluation metrics. **Mathematics in readable LaTeX** |
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
