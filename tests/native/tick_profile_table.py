import json,glob,sys,statistics
rows={}
for f in sorted(glob.glob(sys.argv[1]+'/tp-*.log')):
    for line in open(f,errors='replace'):
        if line.startswith('NATIVE_TICK_PROFILE '):
            r=json.loads(line[len('NATIVE_TICK_PROFILE '):]); arm=f.split('/')[-1].split('-')[1]
            sim=r['sim']; sec=sim['sections']
            g=lambda k: sec.get(k,{}).get('ms_per_tick',0.0)
            tick=sim['tick_ms']; seg=['segment:elements','segment:order_executor+commanders','segment:controllers']
            p0=tick-sum(g(k) for k in seg)
            top=sorted([(k,v['ms_per_tick']) for k,v in sec.items() if not k.startswith('segment') and not k.startswith('brain/') and '/' not in k],key=lambda x:-x[1])[:7]
            print(f"{f.split('/')[-1]:36} alive {r['alive']} frame {r['frame_wall_ms']:6.1f}, {r['ticks_per_frame']:.2f} t/f, process {r['process_ms']:.1f} | tick scripts {tick:5.1f}: elem {g(seg[0]):4.1f} cmdr {g(seg[1]):4.1f} ctrl {g(seg[2]):5.1f} prio0 {p0:5.1f} (unattr {sim['unattributed_ms']:.1f}) | engine step {r['engine_physics_step_ms']:.1f} (n {r['step_samples']})")
            print("    prio0 sections:", ", ".join(f"{k} {v:.2f}" for k,v in top))
            rows.setdefault(arm,[]).append((r['frame_wall_ms'],r['ticks_per_frame'],tick,g(seg[0]),g(seg[1]),g(seg[2]),p0,r['engine_physics_step_ms'],r['process_ms'],sim['unattributed_ms']))
for arm,v in rows.items():
    m=[statistics.mean(x[i] for x in v) for i in range(10)]
    print(f"MEAN {arm} n={len(v)}: frame {m[0]:.1f} ms, {m[1]:.2f} ticks/frame, tick scripts {m[2]:.1f} (elements {m[3]:.1f}, commanders {m[4]:.1f}, controllers {m[5]:.1f}, prio0 {m[6]:.1f} of which unattributed {m[9]:.1f}), engine step {m[7]:.1f}, process {m[8]:.1f}")
