#!/usr/bin/env python3
"""Round 35 (W1c): print a wedge_trace.gd --trace-crew log's WEDGE_TICK rows as a timeline. usage: wedge_tick_timeline.py run.log [every_nth]"""
import sys,json
step=int(sys.argv[2]) if len(sys.argv)>2 else 4
rows=[json.loads(l[11:]) for l in open(sys.argv[1]) if l.startswith('WEDGE_TICK ')]
for s in rows[::step]:
  print(s['crew'][-9:],round(s['t']/30,1),s['x'],s['z'],'goal_m',s['goal_m'],'mps',s['mps'],s['phase'],s['move_type'],s['driver'],s['force'],'pace',s['pace'],'thr',s['thr'],'st',s['steer'],'w',int(s['wedged']),'fires',s['unstick_fires'],'k',s['kturn_m'],'col',s['colliders'],'wall',int(s['wall_touch']),'held',int(s['held']),'fr',s['friends'],s['near_friend_m'],'blk',s['blocked_by'],s['yield_to'],s['option'])
