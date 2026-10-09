import json,glob,statistics,math,sys
THINK=['brain/situation','brain/decide','brain/act','brain/t.poll','brain/t.rate_progress','brain/t.incoming','brain/motion']
EXEC=['brain/move','brain/weapon','brain/c.wall_contact','brain/c.reflexes']
for arm in sys.argv[2:]:
    rows=[]
    for f in sorted(glob.glob(f'{sys.argv[1]}/tp-{arm}-*.log')):
        for line in open(f,errors='replace'):
            if line.startswith('NATIVE_TICK_PROFILE '):
                r=json.loads(line[20:]); s=r['sim']['sections']
                d={'frame':r['frame_wall_ms'],'tpf':r['ticks_per_frame'],'tick':r['sim']['tick_ms'],'alive0':r['alive'][0],'alive1':r['alive'][1],
                   'elements':s['segment:elements']['ms_per_tick'],'ctrl':s['segment:controllers']['ms_per_tick'],'step':r['engine_physics_step_ms']}
                d['prio0']=d['tick']-d['elements']-d['ctrl']-s.get('segment:order_executor+commanders',{}).get('ms_per_tick',0)
                for k,v in s.items():
                    if k.startswith('brain/') or k in ('tank','match','visfield','shell'): d[k]=v['ms_per_tick']
                rows.append(d)
    if not rows: continue
    m=lambda k: statistics.mean(r.get(k,0) for r in rows)
    se=lambda k: statistics.stdev([r.get(k,0) for r in rows])/math.sqrt(len(rows))
    print(f"== {arm}: n={len(rows)}, alive at 8 s {m('alive0'):.0f}, at 20 s {m('alive1'):.0f}")
    print(f"frame {m('frame'):.1f} ms at {m('tpf'):.2f} ticks/frame; tick scripts {m('tick'):.2f} (se {se('tick'):.2f}): controllers {m('ctrl'):.2f}, elements {m('elements'):.2f}, prio0 {m('prio0'):.2f} (tank {m('tank'):.2f}, match {m('match'):.2f}, visfield {m('visfield'):.2f}, shell {m('shell'):.2f}); engine step {m('step'):.2f}")
    print(f"think {m('brain/think'):.2f}: " + ", ".join(f"{k[6:]} {m(k):.2f}" for k in sorted(THINK,key=lambda k:-m(k))[:6]))
    print(f"execute {m('brain/execute'):.2f}: " + ", ".join(f"{k[6:]} {m(k):.2f}" for k in sorted(EXEC+['brain/weapon.scan','brain/weapon.lanes','brain/weapon.aim','brain/by.move_to.moving'],key=lambda k:-m(k))[:6]))
