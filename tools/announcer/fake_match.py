#!/usr/bin/env python3
"""Seeded fake matches for the announcer (K5 timelines; tests/announcer/fixtures/README.md).

    python3 tools/announcer/fake_match.py --scenario comeback --seed 3 > comeback.jsonl
    python3 tools/announcer/fake_match.py --all --out tests/announcer/fixtures

Not the game's simulation: a small abstract duel model with the roster's rock-paper-scissors (hit chance by target
speed, damage by armor), so timelines *read* like matches: contact, trades, streaks, friendly fire, close calls, a
result. Each scenario has a shape it must show (a comeback must be a comeback); the generator tries seeds from --seed
upward and keeps the first match that fits, so the same arguments always give the same file.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import events as contract  # noqa: E402

DT = 0.25
TIME_LIMIT = 300.0
MOMENTUM_EVERY = 5.0
CLOSE_CALL_HULL = 0.15
CLOSE_CALL_DELAY = 4.0
DAMAGE_REPORT_GAP = 3.0
COSTS = {"scout": 110, "tank": 200, "ifv": 150, "artillery": 220, "lancer": 200, "burner": 220}

# Per unit type: hull and shield points, weapon reload (s), damage per hit, base accuracy, and how hard it is to hit
# (evasion) and to hurt (armor). Numbers echo game/units/units.gd and game/combat/weapons.gd loosely; they only need
# to produce believable fights, and the matchups the design names (game_design.md "Starting roster").
STATS = {
    "scout": {"hull": 140, "shield": 80, "reload": 0.5, "damage": 11, "accuracy": 0.55, "evasion": 0.45, "armor": 0.0},
    "tank": {"hull": 300, "shield": 150, "reload": 3.5, "damage": 95, "accuracy": 0.6, "evasion": 0.0, "armor": 0.55},
    "ifv": {"hull": 220, "shield": 100, "reload": 1.2, "damage": 26, "accuracy": 0.7, "evasion": 0.15, "armor": 0.25},
    "artillery": {"hull": 200, "shield": 80, "reload": 4.5, "damage": 80, "accuracy": 0.35, "evasion": 0.0, "armor": 0.1},
    "lancer": {"hull": 200, "shield": 120, "reload": 2.4, "damage": 45, "accuracy": 0.8, "evasion": 0.05, "armor": 0.1},
    "burner": {"hull": 220, "shield": 100, "reload": 0.8, "damage": 20, "accuracy": 0.6, "evasion": 0.1, "armor": 0.2},
}
# Shooter type -> target types it prefers (good_vs in the roster).
PREFERS = {"scout": ["artillery", "lancer"], "tank": ["ifv", "tank"], "ifv": ["scout", "burner"],
           "artillery": ["tank", "artillery"], "lancer": ["tank"], "burner": ["scout", "ifv"]}
# Turret trackers miss fast targets; fixed guns and autocannons don't care as much.
TRACKING_PENALTY = {"tank": 1.0, "artillery": 1.0, "lancer": 0.3, "ifv": 0.1, "scout": 0.4, "burner": 0.5}
# Splash weapons near the front line: the base chance a shot lands on a teammate instead.
FRIENDLY_RISK = {"artillery": 0.035, "tank": 0.008, "burner": 0.02}


@dataclass
class Unit:
    id: str
    unit: str
    team: str
    squad: str
    hull: float
    shield: float
    max_hull: float
    reload_left: float = 0.0
    target: "Unit | None" = None
    low_since: float = -1.0
    close_call_done: bool = False
    last_damage_report: float = -99.0

    @property
    def alive(self) -> bool:
        return self.hull > 0


@dataclass
class Scenario:
    name: str
    blurb: str
    arena: str
    green: list  # [(squad name, [unit types])]
    rust: list
    edge: callable = None  # (t, match) -> {"green": multiplier, "rust": multiplier}
    friendly_scale: float = 1.0
    contact: tuple = (12.0, 20.0)
    control: bool = False
    hazard_rate: float = 0.0  # per second, per badly hurt unit (hull < 30%) during a fight: drives into a fire pit
    factions: tuple = ("condemned", "condemned")  # green, rust (K4 faction ids)
    fits: callable = None  # (events) -> bool
    notes: dict = field(default_factory=dict)


def even(_t, _m):
    return {"green": 1.0, "rust": 1.0}


def _deaths(events, team):
    return sum(1 for e in events if e["type"] == "unit_destroyed" and e["victim_team"] == team)


def _max_rust_lead(events):
    lead, best = 0, 0
    for e in events:
        if e["type"] == "unit_destroyed":
            lead += 1 if e["victim_team"] == "green" else -1
            best = max(best, lead)
    return best


def _end(events):
    return events[-1]


SCENARIOS = {
    "close_match": Scenario(
        "close_match", "Even armies trade all match; decided in the last seconds.", "foundry",
        green=[("Alpha", ["tank", "ifv", "ifv"]), ("Bravo", ["scout", "artillery"])],
        rust=[("Anvil", ["tank", "ifv", "scout"]), ("Lance", ["lancer", "ifv"])],
        fits=lambda ev: _end(ev)["winner"] != "draw" and sum(_end(ev)["units_left"].values()) <= 2
        and _end(ev)["duration_seconds"] >= 70 and _max_rust_lead(ev) >= 1 and _deaths(ev, "green") >= 3),
    "blowout": Scenario(
        "blowout", "One side outclasses the other quickly.", "scrapyard",
        green=[("Guns", ["tank", "tank", "tank"]), ("Eyes", ["scout"])],
        rust=[("Swarm", ["scout", "scout", "ifv"]), ("Battery", ["artillery", "artillery"])],
        edge=lambda t, m: {"green": 1.5, "rust": 0.7},
        fits=lambda ev: _end(ev)["winner"] == "green" and _end(ev)["units_left"]["green"] >= 3
        and _end(ev)["duration_seconds"] <= 90),
    "comeback": Scenario(
        "comeback", "Rust goes up by several units; Green claws back and wins.", "furnace",
        green=[("Alpha", ["tank", "ifv"]), ("Bravo", ["ifv", "scout", "scout"])],
        rust=[("Hammer", ["tank", "tank"]), ("Needle", ["lancer", "scout"])],
        edge=lambda t, m: {"green": 0.55 if t < m.contact_at + 25 else 1.9, "rust": 1.4 if t < m.contact_at + 25 else 0.6},
        fits=lambda ev: _end(ev)["winner"] == "green" and _max_rust_lead(ev) >= 2 and _deaths(ev, "rust") == 4),
    "friendly_fire_disaster": Scenario(
        "friendly_fire_disaster", "An artillery-heavy Rust army shells its own front line.", "scrapyard",
        green=[("Alpha", ["ifv", "ifv", "tank"]), ("Bravo", ["scout", "scout"])],
        rust=[("Front", ["tank", "ifv"]), ("Battery", ["artillery", "artillery"])],
        friendly_scale=5.0,
        fits=lambda ev: sum(1 for e in ev if e["type"] == "friendly_fire") >= 3
        and any(e["type"] == "unit_destroyed" and e["friendly"] for e in ev) and _end(ev)["winner"] == "green"),
    "scouts_vs_tanks": Scenario(
        "scouts_vs_tanks", "A Green scout swarm against a Rust tank wall.", "foundry",
        green=[("Wasps", ["scout", "scout", "scout"]), ("Hornets", ["scout", "scout", "scout"])],
        rust=[("Wall", ["tank", "tank", "tank"]), ("Spotter", ["ifv"])],
        contact=(8.0, 12.0),
        hazard_rate=0.02,
        fits=lambda ev: any(e["type"] == "unit_destroyed" and e["cause"] == "hazard" for e in ev)
        and _end(ev)["winner"] != "draw" and _end(ev)["kills_by_unit"]["green"].get("scout", 0) >= 2
        and _end(ev)["kills_by_unit"]["rust"].get("tank", 0) >= 2),
    "control_swing": Scenario(
        "control_swing", "The control point changes hands and decides the match.", "furnace",
        green=[("Alpha", ["tank", "ifv"]), ("Bravo", ["scout", "ifv"])],
        rust=[("Anvil", ["tank", "ifv"]), ("Dart", ["scout", "lancer"])],
        edge=lambda t, m: {"green": 0.6, "rust": 0.6},
        control=True,
        fits=lambda ev: _end(ev)["reason"] == "control"
        and sum(1 for e in ev if e["type"] == "control_changed") >= 3),
    # Factions are concept art this round (K4); these two let the booth's faction lines be read before they play.
    "gangs_vs_law": Scenario(
        "gangs_vs_law", "A road gang (Green) rushes the Law (Rust); the crowd boos the Law.", "scrapyard",
        green=[("Wreckers", ["scout", "scout", "ifv"]), ("Chrome", ["burner", "scout"])],
        rust=[("Precinct", ["tank", "ifv", "ifv"]), ("Spotlight", ["scout"])],
        factions=("gangs", "law"),
        fits=lambda ev: _end(ev)["winner"] == "green" and _deaths(ev, "green") >= 2),
    "syndicate_showcase": Scenario(
        "syndicate_showcase", "The Syndicate's few expensive hover units (Rust) against a Condemned army.", "foundry",
        green=[("Alpha", ["tank", "tank"]), ("Bravo", ["scout", "scout", "ifv"])],
        rust=[("Vesper", ["lancer", "lancer"]), ("Halo", ["artillery"])],
        factions=("condemned", "syndicate"),
        fits=lambda ev: _end(ev)["kills_by_unit"]["rust"].get("lancer", 0) >= 2 and _deaths(ev, "rust") >= 1),
}


class FakeMatch:
    CONTROL_POINTS_TO_WIN = 90
    CONTROL_CAPTURE_SECONDS = 8.0

    def __init__(self, scenario: Scenario, seed: int):
        self.scenario = scenario
        self.seed = seed
        self.rng = random.Random("%s:%d" % (scenario.name, seed))
        self.events: list = []
        self.units: list[Unit] = []
        self.t = 0.0
        self.contact_at = self.rng.uniform(*scenario.contact)
        self.first_contact_done = False
        self.kills = {"green": {}, "rust": {}}
        self.control_owner = "neutral"
        self.control_points = {"green": 0.0, "rust": 0.0}
        self.capture = {"team": "", "progress": 0.0}
        self.push = 0.0
        # Fights come in bursts: engaged windows with lulls between them (repositioning, flanking).
        self.lull_until = 0.0
        self.burst_until = 0.0
        for team, squads in (("green", scenario.green), ("rust", scenario.rust)):
            for squad, types in squads:
                for number, unit in enumerate(types, start=1):
                    stats = STATS[unit]
                    self.units.append(Unit("%s_%s_%d" % (team.capitalize(), squad, number), unit, team, squad,
                                           stats["hull"], stats["shield"], stats["hull"],
                                           reload_left=self.rng.uniform(0, stats["reload"])))

    # ---- output ----
    def emit(self, kind: str, **fields) -> None:
        tick = int(round(self.t * contract.TICKS_PER_SECOND))
        self.events.append({"tick": tick, "t": round(self.t, 2), "type": kind, **fields})

    def alive(self, team: str) -> list[Unit]:
        return [u for u in self.units if u.team == team and u.alive]

    def army_health(self, team: str) -> float:
        members = [u for u in self.units if u.team == team]
        return round(sum(max(u.hull, 0) / u.max_hull for u in members) / len(members), 3)

    # ---- the match ----
    def run(self) -> list:
        budget = 1000
        teams = []
        for team in ("green", "rust"):
            members = [u for u in self.units if u.team == team]
            budget = max(budget, -(-sum(COSTS[u.unit] for u in members) // 100) * 100)
            teams.append({"team": team, "faction": self.scenario.factions[0 if team == "green" else 1], "units": [{"id": u.id, "unit": u.unit, "squad": u.squad} for u in members]})
        self.emit("match_start", arena=self.scenario.arena, budget=budget, teams=teams, control_point=self.scenario.control,
                  fixture={"scenario": self.scenario.name, "seed": self.seed})
        next_momentum = MOMENTUM_EVERY
        while True:
            self.t = round(self.t + DT, 2)
            if self.t >= self.contact_at and self.engaged():
                self.fight()
                self.hazards()
            if self.scenario.control and self.t >= self.contact_at - 4:
                self.contest_control()
            self.check_close_calls()
            if self.t >= next_momentum:
                next_momentum += MOMENTUM_EVERY
                self.emit("momentum", army_health={t: self.army_health(t) for t in ("green", "rust")},
                          units_left={t: len(self.alive(t)) for t in ("green", "rust")})
            result = self.result()
            if result:
                self.emit("match_end", **result)
                return self.events

    def result(self) -> dict | None:
        left = {t: len(self.alive(t)) for t in ("green", "rust")}
        winner, reason = "", ""
        if left["green"] == 0 or left["rust"] == 0:
            winner = "draw" if left["green"] == left["rust"] else ("green" if left["green"] else "rust")
            reason = "elimination"
        elif max(self.control_points.values()) >= self.CONTROL_POINTS_TO_WIN:
            winner = max(self.control_points, key=self.control_points.get)
            reason = "control"
        elif self.t >= TIME_LIMIT:
            health = {t: self.army_health(t) for t in ("green", "rust")}
            winner = "draw" if health["green"] == health["rust"] else max(health, key=health.get)
            reason = "time"
        if not winner:
            return None
        return {"winner": winner, "reason": reason, "duration_seconds": round(self.t, 1), "units_left": left,
                "kills_by_unit": self.kills}

    def engaged(self) -> bool:
        if self.t < self.lull_until:
            return False
        if self.t >= self.burst_until:
            self.burst_until = self.t + self.rng.uniform(10.0, 22.0)
            if self.first_contact_done:
                self.lull_until = self.t + self.rng.uniform(4.0, 12.0)
                self.burst_until += self.lull_until - self.t
                return False
        return True

    def edge(self) -> dict:
        return (self.scenario.edge or even)(self.t, self)

    def pick_target(self, shooter: Unit) -> Unit | None:
        enemies = self.alive("rust" if shooter.team == "green" else "green")
        if not enemies:
            return None
        if shooter.target and shooter.target.alive and self.rng.random() < 0.85:
            return shooter.target
        preferred = [e for e in enemies if e.unit in PREFERS[shooter.unit]]
        pool = preferred if preferred and self.rng.random() < 0.7 else enemies
        return self.rng.choice(pool)

    def fight(self) -> None:
        shooters = [u for u in self.units if u.alive]
        self.rng.shuffle(shooters)
        for shooter in shooters:
            if not shooter.alive:
                continue
            shooter.reload_left -= DT
            if shooter.reload_left > 0:
                continue
            stats = STATS[shooter.unit]
            shooter.reload_left = stats["reload"] * self.rng.uniform(0.85, 1.25)
            target = self.pick_target(shooter)
            if target is None:
                continue
            shooter.target = target
            if not self.first_contact_done:
                self.first_contact_done = True
                self.emit("first_contact", team=shooter.team, unit_id=shooter.id, unit=shooter.unit,
                          target_id=target.id, target_unit=target.unit)
            risk = FRIENDLY_RISK.get(shooter.unit, 0.0) * self.scenario.friendly_scale
            friends = [u for u in self.alive(shooter.team) if u is not shooter]
            if friends and self.rng.random() < risk:
                self.hit(shooter, self.rng.choice(friends), stats["damage"] * self.rng.uniform(0.5, 1.0), weak_spot=False)
                continue
            evasion = STATS[target.unit]["evasion"] * TRACKING_PENALTY[shooter.unit]
            chance = stats["accuracy"] * (1.0 - evasion) * self.edge()[shooter.team] ** 0.5
            if self.rng.random() >= min(chance, 0.95):
                continue
            weak_spot = self.rng.random() < 0.1
            damage = stats["damage"] * self.rng.uniform(0.8, 1.2) * self.edge()[shooter.team] ** 0.5
            damage *= 1.0 if weak_spot else 1.0 - STATS[target.unit]["armor"] * (0.6 if shooter.unit in ("tank", "lancer", "artillery") else 1.0)
            self.hit(shooter, target, damage * (1.8 if weak_spot else 1.0), weak_spot)

    def hazards(self) -> None:
        for unit in self.units:
            if unit.alive and unit.hull / unit.max_hull < 0.3 and self.rng.random() < self.scenario.hazard_rate * DT:
                unit.hull = 0.0
                self.destroy(unit, None)

    def hit(self, shooter: Unit, victim: Unit, damage: float, weak_spot: bool) -> None:
        hull_before = victim.hull
        absorbed = min(victim.shield, damage * 0.6)
        victim.shield -= absorbed
        victim.hull = max(0.0, victim.hull - (damage - absorbed))
        lost = (hull_before - victim.hull) / victim.max_hull
        killed = not victim.alive
        friendly = shooter.team == victim.team
        hull = round(victim.hull / victim.max_hull, 3)
        shield = round(victim.shield / STATS[victim.unit]["shield"], 3)
        if friendly:
            self.emit("friendly_fire", shooter=shooter.id, shooter_unit=shooter.unit, victim=victim.id, victim_unit=victim.unit,
                      team=shooter.team, hull=hull, killed=killed)
        elif not killed:
            critical = weak_spot or lost >= 0.3
            if critical or self.t - victim.last_damage_report >= DAMAGE_REPORT_GAP and lost >= 0.1:
                victim.last_damage_report = self.t
                self.emit("damage", shooter=shooter.id, shooter_unit=shooter.unit, victim=victim.id, victim_unit=victim.unit,
                          hull=hull, shield=shield, critical=critical, amount=round(lost, 3), weak_spot=weak_spot,
                          face=self.rng.choice(["front", "front", "side", "rear"]))
        if killed:
            self.destroy(victim, shooter)
        elif victim.hull / victim.max_hull < CLOSE_CALL_HULL and victim.low_since < 0:
            victim.low_since = self.t

    def destroy(self, victim: Unit, killer: Unit | None) -> None:
        friendly = killer is not None and killer.team == victim.team
        self.emit("unit_destroyed", victim=victim.id, victim_unit=victim.unit, victim_team=victim.team,
                  killer=killer.id if killer else "", killer_unit=killer.unit if killer else "",
                  killer_team=killer.team if killer else "", friendly=friendly, cause="weapon" if killer else "hazard")
        if killer and not friendly:
            self.kills[killer.team][killer.unit] = self.kills[killer.team].get(killer.unit, 0) + 1
        squad = [u for u in self.units if u.team == victim.team and u.squad == victim.squad]
        if all(not u.alive for u in squad):
            self.emit("squad_wiped", team=victim.team, squad=victim.squad, units_lost=len(squad))

    def check_close_calls(self) -> None:
        for unit in self.units:
            if unit.alive and unit.low_since >= 0 and not unit.close_call_done and self.t - unit.low_since >= CLOSE_CALL_DELAY:
                unit.close_call_done = True
                self.emit("close_call", unit_id=unit.id, unit=unit.unit, team=unit.team, hull_left=round(unit.hull / unit.max_hull, 3))

    def contest_control(self) -> None:
        # A slow random walk decides who is pushing onto the point; a team with clearly more units there this second
        # advances its capture, and a capture needs CONTROL_CAPTURE_SECONDS of it.
        if abs(self.t - round(self.t)) > 1e-6:
            return
        self.push = max(-1.0, min(1.0, self.push + self.rng.gauss(0.0, 0.3)))
        share = {"green": 0.5 + 0.4 * self.push, "rust": 0.5 - 0.4 * self.push}
        presence = {t: sum(self.rng.random() < share[t] for _ in self.alive(t)) for t in ("green", "rust")}
        if abs(presence["green"] - presence["rust"]) >= 2:
            team = max(presence, key=presence.get)
            if self.control_owner != team:
                if self.capture["team"] != team:
                    self.capture = {"team": team, "progress": 0.0}
                self.capture["progress"] += 1.0
                if self.capture["progress"] >= self.CONTROL_CAPTURE_SECONDS:
                    self.emit("control_changed", owner=team, previous=self.control_owner)
                    self.control_owner = team
                    self.capture = {"team": "", "progress": 0.0}
        if self.control_owner in self.control_points:
            self.control_points[self.control_owner] += 1.0


def generate(name: str, seed: int, tries: int = 2000) -> list:
    scenario = SCENARIOS[name]
    for attempt in range(tries):
        events = FakeMatch(scenario, seed + attempt).run()
        if scenario.fits is None or scenario.fits(events):
            problems = contract.validate_timeline(events)
            if problems:
                raise AssertionError("generator broke the contract: %s" % problems[:3])
            return events
    raise RuntimeError("no seed in %d..%d fits scenario %s" % (seed, seed + tries - 1, name))


def write_jsonl(events: list, path: Path) -> None:
    path.write_text("".join(json.dumps(e, separators=(", ", ": ")) + "\n" for e in events))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--scenario", choices=sorted(SCENARIOS))
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--all", action="store_true", help="write every scenario to --out")
    parser.add_argument("--out", type=Path, help="output folder (with --all) or file")
    args = parser.parse_args(argv)
    if args.all:
        if not args.out:
            parser.error("--all needs --out")
        args.out.mkdir(parents=True, exist_ok=True)
        for name in SCENARIOS:
            events = generate(name, args.seed)
            write_jsonl(events, args.out / ("%s.jsonl" % name))
            end = events[-1]
            print("%-24s seed %-4d %5.1f s  %-5s by %-11s left %s  events %d" % (
                name, events[0]["fixture"]["seed"], end["duration_seconds"], end["winner"], end["reason"],
                end["units_left"], len(events)))
        return 0
    if not args.scenario:
        parser.error("pass --scenario NAME or --all")
    events = generate(args.scenario, args.seed)
    if args.out:
        write_jsonl(events, args.out)
    else:
        sys.stdout.write("".join(json.dumps(e) + "\n" for e in events))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
