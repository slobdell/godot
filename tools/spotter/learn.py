#!/usr/bin/env python3
"""Spotter S6: a learned ranker from his labels, compared with S2's hand ranker on held-out labels. Dev tooling; never ships.

    python3 tools/spotter/learn.py LABELS.json [LABELS2.json ...]
        each file: the judging page's db exported by the session ({"clips": [...], "labels": [...]}; tools/spotter/labels.py),
        where every clip carries its moment's `surprise_max` / `signals_max` / `length_s` / `choice` (rank.py since batch 2;
        batch 1's are rebuilt from ~/spotter-work/batch1/fights/moments.json by the same rank code: identical top 30)

The model is a small logistic regression (stdlib, L2, gradient descent) over: each signal's peak rarity (11), log2 length, and the
brain's choice (RETREAT / HOLD / MOVE / FOLLOW / ENGAGE / SPOT / other). With a few hundred labels a GPU buys nothing; a frame-based
model (clip pixels) is the GPU's job, and only worth trying if this one plateaus. Verdicts used: dumb = 1, fine = 0; "can't tell"
is left out. Evaluation: K-fold (default 5, stratified by seed so a fight never sits in train and test both) AUC and precision at
the top 10 / 30 % of each held-out fold, the learned score v the hand score. It prints which features the model leans on.
"""
import argparse
import json
import math
import random
import sys

SIGNALS = ["noprog_s", "wall_s", "friend_s", "reverse_s", "wrongway_s", "holdfire_s", "rearfire_s", "outranged_s", "idlehit_s",
           "spread_m", "spin_dps"]
CHOICES = ["RETREAT", "HOLD", "MOVE", "FOLLOW", "ENGAGE", "SPOT"]
NAMES = [f"rare:{s}" for s in SIGNALS] + ["log2_len"] + [f"choice:{c}" for c in CHOICES] + ["choice:other"]


def vector(clip):
    sur = clip.get("surprise_max", {})
    x = [float(sur.get(s, 0.0)) for s in SIGNALS]
    x.append(math.log2(max(float(clip.get("length_s", 1)), 1.0)))
    choice = str(clip.get("choice", "")).split(" ")[0]
    x += [1.0 if choice == c else 0.0 for c in CHOICES] + [0.0 if choice in CHOICES else 1.0]
    return x


def fit(xs, ys, l2=0.05, steps=3000, rate=0.1):
    n, d = len(xs), len(xs[0])
    mean = [sum(x[j] for x in xs) / n for j in range(d)]
    std = [max(math.sqrt(sum((x[j] - mean[j]) ** 2 for x in xs) / n), 1e-6) for j in range(d)]
    zs = [[(x[j] - mean[j]) / std[j] for j in range(d)] for x in xs]
    w, b = [0.0] * d, 0.0
    for _ in range(steps):
        gw, gb = [l2 * wj for wj in w], 0.0
        for z, y in zip(zs, ys):
            p = 1.0 / (1.0 + math.exp(-max(-30.0, min(30.0, b + sum(wj * zj for wj, zj in zip(w, z))))))
            for j in range(d):
                gw[j] += (p - y) * z[j] / n
            gb += (p - y) / n
        w = [wj - rate * g for wj, g in zip(w, gw)]
        b -= rate * gb
    return lambda x: b + sum(wj * (xj - m) / s for wj, xj, m, s in zip(w, x, mean, std)), w


def auc(scores, ys):
    pos = [s for s, y in zip(scores, ys) if y == 1]
    neg = [s for s, y in zip(scores, ys) if y == 0]
    if not pos or not neg:
        return float("nan")
    wins = sum(1.0 if p > q else 0.5 if p == q else 0.0 for p in pos for q in neg)
    return wins / (len(pos) * len(neg))


def precision_at(scores, ys, share):
    order = sorted(range(len(ys)), key=lambda i: -scores[i])
    k = max(1, int(round(share * len(ys))))
    return sum(ys[i] for i in order[:k]) / k


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("labels", nargs="+")
    ap.add_argument("--folds", type=int, default=5)
    args = ap.parse_args()
    rows = []
    for path in args.labels:
        data = json.load(open(path))
        verdict = {l["clip"]: l.get("verdict") for l in data["labels"]}
        for clip in data["clips"]:
            v = verdict.get(clip["id"])
            if v in ("dumb", "fine"):
                rows.append((clip, 1 if v == "dumb" else 0))
    if len(rows) < 20:
        sys.exit(f"learn: {len(rows)} decided labels; S6 waits for a few hundred (the brief), and needs 20 to say anything")
    seeds = sorted({c["seed"] for c, _ in rows})
    random.Random(7).shuffle(seeds)
    fold_of = {s: i % args.folds for i, s in enumerate(seeds)}
    learned, hand, ys = [], [], []
    for k in range(args.folds):
        train = [(c, y) for c, y in rows if fold_of[c["seed"]] != k]
        test = [(c, y) for c, y in rows if fold_of[c["seed"]] == k]
        if not test or len({y for _, y in train}) < 2:
            continue
        score, _ = fit([vector(c) for c, _ in train], [y for _, y in train])
        learned += [score(vector(c)) for c, _ in test]
        hand += [float(c["score"]) for c, _ in test]
        ys += [y for _, y in test]
    print(f"learn: {len(rows)} decided labels ({sum(y for _, y in rows)} dumb), {len(seeds)} seeds, {args.folds}-fold by seed")
    print(f"  AUC        learned {auc(learned, ys):.3f}   hand {auc(hand, ys):.3f}")
    for share in (0.1, 0.3):
        print(f"  prec@{int(share * 100):2d}%   learned {precision_at(learned, ys, share):.2f}   hand {precision_at(hand, ys, share):.2f}")
    _, w = fit([vector(c) for c, _ in rows], [y for _, y in rows])
    print("  weights (all labels, standardised; + leans dumb):")
    for name, wj in sorted(zip(NAMES, w), key=lambda t: -abs(t[1]))[:10]:
        print(f"    {name:18s} {wj:+.2f}")


if __name__ == "__main__":
    main()
