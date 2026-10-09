#!/usr/bin/env python3
"""Round 24 (brains L1, C24.7): game speed per arm from `make native-tick-profile` logs, paired by arena x seed.

speed = ticks a frame x 33.33 ms / frame ms (C24.7's bar: >= 0.97 in the 8-20 s window).
Usage: l1_speed_table.py <dir> [base arm, default base]
"""
import glob, json, math, re, statistics, sys


def runs(directory):
    out = {}
    for path in sorted(glob.glob(directory + '/tp-*.log')):
        m = re.match(r'tp-(.+?)-(\d+)-([a-z_]+)-main-(\d+)\.log', path.split('/')[-1])
        if not m:
            continue
        for line in open(path, errors='replace'):
            if line.startswith('NATIVE_TICK_PROFILE '):
                r = json.loads(line[len('NATIVE_TICK_PROFILE '):])
                ctrl = r['sim']['sections'].get('segment:controllers', {}).get('ms_per_tick', 0.0)
                out.setdefault(m.group(1), {})[(m.group(3), m.group(4))] = {
                    'speed': r['ticks_per_frame'] * 1000.0 / 30.0 / r['frame_wall_ms'],
                    'tick': r['sim']['tick_ms'], 'ctrl': ctrl}
    return out


def mean_se(values):
    if len(values) < 2:
        return (values[0] if values else float('nan')), float('nan')
    return statistics.mean(values), statistics.stdev(values) / math.sqrt(len(values))


def main(directory, base='base'):
    arms = runs(directory)
    print('| arm | n | game speed (se) | paired v %s (se) | tick scripts ms | controllers ms (paired) |' % base)
    print('|---|---|---|---|---|---|')
    for arm in sorted(arms, key=lambda a: (a != base, a)):
        cells = arms[arm]
        speed = mean_se([c['speed'] for c in cells.values()])
        tick = statistics.mean(c['tick'] for c in cells.values())
        ctrl = statistics.mean(c['ctrl'] for c in cells.values())
        paired, pctrl = '', ''
        if arm != base and base in arms:
            keys = [k for k in cells if k in arms[base]]
            d = mean_se([cells[k]['speed'] - arms[base][k]['speed'] for k in keys])
            c = mean_se([cells[k]['ctrl'] - arms[base][k]['ctrl'] for k in keys])
            paired = '%+.3f (%.3f) n=%d' % (d[0], d[1], len(keys))
            pctrl = ' (%+.1f, se %.1f)' % c
        print('| %s | %d | %.3f (%.3f) | %s | %.1f | %.1f%s |' % (arm, len(cells), speed[0], speed[1], paired, tick, ctrl, pctrl))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else 'base')
