import json,re,sys
S=sys.argv[1]
LAP_TICK=25.0; BRAIN_SHARE=0.87
def lap(p): return f"~{p/100*LAP_TICK*BRAIN_SHARE:.1f} ms of 25"
def row(where,pct,se,n,lapms=True):
    return {"where":where,"pct":f"{pct:+.1f} % ± {se:.1f} ({n})","laptop":lap(pct) if lapms and pct>1.5 else "—"}
pend="pending"
champ={"shot":"6.8 ± 0.3 s","kill":"14.2 ± 0.8 s","kills":"28.1 ± 1.3"}
def beh(shot,kill,kills,thinks,ladder_small,ladder_big=pend,scen=pend):
    return [
      {"what":"First shot (16 Sumps seeds)","champ":champ["shot"],"lever":shot},
      {"what":"First kill","champ":champ["kill"],"lever":kill},
      {"what":"Kills in 120 s (both sides)","champ":champ["kills"],"lever":kills},
      {"what":"Thinks (16 matches)","champ":"399 532","lever":thinks},
      {"what":"Ladder v champion, small armies","champ":"—","lever":ladder_small},
      {"what":"Ladder v champion, your army size","champ":"—","lever":ladder_big},
      {"what":"Scenarios and battle drills","champ":"—","lever":scen},
      {"what":"A new order taken up (K1)","champ":"next tick","lever":"next tick"},
    ]
def his(rows,law_wins,law_kills,cond_kills):
    return [
      {"what":"YOUR setup: your Law on today's brain v the CPU's Condemned on the lever, Law wins of 16","champ":"3","lever":law_wins},
      {"what":"...kills by Condemned (your losses) a match","champ":"18.4","lever":cond_kills},
      {"what":"...kills by Law a match","champ":"9.7","lever":law_kills},
    ]+rows
def drive(rows,sumps_plant,sumps_steer,term_plant,term_steer):
    return rows+[
      {"what":"Sumps: long hulls rubbing walls on route, per min (6 seeds)","champ":"393","lever":sumps_steer},
      {"what":"Sumps: long hulls hitting walls in a 3-point turn, per min","champ":"47","lever":sumps_plant},
      {"what":"Terminus: rubbing walls on route, per min","champ":"369","lever":term_steer},
      {"what":"Terminus: hitting walls in a 3-point turn, per min","champ":"32","lever":term_plant},
    ]
L=[]
def stride_beh(shot,kill,kills,thinks,ladder,law_wins,law_kills,cond_kills,steer,plant):
    return [
      {"what":"YOUR setup: your Law on today's brain v the CPU's Condemned on the lever, Law wins of 16","champ":"3","lever":law_wins},
      {"what":"...kills by Condemned (your losses) a match","champ":"18.4","lever":cond_kills},
      {"what":"...kills by Law a match","champ":"9.7","lever":law_kills},
      {"what":"Ladder v today's brain at your army size (16 games; today's brain v its twin: 8–8)","champ":"—","lever":ladder},
      {"what":"Scenarios and battle drills (both sides on it, and CPU side only)","champ":"43 / 1 / 3, drills clean","lever":"the same (the 1 is a known old failure)"},
      {"what":"First shot, both sides on it (16 Sumps seeds)","champ":"6.8 s","lever":shot},
      {"what":"First kill","champ":"14.2 s","lever":kill},
      {"what":"Kills in 120 s (both sides)","champ":"28.1","lever":kills},
      {"what":"Thinks (16 matches)","champ":"399 532","lever":thinks},
      {"what":"Sumps: long hulls rubbing walls on route, per min (6 seeds; change on the same seed)","champ":"393","lever":steer},
      {"what":"Sumps: long hulls hitting walls in a 3-point turn, per min","champ":"47","lever":plant},
      {"what":"A new order taken up (K1)","champ":"next tick","lever":"next tick"},
    ]
