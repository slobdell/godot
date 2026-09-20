"""A12: the four trajectory-space metrics (`_agents/metrics.md` is the one-page reference).

Round 8 measured time-allocation while the lead's complaint was about the SHAPE of the motion. These four read
the shape, from positions, off a trajectory log (FORMAT.md):

  1. windowed displacement efficiency   net displacement / path length on a 4 s sliding window
  2. signed cusp density                sign changes of the along-body velocity, per agent-minute
  3. spectral arc length (SPARC)        Balasubramanian et al. (2012/2015); more negative = jerkier
  4. affine formation residual          Zhao (2018); zero for any affine deformation of the nominal shape

Pure Python 3, no third-party dependency — including the FFT — so the number is identical on the laptop and on
builder0. Every function refuses (returns a stated `refused` count) rather than silently returning zero for a
sample too short to answer.
"""

from __future__ import annotations

import cmath
import math
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence, Tuple

from trajlog import Sample, TrajectoryLog

# ---- Constants. Every one of these is a definition, not a tuning knob. ------------------------

## The window over which "is it getting anywhere" is asked. arena's `WINDOW_S`, kept verbatim so the round-8
## threshold is a special case of the continuous metric rather than a different measurement.
WINDOW_S = 4.0
## Round 8's `oscillating` threshold, kept verbatim (`fight_probe.gd` OSCILLATE_PATH_M / OSCILLATE_RATIO).
OSCILLATE_PATH_M = 8.0
OSCILLATE_RATIO = 0.25
## A goal that jumps further than this is a different goal: reset the window (`fight_probe.gd` GOAL_MOVED_M).
GOAL_MOVED_M = 3.0
## "Not arrived" (`fight_probe.gd` AT_GOAL_M): the gate on round 8's under-way denominator.
AT_GOAL_M = 8.0

## Cusp: a sign change of the along-body velocity with both sides above this speed. `fight_probe.gd` GEAR_SPEED,
## kept so cusp density is comparable with round 8's gear-flip counter.
CUSP_SPEED_MPS = 0.5

## SPARC: a FIXED window and a FIXED transform length, because a number that changes with the run length or with a
## threshold crossing cannot be compared between two runs. 256 samples is 8.53 s at 30 Hz.
##
## NO ZERO PADDING, and a Hann taper before the transform. Both are forced on us by the fact that our windows are
## arbitrary slices of an ongoing drive, not the rest-to-rest movements the reference is written for. A slice that
## does not begin and end at zero has a step discontinuity against its own periodic extension (or against the pad),
## and the sidelobes of that step swamp the spectrum: the first version of this file zero-padded x8 and scored a
## unit driving at a DEAD CONSTANT SPEED as jerkier than a square wave, because it was measuring the window edge.
## The taper removes the edge; N = W keeps every bin exact, so a constant profile's spectrum is the Hann kernel
## (1, 0.5, 0, 0, ...) on paper and the known answers are hand-computable rather than pinned to a first run.
SPARC_WINDOW_SAMPLES = 256
SPARC_NFFT = 256
## Fixed cutoff, in rad/s. The reference's adaptive cutoff (the last bin above an amplitude threshold) makes the
## answer depend on where a spectrum happens to cross 0.05, which is exactly the kind of number that differs
## between two runs for no behavioural reason.
SPARC_CUTOFF_RAD_S = 20.0
## A window whose speed profile sums to less than this (m/s, summed over samples) is a parked unit: its normalised
## spectrum is 0/0. Refused and counted, never reported as a value.
SPARC_MIN_DC = 1e-6

## An affine fit in 2-D has 6 parameters and 3 points determine it exactly, so a 3-unit element's residual is
## identically zero and would read as a perfect formation. Report 4 and up.
FORMATION_MIN_MEMBERS = 4


def window_samples(tick_rate: int, seconds: float = WINDOW_S) -> int:
    """The window in ticks. int() to match `fight_probe.gd`'s `int(WINDOW_S * SimClock.TICK_RATE)`."""
    return int(seconds * tick_rate)


def _flat(a: Sample, b: Sample) -> float:
    return math.hypot(a.x - b.x, a.z - b.z)


# ---- 1. Windowed displacement efficiency -------------------------------------------------------


