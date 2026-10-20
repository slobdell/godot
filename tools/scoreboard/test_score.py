"""Known answers for tools/scoreboard/score.py (round 35, X5 (a)): one scoreboard folder written by hand, every number read
back. Run by tools/test_scoreboard.sh (so shell-tools-test carries it)."""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def death(cause, **kw):
    return "JAM_DEATH " + json.dumps(dict(cause=cause, **kw)) + "\n"


def census(teams):
    return "JAM_CENSUS " + json.dumps({"teams": teams}) + "\n"


def state(frame, unit, goal, x, z, order="move"):
    return "MANOEUVRE_STATE f %d %s drive order %s pace 1.0 goal %.1f real 0.50 at %.1f %.1f to 0 0\n" % (
        frame, unit, order, goal, x, z)


def squad_row(map_, n, route, arrived, far=False, twitch=None):
    r = {"map": map_, "squads": n, "route": route, "arm": "main", "arrived_s": arrived, "crossed": far, "deck": far,
         "shuffle_m": 0.0, "driven_m": 10.0, "plan_drive_m": 10.0, "anchor_offset_m": 1.0, "foreign_m": 5.0}
    if twitch is not None:
        r["twitch_m"] = twitch
    return "ORDERS_PROBE_SQUAD " + json.dumps(r) + "\n"


def build(root, with_twitch):
    # fights: one read (4 deaths: open, stuck, jam under fire by hit_in_jam, jam not under fire), one with no census
    write(os.path.join(root, "fights", "locks-1.log"), "".join([
        death("open:los"), death("stuck:wall"), death("jam:held", hit_in_jam=True, hits_10s=0),
        death("jam:held", hit_in_jam=False, hits_10s=1),
        census({"green": {"shots": 10, "hits": 4, "kills": 2}, "rust": {"shots": 30, "hits": 6, "kills": 2}})]))
    write(os.path.join(root, "fights", "sumps-1.log"), "crashed\n")
    # moves: one run, never settled, one crew 30 m off its slot, two movers at the judge (one closing, one rocking)
    run = os.path.join(root, "moves", "gangs", "faced_move-7")
    write(os.path.join(run, "screen.json"), json.dumps([{"squads": [{"squad": "A", "arrived": True, "each": [
        {"unit": "U1", "real_mps": 0.5}, {"unit": "U2", "real_mps": 0.4}, {"unit": "U3", "real_mps": 0.0}]}],
        "settled_after_s": -1.0}]))
    lines = []
    for i in range(0, 12):
        f = 300 + i * 30
        lines.append(state(f, "U1", 20.0 - i, float(i), 0.0))          # closing: goal 20 -> 9
        lines.append(state(f, "U2", 30.0, 0.1 * (i % 2), 0.0))          # jitter: rocks 0.1 m
    lines.append("ELEMENT_TRACE t=12.0 [move] id 1 U1 at (0.0,0.0) slot (30.0,0.0) 30.0 m off U2 at (1,1) slot (2,2) 1.4 m off\n")
    write(os.path.join(run, "run.log"), "".join(lines))
    # orders: locks 3 click over two seeds (one all in at 20 s, one never), crossing 3 click (all in at 30 s, a squad far)
    write(os.path.join(root, "orders", "locks-3-click-main-s1.log"),
          squad_row("locks", 3, "click", 12.0, twitch=1.0 if with_twitch else None)
          + squad_row("locks", 3, "click", 20.0, twitch=2.0 if with_twitch else None))
    write(os.path.join(root, "orders", "locks-3-click-main-s2.log"),
          squad_row("locks", 3, "click", -1.0, twitch=4.0 if with_twitch else None)
          + squad_row("locks", 3, "click", 15.0, twitch=0.5 if with_twitch else None))
    write(os.path.join(root, "orders", "crossing-3-click-main-s1.log"),
          squad_row("crossing", 3, "click", 30.0, far=True, twitch=3.0 if with_twitch else None))
    write(os.path.join(root, "run.txt"), ">> scoreboard-run on box | commit abc\n")


def score(root):
    out = subprocess.run([sys.executable, "-I", os.path.join(HERE, "score.py"), root, "--commit", "abc", "--machine", "box"],
                         capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def test_every_number():
    with tempfile.TemporaryDirectory() as root:
        build(root, True)
        row = score(root)
    f = row["fights"]
    assert (f["ran"], f["read"], f["deaths"], f["open"], f["stuck"], f["jam"], f["jam_under_fire"], f["kills"]) == \
        (2, 1, 4, 1, 1, 2, 1, 4)
    assert abs(f["hit_rate"] - 10 / 40) < 1e-9
    m = row["moves"]
    assert (m["ran"], m["read"], m["never_settled"], m["crews_left_behind"], m["squads"], m["squads_arrived"]) == (1, 1, 1, 1, 1, 1)
    assert m["movers"]["closing"] == 1 and m["movers"]["jitter"] == 1 and m["still_moving"] == 1
    assert m["per_task"]["faced_move"] == {"runs": 1, "never_settled": 1, "crews_left_behind": 1, "still_moving": 1, "jitter": 1}
    o = row["orders"]
    assert (o["ran"], o["read"], o["never_all_in"], o["far_bank_squads"]) == (3, 3, 1, 1)
    assert o["all_in_median_s"] == 25.0           # the runs all in: 20 and 30
    assert o["twitch_median_m"] == 3.0 and o["twitch_worst_m"] == 4.0   # per run worst: 2, 4, 3
    assert o["cases"]["locks 3 click"] == {"runs": 2, "all_in_median_s": 20.0, "never_all_in": 1, "far_bank": 0}
    assert row["commit"] == "abc" and row["machine"] == "box" and row["run"] == [">> scoreboard-run on box | commit abc"]


def test_an_older_main_without_twitch_reads_null_not_zero():
    with tempfile.TemporaryDirectory() as root:
        build(root, False)
        row = score(root)
    assert row["orders"]["twitch_median_m"] is None and row["orders"]["twitch_worst_m"] is None


def test_an_empty_folder_reads_nothing_and_never_a_zero_death_count():
    with tempfile.TemporaryDirectory() as root:
        row = score(root)
    assert row["fights"] == {"ran": 0, "read": 0}
    assert row["orders"] == {"ran": 0, "read": 0}
    assert row["moves"]["read"] == 0


def test_the_table_reads_per_fight_and_marks_what_is_missing():
    sys.path.insert(0, HERE)
    import table
    with tempfile.TemporaryDirectory() as raw, tempfile.TemporaryDirectory() as board:
        build(raw, False)
        os.makedirs(os.path.join(board, "rows"))
        with open(os.path.join(board, "rows", "abc.json"), "w") as f:
            json.dump(score(raw), f)
        with open(os.path.join(board, "mains.txt"), "w") as f:
            f.write("# comment\nabc old main\ndef new main\n")
        text = table.render(board)
    line = [l for l in text.splitlines() if l.startswith("| Tanks lost per fight")][0]
    assert line == "| Tanks lost per fight, any cause | 4 | not run | lower |", line
    assert "| Twitch after placing, median (metres a crew shuffles) | n/a | not run | lower |" in text
    assert "| Orders where some squad never got in (90 s) | 1 of 3 | not run | lower |" in text
    assert "| Hit rate | 25 % | not run |  |" in text
    assert "**old main**<br>`abc`" in text


if __name__ == "__main__":
    failed = 0
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            try:
                fn()
                print("  ok   " + name)
            except Exception as e:  # noqa: BLE001
                failed += 1
                print("  FAIL %s: %r" % (name, e))
    sys.exit(1 if failed else 0)