L.append(dict(id="l17s",ready=False,closed_reason="Not offered: on your laptop it made no measurable difference.",name="Far units steer at half rate",
  what="A CPU unit with no enemy in reach and no order to carry out runs its whole controller every other tick (15 times a second instead of 30). Its hull keeps the last command and still moves every tick. It re-checks for enemies on every intel tick and returns to full rate the moment one comes into reach; a new order or a squad call runs it at once. Never your units.",
  price=[{"where":"Your Sumps now (turned containers), skirmish seed 92721","pct":"+20.4 % ± 4.9 (1 run, 51 units)","laptop":"~4 ms of 25"},{"where":"Your skirmish before the turn, 3 seeds (92721 / 31337 / 4242)","pct":"−2 to +19 % (12.3 / 19.3 / −1.8)","laptop":"0 to ~4 ms of 25 (mean ~2)"},{"where":"Sumps CPU v CPU (3 seeds)","pct":"+6.6 % ± 1.1","laptop":"—"}],
  behaviour=stride_beh("6.5 s","14.5 s","30.4","384 080 (−3.9 %)","10–6","3","11.4","17.8","before the turn: 596 (−2 paired); now: 493 (+37 paired, champion 514)","before: 23 (−8); now: 21 (−1)"),
  notice="On the Sumps you play now (turned containers): it saves 20 % of the brains in one run of your skirmish, and a CPU column rubs the containers about 7 % more often (+37 a minute on ~550), where before the turn it did not rub more at all. Most likely nothing else. A CPU column far from the fight corrects its line 15 times a second instead of 30, at a distance where you would not see it. It saves nothing in a fight where the CPU is in contact from the start (one of three seeds).",
  rec={"kind":"keep","label":"Withdrawn","why":"Withdrawn: on your laptop it made no measurable difference (two seeds, within ±1 ms of today's brain run twice). Builder0's earlier reading follows, for the record. No measured behaviour change after two defects were found and fixed: the same scenarios, drills, pace, ladder within its noise, your side no worse off. What it buys depends on how long the CPU spends away from the fight: nothing to about a fifth of the brains. The bundle below buys more."}))
L.append(dict(id="l17i1",name="Far, idle units think once a second",
  what="A CPU unit with no known enemy within 130 m, no order and no squad call waiting thinks once a second instead of 3.3 times. It wakes at once on a new order, a squad call, or an enemy coming near. Never your units.",
  price=[row("Your skirmish (51 units, 1 run)",4.28,1.83,"N=51 units paired"),row("Sumps CPU v CPU (3 seeds)",0.67,0.71,"N=3 seeds",False)],
  behaviour=beh("6.7 s","14.9 s","29.6","386 186 (−3.3 %)","7–9 (16 games)","9–7 (16 games, your army size; today v its twin: 7–7–2)","the same (on the turned Sumps tree; the 1 is a known old failure)"),
  notice="A CPU squad far from the fight reacts up to 1 s later to something new (0.3 s today). Anything that matters already wakes it at once.",
  rec={"kind":"keep","label":"Keep off","why":"The bundle that contains it made no measurable difference on your laptop, so this smaller part would not either. Was: worth about 4 % on your skirmish and nothing on the Sumps, where the armies meet in 4 s. Take it inside the bundle below rather than alone."}))
L.append(dict(id="l17c",name="Shortcut check at the end point",
  what="Before cutting a corner to its next waypoint, a unit checks the straight line at its end only instead of at its middle and its end. Applies to every unit, yours too.",
  price=[row("Your skirmish (51 units, 1 run)",4.52,2.57,"N=51 units paired"),row("Sumps CPU v CPU (3 seeds)",1.87,0.82,"N=3 seeds",False)],
  behaviour=beh("6.5 ± 0.2 s","13.5 ± 0.8 s","27.8 ± 1.3","408 300","8–8 (acted: 178 v 175 shots)","8–8 (16 games, your army size; today v its twin: 7–7–2)","the same (on the turned Sumps tree; the 1 is a known old failure)"),
  notice="Probably nothing. On the Sumps the middle check refused 0 of about 49 000 shortcuts; every refusal came from the end check, which stays. On a map with tighter corners a unit could clip a corner the middle check would have caught.",
  rec={"kind":"keep","label":"Keep off","why":"The bundle that contains it made no measurable difference on your laptop, so this smaller part would not either. Was: a small, steady saving on builder0 with no measured behaviour cost."}))