@dataclass
class EfficiencySummary:
    """The continuous metric: every unit, every contiguous window, ungated."""

    windows: int = 0
    total: float = 0.0
    values: List[float] = field(default_factory=list)
    ## Windows whose path length is ~0: efficiency is 0/0. Counted, never averaged in.
    refused_zero_path: int = 0
    ## Windows that could not be formed because the unit's ticks are not contiguous.
    gaps: int = 0

    @property
    def mean(self) -> Optional[float]:
        return self.total / self.windows if self.windows else None

    def quantile(self, q: float) -> Optional[float]:
        """Nearest-rank quantile: no interpolation, so the answer is one of the measured values."""
        if not self.values:
            return None
        ordered = sorted(self.values)
        index = min(len(ordered) - 1, max(0, int(math.ceil(q * len(ordered))) - 1))
        return ordered[index]

    def merge(self, other: "EfficiencySummary") -> None:
        self.windows += other.windows
        self.total += other.total
        self.values.extend(other.values)
        self.refused_zero_path += other.refused_zero_path
        self.gaps += other.gaps


def displacement_efficiency(samples: Sequence[Sample], span: int) -> EfficiencySummary:
    """net displacement / path length over every contiguous `span`-sample window. 1.0 = straight; 0 = back where
    it started. A window never spans a tick gap: absence is not a straight line."""
    out = EfficiencySummary()
    if span < 2:
        raise ValueError("a displacement window needs at least 2 samples, got %d" % span)
    window: List[Sample] = []
    path = 0.0
    for sample in samples:
        if window and sample.tick != window[-1].tick + 1:
            out.gaps += 1
            window = []
            path = 0.0
        if window:
            path += _flat(window[-1], sample)
        window.append(sample)
        if len(window) > span:
            path -= _flat(window[0], window[1])
            window.pop(0)
        if len(window) == span:
            if path <= 1e-12:
                out.refused_zero_path += 1
                continue
            efficiency = _flat(window[0], window[-1]) / path
            out.windows += 1
            out.total += efficiency
            out.values.append(efficiency)
    return out


@dataclass
class OscillationSummary:
    """Round 8's `oscillating_share`, re-implemented from positions.

    The gating is `fight_probe.gd`'s, verbatim, because the point of a positive control is to reproduce a number
    and not to compute a better one: only ticks under orders and further than AT_GOAL_M from the goal count; the
    window resets when the goal jumps; and **the denominator is every such tick**, including the ones whose window
    is not yet full. Change any of those three and the share moves for reasons that are not behaviour.
    """

    under_way_ticks: int = 0
    oscillating_ticks: int = 0
    windows: int = 0
    path_m: float = 0.0
    net_m: float = 0.0
    oscillating_windows: int = 0
    units_that_ever_oscillated: int = 0

    @property
    def share(self) -> float:
        return self.oscillating_ticks / max(1.0, float(self.under_way_ticks))

    @property
    def net_over_path(self) -> Optional[float]:
        return self.net_m / self.path_m if self.path_m > 0 else None

    def merge(self, other: "OscillationSummary") -> None:
        self.under_way_ticks += other.under_way_ticks
        self.oscillating_ticks += other.oscillating_ticks
        self.windows += other.windows
        self.path_m += other.path_m
        self.net_m += other.net_m
        self.oscillating_windows += other.oscillating_windows
        self.units_that_ever_oscillated += other.units_that_ever_oscillated


def oscillation(samples: Sequence[Sample], span: int, order_verb: Optional[str] = None) -> OscillationSummary:
    """`order_verb` is `fight_probe.gd`'s `--stall-verb`: the counters sample only units under that verb, because
    the window is measured against what was ASKED. Round 8's headline is `attack_move`, so reproducing it needs
    the same filter -- without it the denominator gains every `move` tick and the share falls for free."""
    out = OscillationSummary()
    trail: List[Sample] = []
    last_goal: Optional[Tuple[float, float]] = None
    ever = False
    for sample in samples:
        distance = sample.goal_distance()
        if distance is None or distance <= AT_GOAL_M:
            continue
        if order_verb is not None and sample.order_verb != order_verb:
            continue
        out.under_way_ticks += 1
        goal = (sample.goal_x, sample.goal_z)
        if last_goal is not None and math.hypot(goal[0] - last_goal[0], goal[1] - last_goal[1]) > GOAL_MOVED_M:
            trail = []
        last_goal = goal
        trail.append(sample)
        if len(trail) > span:
            trail.pop(0)
        if len(trail) < span:
            continue
        path = sum(_flat(trail[i - 1], trail[i]) for i in range(1, len(trail)))
        if path < OSCILLATE_PATH_M:
            continue
        net = _flat(trail[0], trail[-1])
        out.windows += 1
        out.path_m += path
        out.net_m += net
        if net / path < OSCILLATE_RATIO:
            out.oscillating_ticks += 1
            out.oscillating_windows += 1
            ever = True
    out.units_that_ever_oscillated = 1 if ever else 0
    return out


