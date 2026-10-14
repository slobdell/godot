#!/usr/bin/env python3
"""The statistics every judged bar in this project needs, in the standard library only (builder0's system python).

Round 30 (sizing). Every series here is PAIRED: the same (seed, start tick) grid run twice, once per arm, so the unit of
noise is the per-run paired difference d_i = arm_i - base_i, and every pass line is a statement about their sum, mean,
median or count. The functions below take those d_i (or their sd) and answer the four questions a bar must answer:

  how noisy is this probe        -> `paired_sd`, `paired_se_total`, `variance_components`
  how big an n decides an effect -> `n_paired`, `mde`, `fisher_min_n`, `mcnemar_min_n`
  where does the line go         -> `guard_line`, `false_pass_at_null`, `power_at`
  what does a count line mean    -> `binom_tail`, `fisher_exact`, `mcnemar_exact`, `sign_test`

Conventions. Effects, sds and lines are PER RUN unless a name says `total`. alpha is the false-pass rate (a treatment
that does nothing is called a gain, or a harm is called none), one-sided by default because every line in rounds 27-29 was
one-directional ("down >= 25 %", "not worse than base + X"). power is 1 - the false-fail rate at the effect the bar names.
"""
import functools
import math
import random
import statistics

Z_ALPHA_05 = 1.6448536269514722  # one-sided 5 %
Z_POWER_80 = 0.8416212335729143


# ---- normal distribution ---------------------------------------------------------------------------------------

def norm_cdf(z):
    return 0.5 * (1.0 + math.erf(z / math.sqrt(2.0)))


def norm_ppf(p):
    """Inverse normal CDF (Acklam's rational approximation, |error| < 1.2e-9)."""
    if not 0.0 < p < 1.0:
        raise ValueError("p must be inside (0, 1)")
    a = (-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02, 1.383577518672690e+02,
         -3.066479806614716e+01, 2.506628277459239e+00)
    b = (-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02, 6.680131188771972e+01,
         -1.328068155288572e+01)
    c = (-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00, -2.549732539343734e+00,
         4.374664141464968e+00, 2.938163982698783e+00)
    d = (7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00)
    plow = 0.02425
    if p < plow:
        q = math.sqrt(-2.0 * math.log(p))
        return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / \
               ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0)
    if p > 1.0 - plow:
        q = math.sqrt(-2.0 * math.log(1.0 - p))
        return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / \
               ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0)
    q = p - 0.5
    r = q * q
    return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q / \
           (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1.0)


# ---- paired noise ----------------------------------------------------------------------------------------------

def paired_sd(diffs):
    """sd of the per-run paired differences: the probe's noise, per run. 0.0 for fewer than two runs."""
    return statistics.stdev(diffs) if len(diffs) > 1 else 0.0


def paired_se_mean(diffs):
    return paired_sd(diffs) / math.sqrt(len(diffs)) if diffs else 0.0


def paired_se_total(diffs):
    """se of the SUM of the paired differences (what a 'crews 176 -> 177' or 'fast 881 -> 379' line compares)."""
    return paired_sd(diffs) * math.sqrt(len(diffs)) if diffs else 0.0


def acted(diffs, eps=1e-9):
    """The runs where the arms differ at all. A pair where the treatment never fired is byte-identical (the sim is
    deterministic per commit, seed, tick and flags) and contributes a 0 that is not noise but an equality."""
    return [d for d in diffs if abs(d) > eps]