L.append(dict(id="l17k",name="Three-point-turn check every 12 ticks",
  what="A wheeled unit asks whether its next turn will meet a wall every 12 ticks instead of every 6 (0.4 s instead of 0.2 s). Applies to every wheeled unit, yours too.",
  price=[row("Your skirmish (51 units, 1 run)",0.87,2.22,"N=51 units paired"),row("Sumps CPU v CPU (3 seeds)",0.50,0.80,"N=3 seeds",False)],
  behaviour=beh("6.7 ± 0.3 s","14.2 ± 0.8 s","30.2 ± 1.8","405 620","no wheeled hull in the small armies: no information","10–6 (16 games, your army size; today v its twin: 7–7–2)","the same (on the turned Sumps tree; the 1 is a known old failure)"),
  notice="A wheeled vehicle starting a three-point turn could do it up to 0.2 s later, close to a wall.",
  rec={"kind":"keep","label":"Keep off","why":"Inside the noise in both workloads. Not worth any risk on its own."}))
L.append(dict(id="l17o",name="Avoidance against 4 neighbours",
  what="A unit steering around others considers its 4 nearest neighbours instead of 6. Every unit.",
  price=[row("Your skirmish (51 units, 1 run)",2.36,2.62,"N=51 units paired"),row("Sumps CPU v CPU (3 seeds)",-0.29,0.65,"N=3 seeds",False)],
  behaviour=beh("6.9 ± 0.4 s","14.1 ± 1.0 s","27.4 ± 1.7","407 976","no unit had 5+ neighbours in the small armies: no information","9–7 (16 games, your army size; today v its twin: 7–7–2)","the same (on the turned Sumps tree; the 1 is a known old failure)"),
  notice="More bumping in a tight crowd.",
  rec={"kind":"keep","label":"Keep off","why":"It buys nothing measurable: what avoidance saves comes back as untangling."}))
L.append(dict(id="l17i2",name="Far, idle units think twice a second",
  what="As 'once a second' above, at twice a second.",
  price=[row("Your skirmish (51 units, 1 run)",0.88,2.02,"N=51 units paired"),row("Sumps CPU v CPU (3 seeds)",-1.34,0.65,"N=3 seeds",False)],
  behaviour=beh("6.7 s","13.8 s","27.8","391 135 (−2.1 %)","no information (identical to the champion)","7–9 (16 games, your army size; today v its twin: 7–7–2)","the same (on the turned Sumps tree; the 1 is a known old failure)"),
  notice="A CPU squad far away reacts up to 0.5 s later to something new.",
  rec={"kind":"keep","label":"Keep off","why":"Inside the noise. The once-a-second version is the one with a price."}))
B=[]
B.append(dict(id="l17b2",ready=False,closed_reason="Not offered: on your laptop it made no measurable difference.",name="The bundle: all four that pay",
  what="Far units steer at half rate, far idle units think once a second, the shortcut check at the end point, and the three-point-turn check every 12 ticks, together. Your own units: the half-rate steering and once-a-second thinking never apply to them; the shortcut check and the turn check apply to every unit, yours included.",
  price=[{"where":"Your Sumps now (turned containers), skirmish seed 92721","pct":"+23.3 % ± 4.9 (1 run, 51 units)","laptop":"~5 ms of 25"},{"where":"Your skirmish before the turn, 3 seeds (92721 / 31337 / 4242)","pct":"+3.5 to +27 % (26.6 / 23.5 / 3.5)","laptop":"~1 to ~6 ms of 25 (mean ~4)"},{"where":"Sumps CPU v CPU (3 seeds)","pct":"+8.5 % ± 1.2","laptop":"—"}],
  behaviour=stride_beh("6.7 s","16.0 s","29.7","372 438 (−6.8 %)","6–10","4","13.1","17.6","before the turn: 540 (+40 paired); now: 524 (+11 paired, champion 514)","before: 40 (0); now: 32 (−18)"),
  notice="On your laptop: no saving at the same number of vehicles, and in the 4-minute run the CPU ended with 7 vehicles instead of 19 (it lost more units to you; one seed). Builder0's reading, for the record: on the Sumps you play now (turned containers) it saved 23 % of the brains in one run of your skirmish; a CPU column rubs the containers about 2 % more often (+11 a minute on ~550, down from about a tenth before the turn) and hits walls in three-point turns less. Otherwise most likely nothing. It saves little in a fight where the CPU is in contact from the start.",
  rec={"kind":"keep","label":"Withdrawn","why":"Withdrawn: on your laptop it made no measurable difference (two seeds, within ±1 ms of today's brain run twice). Builder0's earlier reading follows, for the record. Was: the tap I recommend. The biggest saving where you play (about 4 ms of your 25 ms tick on average, nothing to 6 ms depending on the fight), with no measured change in how the CPU fights: scenarios, drills, pace and the ladder all within today's spread, your side no worse off. Its one visible cost is a little more container rubbing on the Sumps."}))