# ---- 2. Signed cusp density --------------------------------------------------------------------


@dataclass
class CuspSummary:
    cusps: int = 0
    ordered: int = 0
    creep: int = 0
    unexplained: int = 0
    unclassified: int = 0
    ticks: int = 0
    ## Ticks under an ORDER that carries a facing, and -- separately -- ticks on which the arrival ARC was live.
    ## Both reported BESIDE every fraction, never inside it: an arrival arc is off-corridor by construction and is
    ## the unit OBEYING (control + the orchestrator, 2026-09-20), while an order that merely carries a facing says
    ## nothing about the tick in front of you. A statistic that charges A6's falsifier for obedience is wrong; one
    ## that excuses a whole journey because it ends in an arc is wrong in the other direction and harder to catch.
    facing_ordered_ticks: int = 0
    facing_arc_ticks: int = 0
    tick_rate: int = 30

    @property
    def agent_minutes(self) -> float:
        return self.ticks / float(self.tick_rate) / 60.0

    @property
    def per_agent_minute(self) -> Optional[float]:
        return self.cusps / self.agent_minutes if self.agent_minutes > 0 else None

    def merge(self, other: "CuspSummary") -> None:
        self.cusps += other.cusps
        self.ordered += other.ordered
        self.creep += other.creep
        self.unexplained += other.unexplained
        self.unclassified += other.unclassified
        self.ticks += other.ticks
        self.facing_ordered_ticks += other.facing_ordered_ticks
        self.facing_arc_ticks += other.facing_arc_ticks
        self.tick_rate = other.tick_rate or self.tick_rate


def signed_speed(previous: Sample, current: Sample, dt: float) -> float:
    """Speed along the body's own facing, from POSITION and the logged heading — never from `gear`.

    A cusp is a reversal, and a reversal is the hull moving backwards along its nose. Reading it from the
    controller's gear is how round 8 ended up with a third of its flips 'unexplained': the counter could only see
    flips the controller labelled. This sees the motion.
    """
    vx = (current.x - previous.x) / dt
    vz = (current.z - previous.z) / dt
    # The forward vector fight_probe.gd measures the heading from: heading = atan2(-forward.x, -forward.z).
    hx = -math.sin(current.heading_rad)
    hz = -math.cos(current.heading_rad)
    speed = math.hypot(vx, vz)
    along = vx * hx + vz * hz
    return math.copysign(speed, along) if along != 0.0 else 0.0


def cusp_density(samples: Sequence[Sample], tick_rate: int) -> CuspSummary:
    out = CuspSummary(tick_rate=tick_rate)
    out.ticks = len(samples)
    # Per-TICK tallies, over every sample: a cusp needs a pair of samples, but "was the arc live" does not.
    out.facing_ordered_ticks = sum(1 for s in samples if s.facing_ordered)
    out.facing_arc_ticks = sum(1 for s in samples if s.facing_arc)
    dt = 1.0 / float(tick_rate)
    last_sign = 0
    for i in range(1, len(samples)):
        previous, current = samples[i - 1], samples[i]
        if current.tick != previous.tick + 1:
            last_sign = 0
            continue
        speed = signed_speed(previous, current, dt)
        if abs(speed) < CUSP_SPEED_MPS:
            continue  # below the floor: a stationary unit's jitter is not a cusp
        sign = 1 if speed > 0 else -1
        if last_sign != 0 and sign != last_sign:
            out.cusps += 1
            if (
                current.order_reverse is None
                and current.phase is None
                and current.creeping is None
                and current.facing_arc is None
            ):
                out.unclassified += 1
            elif current.order_reverse or current.facing_arc:
                # A live arrival arc is the unit doing as it was told, so a reversal inside it must never land in
                # `unexplained` -- that is the bucket a falsifier reads. Note `facing_arc`, NOT `facing_ordered`:
                # an order carries its facing from the moment it is issued, and excusing the whole journey would
                # hide every real reversal on the way to the gate.
                out.ordered += 1
            elif current.creeping:
                out.creep += 1
            else:
                out.unexplained += 1
        last_sign = sign
    return out


