import json,os,re,sys,collections
root=sys.argv[1]; want=[]
for l in open(sys.argv[2]):
    m=re.match(r"\s+[\d.]+ (\w+)/(\S+) (.+?) (\S+) wedged",l)
    if m and " nearest " in l: want.append((m.group(1),m.group(2),m.group(3)))
summ=collections.Counter()
for fac,run,crew in want:
    last=None; n=0
    for l in open(os.path.join(root,fac,run,"run.log"),errors="replace"):
        if l.startswith("H1B_FAR "):
            d=json.loads(l[8:])
            if d["unit"]==crew: last=d; n+=1
    if last is None: print(f"{fac}/{run} {crew}: no H1B_FAR"); summ["no H1B_FAR"]+=1; continue
    key=(last["blocker_kind"], last["blocker_phase"], "answered" if last["blocker_last_ask_answer"] else "refused",
         "blocker room %.1f"%last["blocker_room_back_m"], "my room %.1f"%last["my_room_back_m"])
    summ[(last["blocker_kind"],last["blocker_phase"],"answered" if last["blocker_last_ask_answer"] else "refused", last["blocker_room_back_m"]<1.0, last["my_room_back_m"]<1.0)]+=1
    print(f"{fac}/{run} {crew}: {n} far rows; blocker {last['blocker']} {key} gap {last['gap_m']} under_way {last['blocker_under_way']} escaping_on_me {last['blocker_escaping_on_me']}")
print(); [print(v,k) for k,v in summ.most_common()]