B.append(dict(id="l17b1",ready=False,name="The bundle without half-rate steering",
  what="Far idle units think once a second, the shortcut check at the end point, and the three-point-turn check every 12 ticks.",
  price=[row("Your skirmish (51 units, 1 run)",5.44,2.74,"N=51 units paired"),row("Sumps CPU v CPU (3 seeds)",4.28,0.76,"N=3 seeds",False)],
  behaviour=beh("not measured","not measured","not measured","not measured","—","not measured at your army size (round 18)","not measured (round 18)"),
  notice="As its parts: barely anything.",
  rec={"kind":"keep","label":"Keep off","why":"The cautious option if you do not want half-rate steering. It buys about a fifth of what the full bundle buys."}))
data=dict(
 lede="Final answer: none of these levers is worth turning on. Measured on your laptop while you slept, the bundle and half-rate steering did not lower your tick at the same number of vehicles, in the first minute (two seeds) or over a 4-minute run (one seed, today's brain run twice to bracket it). The levers did act, skipping about 68 CPU controller ticks a second, but in a live fight the CPU is mostly within reach of your army, and most of the idle time they save comes after the match is already decided. On the 4-minute run the bundle also changed how the match went: the CPU ended with 7 vehicles instead of 19. Every lever stays off.",
 strip=[{"big":"no saving","small":"on your laptop, at the same number of vehicles, with the bundle or half-rate steering: first minute (two seeds) and a 4-minute run (one seed)"},
        {"big":"0","small":"levers on, and none recommended: every lever stays off"},
        {"big":"after","small":"most of the far-and-idle time the levers save comes AFTER the match is decided, when CPU survivors sit idle"},
        {"big":"changed","small":"the bundle changed how the 4-minute match went: the CPU kept 7 vehicles instead of 19 (one seed)"}],
 levers=L, bundles=B,
 method="""<p><b>Which map each row is on.</b> A row that says "now" or "turned Sumps" was measured on the Sumps you play tonight (turned containers); every other row was measured before the containers were turned (round 17's start). Cost is measured <i>inside one run</i>: the lever is on for half the units and off for the other half in the same ticks, the halves swap every 90 or 300 ticks, and each unit is compared with itself (its time per tick with the lever on against with it off). The ± is that comparison's standard error; N says over what (units paired in one run, or seeds). A <b>null control</b> (the same split with no lever) reads +2.3 ± 2.5 % on your skirmish and −0.3 ± 0.8 % on the Sumps, so the instrument reads zero when nothing changes.</p>
<p><b>Your skirmish</b> is perf-play's setup (your window, your flags, Law against Condemned on the Sumps, about 51 units) on builder0 with a display. <b>Sumps CPU v CPU</b> is a headless 180 s match, 50 vehicles, seeds 92721, 4242 and 5151, pinned to builder0's fast cores. The armies meet in about 4 s there, so far-and-idle levers have little to act on; on your skirmish the CPU spends two thirds of its time far from any fight.</p>
<p><b>Your laptop, the 4-minute run (measured 09:58–10:10, you away; seed 92721; today's brain, the bundle, today's brain again):</b> today's brain ran 18.7 and 20.4 ms of tick script time over the whole run (the same fight, 1.7 ms apart, so the bracket is wider than the ±1 ms the first-minute runs showed); the bundle 14.6 ms, but in a different fight with fewer vehicles alive (16.8 on average against 25.2). At equal counts there is nothing: at 30 vehicles today's brain 25.1 / 26.5 ms, the bundle 27.4 ms at 30 and 25.0 at 26. Per vehicle alive, the brains' controllers cost 0.60 / 0.66 ms with today's brain and 0.65 ms with the bundle. The stride acted (68.4 skipped controller ticks a second, none on your side); today's brain was far and idle 49.9 % of the time, most of it after your defeat at ~132 s, when the CPU's survivors sit still.</p>
<p><b>Your laptop, the first minute (measured 03:07–03:27, you asleep):</b> tick script time at ~30 vehicles, today's brain twice 26.1 / 27.0 and 26.4 / 26.3 ms (seeds 92721 / 31337), half-rate steering 26.5 / 25.8, the bundle 26.8 / 26.4: all inside the two runs of today's brain. Builder0 on the same command line: the stride skipped ~64–67 CPU controller ticks a second; the brains' controllers are ~80 % of the tick's script time on your path; the tick moved by 0.1–1.2 ms.</p>
<p><b>Builder0's earlier projections</b> (kept for the record; they did not hold on your laptop's first minute) from builder0's in-run paired A/B (about 51 units each, % of the brains' controller time, three skirmish seeds, the fixed version: half-rate steering 12.3 / 19.3 / −1.8 %, the bundle 26.6 / 23.5 / 3.5 %, null control on the same harness ±2 %) onto the laptop's 25 ms tick at 30 vehicles (~87 % brains). The seeds differ by how long the CPU spends away from the fight: on seed 4242 its army is in contact 85 % of the time and nothing is saved. The orchestrator will measure them on your laptop in a quiet window. The locked-30 count assumes the tick scales with vehicles and that 10 held at round 16's launch (about 11 after round 16's 9 %).</p>
<p><b>Two defects found and fixed.</b> The half-rate steering first lost a cover fight (a unit noticed its enemy one tick late) and then sent a unit carrying an order 70 m out of its formation slot. Both were caught by the scenario tests and fixed; every number for it on this page was taken after both fixes (commit 6a926d4b, check green, today's game unchanged with the levers off).</p>
<p><b>Your Sumps changed tonight.</b> Every row here was measured before the containers were turned (round 17's start); one arm on the current map is now on the two open cards. From tonight the Sumps you play has containers turned 4–6°, and long hulls already rub them more there (yard's count: 449 to 583 a minute). On it the saving holds (20 % and 23 %, one run each; the three-run range is still from before the turn). The turned containers make the half-rate steering rub MORE than before (about 7 %, where it was none) and the bundle LESS (about 2 %, where it was a tenth).</p>
<p><b>Driving</b>: War Rigs (14 m) and Condemned tanks, 6 seeds a map, counted the way yard counts wall contacts; "paired" is the change on the same seed.</p>
<p><b>Behaviour</b>: 16 Sumps seeds named before the first run, both sides on the lever; the champion's arm ran twice and came out byte-identical. Ladders play each lever against the champion, every seed four ways.</p>""",
 foot="Tank Squad · brains stream, round 17 · numbers in _agents/streams/brains.md Status · page data last updated "+__import__("datetime").datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %Z"))
html=open(S+"/brains-levers.html").read()
payload="/*DATA*/"+json.dumps(data,ensure_ascii=False).replace("</","<\/")+"/*END*/"
html=re.sub(r"/\*DATA\*/.*?/\*END\*/",lambda m: payload,html,flags=re.S)
open(S+"/brains-levers.html","w").write(html)
print("ok",len(html))