# ---- 3. Spectral arc length --------------------------------------------------------------------


def _fft(values: Sequence[complex]) -> List[complex]:
    """Iterative radix-2 Cooley-Tukey. Ours, so the transform is bit-identical on every machine and `make check`
    grows no dependency. `len(values)` must be a power of two."""
    n = len(values)
    if n & (n - 1) != 0:
        raise ValueError("FFT length must be a power of two, got %d" % n)
    out = list(values)
    # Bit-reversal permutation.
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
        if i < j:
            out[i], out[j] = out[j], out[i]
    length = 2
    while length <= n:
        angle = -2.0 * math.pi / length
        step = cmath.exp(complex(0.0, angle))
        for start in range(0, n, length):
            w = complex(1.0, 0.0)
            half = length >> 1
            for k in range(start, start + half):
                u = out[k]
                v = out[k + half] * w
                out[k] = u + v
                out[k + half] = u - v
                w *= step
        length <<= 1
    return out


def hann(n: int) -> List[float]:
    """The periodic Hann taper, w[k] = 0.5 - 0.5 cos(2 pi k / n). Periodic (not symmetric) so that its own
    transform is exactly three bins: that is what makes the known answers hand-computable."""
    return [0.5 - 0.5 * math.cos(2.0 * math.pi * k / n) for k in range(n)]


