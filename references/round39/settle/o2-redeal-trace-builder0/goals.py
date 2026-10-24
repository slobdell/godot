import re,sys
pat=re.compile(r'(Green_Alpha_\d)\(([-\d.]+),([-\d.]+) goal (\[[^\]]*\]|-|null|<null>)\s*([A-Z_]*)[^"]*"([^"]*)" st ([^ )]+)')
last={}
for l in open(sys.argv[1],errors='replace'):
    if l.startswith('ORDERS_PROBE_TRACE'):
        t=l.split()[1]
        for m in pat.finditer(l):
            n,x,z,goal,verb,why,st=m.groups()
            key=(goal,verb)
            if last.get(n)!=key:
                print(t,n,'at',x,z,'goal',goal,verb,'|',why[:60],'| st',st)
                last[n]=key
    elif l.startswith('ARRIVE_GOAL') and 'Alpha' in l: print('  ',l.strip()[:120])