def variance_components(groups):
    """One-way components of per-run paired differences grouped by seed: {seed: [d over ticks]}.

    Returns between-seed variance (of the true seed means), within-seed (tick) variance, the intraclass correlation,
    and the se of the grand mean for the layout as run against the same number of runs spread over more seeds, so a
    bar can say where the next run buys most. Method-of-moments (balanced ANOVA); unbalanced groups use the mean size.
    """
    groups = {k: v for k, v in groups.items() if len(v) > 0}
    k = len(groups)
    sizes = [len(v) for v in groups.values()]
    n = sum(sizes)
    if k < 2 or n <= k:
        return {"seeds": k, "runs": n, "between": 0.0, "within": paired_sd([d for v in groups.values() for d in v]) ** 2,
                "icc": 0.0, "se_as_run": paired_se_mean([d for v in groups.values() for d in v]), "alternatives": {}}
    grand = statistics.mean(d for v in groups.values() for d in v)
    means = {s: statistics.mean(v) for s, v in groups.items()}
    ss_within = sum((d - means[s]) ** 2 for s, v in groups.items() for d in v)
    ss_between = sum(len(v) * (means[s] - grand) ** 2 for s, v in groups.items())
    ms_within = ss_within / (n - k)
    ms_between = ss_between / (k - 1)
    m = statistics.mean(sizes)
    between = max(0.0, (ms_between - ms_within) / m)
    within = ms_within
    icc = between / (between + within) if (between + within) > 0 else 0.0

    def se_for(seeds, ticks):
        return math.sqrt(between / seeds + within / (seeds * ticks))

    alternatives = {}
    for seeds, ticks in ((k, int(round(m))), (n, 1), (max(1, n // 3), 3), (max(1, n // 2), 2)):
        if seeds * ticks <= n and seeds >= 1 and ticks >= 1:
            alternatives["%d seeds x %d ticks" % (seeds, ticks)] = se_for(seeds, ticks)
    return {"seeds": k, "runs": n, "between": between, "within": within, "icc": icc,
            "se_as_run": se_for(k, m), "alternatives": alternatives}


# ---- sizing ----------------------------------------------------------------------------------------------------

def n_paired(sd, effect, alpha=0.05, power=0.8, one_sided=True):
    """Smallest n of paired runs that detects a per-run effect `effect` with the probe's per-run sd `sd` at the
    given false-pass rate and power (normal approximation; n < 8 is rounded up to 8 to cover the t correction).
    Returns None when the effect is 0 (nothing decides a zero)."""
    if effect == 0:
        return None
    if sd == 0:
        return 1
    z_a = norm_ppf(1.0 - alpha) if one_sided else norm_ppf(1.0 - alpha / 2.0)
    z_b = norm_ppf(power)
    n = ((z_a + z_b) * sd / abs(effect)) ** 2
    return max(8, math.ceil(n)) if n > 2 else max(2, math.ceil(n))


def mde(sd, n, alpha=0.05, power=0.8, one_sided=True):
    """The minimal per-run effect that n paired runs detect at this alpha and power (the honest line for a guard)."""
    if n <= 0:
        return float("inf")
    z_a = norm_ppf(1.0 - alpha) if one_sided else norm_ppf(1.0 - alpha / 2.0)
    return (z_a + norm_ppf(power)) * sd / math.sqrt(n)


def guard_line(base_total, sd, n, k=Z_ALPHA_05, worse_is_up=True):
    """A guard 'not worse than base by more than X' on a TOTAL over n runs, sized by the noise: base + k * se_total.
    k = 1.645 is a 5 % false-fail rate on a treatment that changes nothing; k = 2 is ~2.3 %."""
    se = sd * math.sqrt(n)
    return base_total + k * se if worse_is_up else base_total - k * se


def false_pass_at_null(line_effect, sd, n):
    """A line of the form 'the arm moved by at least `line_effect` per run' read as a point threshold: how often a
    treatment that does NOTHING passes it (the sign is the direction that passes)."""
    if sd == 0:
        return 0.0 if line_effect != 0 else 1.0
    return 1.0 - norm_cdf(abs(line_effect) * math.sqrt(n) / sd)


def power_at(true_effect, line_effect, sd, n):
    """How often a treatment whose true per-run effect is `true_effect` passes a point-threshold line at
    `line_effect` (both signed the way the line reads, e.g. both negative for 'down >= 25 %')."""
    if sd == 0:
        return 1.0 if abs(true_effect) >= abs(line_effect) else 0.0
    return norm_cdf((abs(true_effect) - abs(line_effect)) * math.sqrt(n) / sd)


# ---- medians (bootstrap, paired) -------------------------------------------------------------------------------

def bootstrap_median_diff(base, arm, reps=4000, seed=30, level=0.90):
    """Resample run PAIRS and read median(arm) - median(base) each time. Returns (point, lo, hi, sd) with a
    central `level` interval: 0.90 central = a 5 % one-sided bound each way."""
    n = len(base)
    if n == 0 or n != len(arm):
        raise ValueError("paired medians need two equal, non-empty lists")
    rng = random.Random(seed)
    point = statistics.median(arm) - statistics.median(base)
    draws = []
    for _ in range(reps):
        idx = [rng.randrange(n) for _ in range(n)]
        draws.append(statistics.median(arm[i] for i in idx) - statistics.median(base[i] for i in idx))
    draws.sort()
    lo = draws[int((1.0 - level) / 2.0 * (reps - 1))]
    hi = draws[int((1.0 - (1.0 - level) / 2.0) * (reps - 1))]
    return point, lo, hi, statistics.pstdev(draws)


# ---- counts ----------------------------------------------------------------------------------------------------

def binom_pmf(k, n, p):
    return math.comb(n, k) * p ** k * (1.0 - p) ** (n - k)


def binom_tail(k, n, p):
    """P(X >= k) for X ~ Binomial(n, p)."""
    return sum(binom_pmf(i, n, p) for i in range(k, n + 1))


def binom_cdf(k, n, p):
    return sum(binom_pmf(i, n, p) for i in range(0, k + 1))


def fisher_exact(a, b, c, d):
    """2x2 table [[a, b], [c, d]] (rows = arms, columns = success/failure). Returns (two-sided p, one-sided p in the
    OBSERVED direction: the tail of row 1's success count on the side it fell). A bar's count line is always read in
    the direction the arm moved, so the one-sided p is the one the line quotes."""
    n = a + b + c + d
    row1 = a + b
    col1 = a + c

    def p_of(x):
        return math.comb(row1, x) * math.comb(n - row1, col1 - x) / math.comb(n, col1)

    lo, hi = max(0, col1 - (n - row1)), min(row1, col1)
    observed = p_of(a)
    two = sum(p for x in range(lo, hi + 1) for p in [p_of(x)] if p <= observed + 1e-12)
    expected = row1 * col1 / n
    if a >= expected:
        one = sum(p_of(x) for x in range(a, hi + 1))
    else:
        one = sum(p_of(x) for x in range(lo, a + 1))
    return min(1.0, two), min(1.0, one)


def mcnemar_exact(b, c):
    """Exact two-sided McNemar over the discordant pairs (b: arm won where base did not; c: the reverse)."""
    n = b + c
    if n == 0:
        return 1.0
    k = min(b, c)
    return min(1.0, 2.0 * binom_cdf(k, n, 0.5))


def sign_test(diffs):
    """One-sided exact sign test that the differences are negative (ties dropped). Returns (negatives, nonzero, p)."""
    nz = [d for d in diffs if d != 0]
    neg = sum(1 for d in nz if d < 0)
    return neg, len(nz), (binom_tail(neg, len(nz), 0.5) if nz else 1.0)


@functools.lru_cache(maxsize=None)
def _fisher_upper_crit(n, kb, alpha):
    """Smallest k_arm (of n) whose one-sided Fisher p against k_base = kb (of n) is <= alpha; n + 1 if none."""
    for ka in range(kb, n + 1):
        if ka / n > kb / n and fisher_exact(ka, n - ka, kb, n - kb)[1] <= alpha:
            return ka
    return n + 1


@functools.lru_cache(maxsize=None)
def fisher_min_n(p_base, p_arm, alpha=0.05, power=0.8, cap=400):
    """Smallest n PER ARM at which a two-arm count line (k_arm/n v k_base/n, Fisher one-sided) reaches `power`
    when the true rates are p_base and p_arm. Exact enumeration; None if not reached by `cap`."""
    if p_arm <= p_base:
        return None
    for n in range(2, cap + 1):
        pw = 0.0
        for kb in range(n + 1):
            pb = binom_pmf(kb, n, p_base)
            if pb < 1e-12:
                continue
            crit = _fisher_upper_crit(n, kb, alpha)
            if crit <= n:
                pw += pb * binom_tail(crit, n, p_arm)
        if pw >= power:
            return n
    return None


@functools.lru_cache(maxsize=None)
def _mcnemar_crit(m, alpha):
    """Smallest b (of m discordant) whose exact two-sided McNemar p is <= alpha; m + 1 if none."""
    for b in range(m, -1, -1):
        if mcnemar_exact(b, m - b) > alpha:
            return b + 1
    return 0


@functools.lru_cache(maxsize=None)
def mcnemar_min_n(q_for, q_against, alpha=0.05, power=0.8, cap=2000):
    """Smallest number of PAIRS at which an exact McNemar test reaches `power`, when a pair is discordant in the
    arm's favour with probability q_for and against it with q_against (the arrive series: cells the arm wins that
    the base loses). Exact over the discordant count m ~ Bin(n, q_for + q_against) and B | m ~ Bin(m, share)."""
    if q_for <= q_against:
        return None
    pd = q_for + q_against
    share = q_for / pd
    for n in range(4, cap + 1):
        pw = 0.0
        for m in range(0, n + 1):
            pm = binom_pmf(m, n, pd)
            if pm < 1e-12:
                continue
            crit = _mcnemar_crit(m, alpha)
            if crit > m:
                continue
            pw += pm * binom_tail(crit, m, share)
        if pw >= power:
            return n
    return None


def poisson_diff_sd(a, b):
    """sd of the difference of two independent counts read as Poisson (an episode count whose rows were not kept)."""
    return math.sqrt(a + b)