def normalised_spectrum(profile: Sequence[float], nfft: int = SPARC_NFFT) -> List[float]:
    """|FFT(profile zero-padded to nfft)| / |FFT(...)[0]|, the one-sided half. Raises on a zero DC term."""
    if len(profile) > nfft:
        raise ValueError("profile of %d samples does not fit a %d-point transform" % (len(profile), nfft))
    padded = [complex(v, 0.0) for v in profile] + [complex(0.0, 0.0)] * (nfft - len(profile))
    spectrum = _fft(padded)
    dc = abs(spectrum[0])
    if dc < SPARC_MIN_DC:
        raise ValueError("the speed profile sums to %g: a parked unit has no normalised spectrum" % dc)
    return [abs(spectrum[k]) / dc for k in range(nfft // 2 + 1)]


def spectral_arc_length(
    profile: Sequence[float],
    tick_rate: int,
    cutoff_rad_s: float = SPARC_CUTOFF_RAD_S,
) -> float:
    """SPARC (Balasubramanian et al. 2012/2015):

        SAL = - integral_0^wc sqrt( (1/wc)^2 + (dV(w)/dw)^2 ) dw

    over the DC-normalised magnitude spectrum V of the speed profile, with w in rad/s. Smoother is closer to
    zero; jerkier is more negative. The integral is the polyline length of (w/wc, V(w)), which is what the
    reference implementation computes and what makes the metric dimensionless.

    The profile is |speed|, not signed speed: the DC term is what normalises the spectrum, and a shuffling hull's
    signed mean passes through zero — the metric would explode on exactly the case we care about. Reversals are
    cusp density's job.

    **What it measures, exactly:** the total variation of the normalised magnitude spectrum, plus the width of the
    band. So it reads spectral COMPLEXITY and DEPTH — how many things the speed is doing at once, and how strongly
    — and NOT frequency: a single clean wobble scores the same whether it is slow or fast, because sliding a peak
    along the axis does not change the length of the curve. Real jerk is broadband, which is why this works; a
    metric that had to rank two pure tones would be the wrong one to reach for (`_agents/metrics.md`).
    """
    nfft = len(profile)
    if nfft & (nfft - 1) != 0:
        raise ValueError("the SPARC profile must be a power of two long (there is no padding), got %d" % nfft)
    tapered = [value * w for value, w in zip(profile, hann(nfft))]
    magnitudes = normalised_spectrum(tapered, nfft)
    # Bin k sits at w = 2*pi*k*tick_rate/nfft rad/s.
    bin_rad_s = 2.0 * math.pi * float(tick_rate) / float(nfft)
    last = int(cutoff_rad_s / bin_rad_s)
    if last < 1:
        raise ValueError(
            "cutoff %g rad/s is below one bin (%g rad/s): nothing to integrate" % (cutoff_rad_s, bin_rad_s)
        )
    last = min(last, len(magnitudes) - 1)
    total = 0.0
    for k in range(1, last + 1):
        dw = bin_rad_s / cutoff_rad_s  # the normalised frequency step
        dv = magnitudes[k] - magnitudes[k - 1]
        total += math.hypot(dw, dv)
    return -total


@dataclass
class SparcSummary:
    windows: int = 0
    total: float = 0.0
    values: List[float] = field(default_factory=list)
    refused_parked: int = 0
    refused_short: int = 0

    @property
    def mean(self) -> Optional[float]:
        return self.total / self.windows if self.windows else None

    def merge(self, other: "SparcSummary") -> None:
        self.windows += other.windows
        self.total += other.total
        self.values.extend(other.values)
        self.refused_parked += other.refused_parked
        self.refused_short += other.refused_short


def sparc_over_log(
    samples: Sequence[Sample],
    tick_rate: int,
    window: int = SPARC_WINDOW_SAMPLES,
    stride: Optional[int] = None,
) -> SparcSummary:
    """SPARC over non-overlapping fixed windows of the |speed| profile. Non-overlapping by default so each window
    is an independent sample: overlapping windows make a mean look better-determined than it is."""
    out = SparcSummary()
    stride = stride or window
    if len(samples) < window:
        out.refused_short += 1
        return out
    start = 0
    while start + window <= len(samples):
        chunk = samples[start : start + window]
        start += stride
        if chunk[-1].tick - chunk[0].tick != window - 1:
            out.refused_short += 1  # a gap: the window is not `window` ticks of motion
            continue
        profile = [abs(s.speed_mps) for s in chunk]
        try:
            value = spectral_arc_length(profile, tick_rate)
        except ValueError:
            out.refused_parked += 1
            continue
        out.windows += 1
        out.total += value
        out.values.append(value)
    return out


# ---- 4. Affine formation residual --------------------------------------------------------------


def affine_residual_rms(nominal: Sequence[Tuple[float, float]], actual: Sequence[Tuple[float, float]]) -> float:
    """RMS residual of the best affine map from the reference slot geometry onto the actual positions (Zhao 2018).

    Exactly zero for any translation, rotation, scale or shear of the reference — an element that has wheeled,
    spread out or been squeezed by a corridor is still IN formation. Positive only when a unit has left its slot
    in a way the shared deformation does not explain, which is the thing a player sees.

    **The reference is whatever the producer logged in `slot_x`/`slot_z`: the slot the leader ASSIGNED this tick,
    deformation included** (`Element.slots`), and never a shape reconstructed from a formation name. squad's A8
    narrows a formation with a *file morph* that is deliberately NOT affine — no 2x2 can separate two slots at the
    same depth while squeezing that axis toward zero, so "a wedge becomes a column" is impossible for an affine
    map. With the nominal shape as reference, a wedge that had correctly filed through a defile would read as a
    large residual: a false positive on the one manoeuvre A8 exists to produce. Against the commanded slot, every
    deformation the leader ordered is free, affine or not.

    Solved by ORTHOGONAL PROJECTION (modified Gram-Schmidt on [nx, nz, 1]) rather than by the 3x3 normal
    equations. The two agree wherever the reference is well conditioned, but the projection is also defined when
    it is not — and the case that matters is A8's headline manoeuvre: **an element filed into single file has
    COLLINEAR slots**, which makes the coefficients ambiguous while leaving the residual perfectly well defined.
    The earlier solve refused those elements outright, which would have blinded the metric exactly when squad
    most needs it. A unit standing out of the file is still measured.
    """
    m = len(nominal)
    if m != len(actual):
        raise ValueError("%d reference slots against %d actual positions" % (m, len(actual)))
    if m < FORMATION_MIN_MEMBERS:
        raise ValueError(
            "an affine fit needs %d members to leave a residual (3 points determine it exactly), got %d"
            % (FORMATION_MIN_MEMBERS, m)
        )
    columns = [[nx for nx, _ in nominal], [nz for _, nz in nominal], [1.0] * m]
    ortho: List[List[float]] = []
    for column in columns:
        vector = list(column)
        original = math.sqrt(sum(v * v for v in vector))
        for basis in ortho:
            scale = sum(v * b for v, b in zip(vector, basis))
            vector = [v - scale * b for v, b in zip(vector, basis)]
        length = math.sqrt(sum(v * v for v in vector))
        # Dependent on what came before (a collinear or coincident reference): drop it. Relative to the column's
        # own magnitude, so a formation measured in metres and one measured in centimetres decide the same way.
        if length > 1e-9 * max(original, 1.0):
            ortho.append([v / length for v in vector])
    residual_sq = 0.0
    for axis in (0, 1):
        residual = [point[axis] for point in actual]
        for basis in ortho:
            scale = sum(r * b for r, b in zip(residual, basis))
            residual = [r - scale * b for r, b in zip(residual, basis)]
        residual_sq += sum(r * r for r in residual)
    return math.sqrt(residual_sq / m)


def reference_rank(nominal: Sequence[Tuple[float, float]]) -> int:
    """How many independent directions the reference slot geometry spans: 3 for a real shape, 2 for an element
    filed into a line, 1 for slots all in one place. Reported so a reader can see WHY a residual is small."""
    columns = [[nx for nx, _ in nominal], [nz for _, nz in nominal], [1.0] * len(nominal)]
    ortho: List[List[float]] = []
    for column in columns:
        vector = list(column)
        original = math.sqrt(sum(v * v for v in vector))
        for basis in ortho:
            scale = sum(v * b for v, b in zip(vector, basis))
            vector = [v - scale * b for v, b in zip(vector, basis)]
        length = math.sqrt(sum(v * v for v in vector))
        if length > 1e-9 * max(original, 1.0):
            ortho.append([v / length for v in vector])
    return len(ortho)


@dataclass
class FormationSummary:
    ticks: int = 0
    total: float = 0.0
    values: List[float] = field(default_factory=list)
    members_seen: int = 0
    refused_too_small: int = 0
    ## The lowest reference rank seen: 3 is a real shape, 2 an element filed into a line, 1 slots all in one
    ## place. A small residual at rank 2 means something different from a small residual at rank 3.
    min_rank: int = 3

    @property
    def mean(self) -> Optional[float]:
        return self.total / self.ticks if self.ticks else None

    def merge(self, other: "FormationSummary") -> None:
        self.ticks += other.ticks
        self.total += other.total
        self.values.extend(other.values)
        self.members_seen = max(self.members_seen, other.members_seen)
        self.refused_too_small += other.refused_too_small
        self.min_rank = min(self.min_rank, other.min_rank)


def formation_residual_by_element(log: TrajectoryLog) -> Dict[int, FormationSummary]:
    """Per element, per tick: fit the affine map from the slot geometry to where the vehicles actually are."""
    by_tick: Dict[Tuple[int, int], List[Sample]] = {}
    for samples in log.units.values():
        for sample in samples:
            if sample.element is None or sample.slot_x is None:
                continue
            by_tick.setdefault((sample.element, sample.tick), []).append(sample)
    out: Dict[int, FormationSummary] = {}
    for (element, _tick), members in sorted(by_tick.items()):
        summary = out.setdefault(element, FormationSummary())
        summary.members_seen = max(summary.members_seen, len(members))
        if len(members) < FORMATION_MIN_MEMBERS:
            summary.refused_too_small += 1
            continue
        members.sort(key=lambda s: s.unit)
        nominal = [(s.slot_x, s.slot_z) for s in members]
        actual = [(s.x, s.z) for s in members]
        value = affine_residual_rms(nominal, actual)
        summary.min_rank = min(summary.min_rank, reference_rank(nominal))
        summary.ticks += 1
        summary.total += value
        summary.values.append(value)
    return out


# ---- Hull turn between events (combat's A2 bearing read, 2026-09-20) --------------------------


def turns_between_events(
    samples: Sequence[Sample], ticks: Sequence[int]
) -> Tuple[List[float], int]:
    """|Δ heading| in DEGREES between consecutive events, read off the unwrapped heading.

    Combat's A2 hypothesis is that a physical switching cost lets through the switches a flat bonus blocked —
    the cheap ones, at small bearing changes — while the expensive tail is unchanged or thinner. That is a
    question about how far the hull actually TURNED between two decisions, and the log already answers it: the
    heading is logged unwrapped, so a 201° turn reads as 201° and not as −159°. (Round 8's 20.7° "overshoot",
    which justified a whole technique, was that wrap bug.)

    **What this is and is not.** It is the hull's own rotation between two events. It is NOT the change in
    bearing TO A TARGET: nothing in the trajectory log knows what a unit was shooting at. A unit that switched
    between two targets while driving straight shows ~0 here, which is the honest answer to "did the hull have
    to turn", not to "were the targets far apart".

    Returns (turns in degrees, number of events that fell outside the unit's logged ticks).
    """
    by_tick = {sample.tick: sample for sample in samples}
    ordered = sorted(set(ticks))
    found = [by_tick[tick] for tick in ordered if tick in by_tick]
    missed = len(ordered) - len(found)
    turns = [
        abs(math.degrees(found[i].heading_rad - found[i - 1].heading_rad)) for i in range(1, len(found))
    ]
    return turns, missed


@dataclass
class TurnSummary:
    turns: List[float] = field(default_factory=list)
    events: int = 0
    missed: int = 0

    def merge(self, other: "TurnSummary") -> None:
        self.turns.extend(other.turns)
        self.events += other.events
        self.missed += other.missed

    def quantile(self, q: float) -> Optional[float]:
        if not self.turns:
            return None
        ordered = sorted(self.turns)
        index = min(len(ordered) - 1, max(0, int(math.ceil(q * len(ordered))) - 1))
        return ordered[index]

    @property
    def mean(self) -> Optional[float]:
        return sum(self.turns) / len(self.turns) if self.turns else None

    def share_under(self, degrees: float) -> Optional[float]:
        if not self.turns:
            return None
        return sum(1 for turn in self.turns if turn < degrees) / len(self.turns)


def turn_report(log: TrajectoryLog, events: Dict[str, Sequence[int]]) -> Dict[str, object]:
    """`events`: {unit name: [tick, ...]}. Per unit type, the distribution of hull turn between them."""
    by_type: Dict[str, TurnSummary] = {}
    unknown = []
    for unit, ticks in sorted(events.items()):
        samples = log.units.get(unit)
        if not samples:
            unknown.append(unit)
            continue
        row = by_type.setdefault(samples[0].unit_id, TurnSummary())
        turns, missed = turns_between_events(samples, ticks)
        row.turns.extend(turns)
        row.events += len(set(ticks))
        row.missed += missed
    return {
        "unknown_units": unknown,
        "by_unit_id": {
            unit_id: {
                "events": row.events,
                "intervals": len(row.turns),
                "events_outside_the_log": row.missed,
                "turn_deg_mean": _round(row.mean, 1),
                "turn_deg_p10": _round(row.quantile(0.10), 1),
                "turn_deg_p50": _round(row.quantile(0.50), 1),
                "turn_deg_p90": _round(row.quantile(0.90), 1),
                "share_under_15_deg": _round(row.share_under(15.0), 3),
                "share_under_45_deg": _round(row.share_under(45.0), 3),
                "share_over_90_deg": _round(1.0 - row.share_under(90.0), 3) if row.turns else None,
            }
            for unit_id, row in sorted(by_type.items())
        },
    }


# ---- The report --------------------------------------------------------------------------------


@dataclass
class UnitTypeReport:
    unit_id: str
    units: int = 0
    ## Units of this type that ever held an order. A log holds BOTH armies; only one of them is under orders, and
    ## without this column an ordered side's row reads as though it did nothing, diluted by the enemy's vehicles.
    units_ordered: int = 0
    efficiency: EfficiencySummary = field(default_factory=EfficiencySummary)
    oscillation: OscillationSummary = field(default_factory=OscillationSummary)
    cusps: CuspSummary = field(default_factory=CuspSummary)
    sparc: SparcSummary = field(default_factory=SparcSummary)


def report(log: TrajectoryLog, order_verb: Optional[str] = None) -> Dict[str, object]:
    """Every metric, per unit type and per element, with its window, its sample count and its unit count."""
    span = window_samples(log.header.tick_rate)
    by_type: Dict[str, UnitTypeReport] = {}
    for name, samples in sorted(log.units.items()):
        if not samples:
            continue
        unit_id = samples[0].unit_id
        row = by_type.setdefault(unit_id, UnitTypeReport(unit_id=unit_id))
        row.units += 1
        row.units_ordered += 1 if any(s.ordered for s in samples) else 0
        row.efficiency.merge(displacement_efficiency(samples, span))
        row.oscillation.merge(oscillation(samples, span, order_verb))
        row.cusps.merge(cusp_density(samples, log.header.tick_rate))
        row.sparc.merge(sparc_over_log(samples, log.header.tick_rate))
    elements = formation_residual_by_element(log)

    def unit_row(row: UnitTypeReport) -> Dict[str, object]:
        return {
            "units": row.units,
            "units_ordered": row.units_ordered,
            "efficiency_mean": _round(row.efficiency.mean, 4),
            "efficiency_p10": _round(row.efficiency.quantile(0.10), 4),
            "efficiency_p50": _round(row.efficiency.quantile(0.50), 4),
            "efficiency_windows": row.efficiency.windows,
            "efficiency_refused_zero_path": row.efficiency.refused_zero_path,
            "oscillating_share": _round(row.oscillation.share, 4),
            "oscillating_units": row.oscillation.units_that_ever_oscillated,
            "under_way_seconds": _round(row.oscillation.under_way_ticks / float(log.header.tick_rate), 1),
            "net_over_path": _round(row.oscillation.net_over_path, 4),
            "cusps_per_agent_minute": _round(row.cusps.per_agent_minute, 2),
            "cusps": row.cusps.cusps,
            "cusps_ordered": row.cusps.ordered,
            "cusps_creep": row.cusps.creep,
            "cusps_unexplained": row.cusps.unexplained,
            "cusps_unclassified": row.cusps.unclassified,
            # None when the COLUMN IS ABSENT, 0.0 only when the column is there and the unit spent no time in
            # an arc. nav hit the difference: a log written before `facing_arc` was published printed
            # `arc_live=0.0s` in both arms of an A/B, which reads exactly like a measurement of behaviour and
            # was an unpublished field. A zero that means "no data" is the thing this whole tool exists to
            # refuse (Invariant 0), and it was in the renderer.
            "facing_ordered_seconds": (
                _round(row.cusps.facing_ordered_ticks / float(log.header.tick_rate), 1)
                if "facing_ordered" in log.columns else None),
            "facing_arc_seconds": (
                _round(row.cusps.facing_arc_ticks / float(log.header.tick_rate), 1)
                if "facing_arc" in log.columns else None),
            "agent_minutes": _round(row.cusps.agent_minutes, 2),
            "sparc_mean": _round(row.sparc.mean, 4),
            "sparc_windows": row.sparc.windows,
            "sparc_refused_parked": row.sparc.refused_parked,
            "sparc_refused_short": row.sparc.refused_short,
        }

    whole = UnitTypeReport(unit_id="ALL")
    for row in by_type.values():
        whole.units += row.units
        whole.units_ordered += row.units_ordered
        whole.efficiency.merge(row.efficiency)
        whole.oscillation.merge(row.oscillation)
        whole.cusps.merge(row.cusps)
        whole.sparc.merge(row.sparc)

    return {
        "provenance": log.header.provenance(),
        "commit": log.header.commit,
        "machine": log.header.machine,
        "producer": log.header.producer,
        "arena": log.header.arena,
        "seed": log.header.seed,
        "knobs": log.header.knobs,
        "path": log.path,
        "tick_rate": log.header.tick_rate,
        "window_s": WINDOW_S,
        "window_ticks": span,
        "sparc_window_samples": SPARC_WINDOW_SAMPLES,
        "sparc_nfft": SPARC_NFFT,
        "sparc_cutoff_rad_s": SPARC_CUTOFF_RAD_S,
        "cause_columns": log.has_cause,
        "columns": sorted(log.columns),
        "oscillating_order_verb": order_verb,
        "samples": log.sample_count(),
        "units": len(log.units),
        "teams": sorted({s.team for samples in log.units.values() for s in samples[:1]}),
        "by_unit_id": {unit_id: unit_row(row) for unit_id, row in sorted(by_type.items())},
        "all": unit_row(whole),
        "by_element": {
            str(element): {
                "residual_rms_mean": _round(summary.mean, 4),
                "ticks": summary.ticks,
                "members": summary.members_seen,
                "refused_too_small": summary.refused_too_small,
                "reference_rank": summary.min_rank,
            }
            for element, summary in sorted(elements.items())
        },
    }


def _round(value: Optional[float], digits: int) -> Optional[float]:
    return None if value is None else round(value, digits)
