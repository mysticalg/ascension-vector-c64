# Generates song + timeline + helper tables + unrolled render loops -> build/song.s, build/render.s
import math, random, json
random.seed(148)
B='/workspace/c64/build/'
o=[]
def tab(label,data):
    o.append(label)
    for i in range(0,len(data),32): o.append('        .byte '+','.join(str(int(b)&255) for b in data[i:i+32]))
# ---- SID frequency table (PAL), C0 = note 0
fl=[];fh=[]
for n in range(96):
    f=440*2**((n-57)/12); r=min(65535,int(round(f*16777216/985248)))
    fl.append(r&255); fh.append(r>>8)
tab('FREQLO',fl); tab('FREQHI',fh)
# ---- song structure (bars). flags
KICK,BASS,HATS,ROLL,ARP,MEL,TONE,DIGI=1,2,4,8,16,32,64,128
E,F,DM,EH=0,1,2,3
sections=[('intro',2),('build',2),('drop',16),('break',8),('build',4),('drop',16),('break',8),('build',4),('drop',16),('break',8),('build',4),('drop',16),('outro',4)]
fl=[];ch=[];roll=[];fc=[]; kinds=[]
dropn=0
for kind,n in sections:
    for b in range(n):
        kinds.append((kind,b,n,dropn))
        if kind=='intro': fl.append(MEL|TONE); ch.append([E,F][b%2]); roll.append(0); fc.append(0x10)
        elif kind=='build':
            fl.append(KICK|ROLL|ARP|(HATS if b>=n-2 else 0)); ch.append([E,E,F,EH][(b+4-n)%4])
            roll.append([4,4,2,1][(b+4-n)%4]); fc.append(0x18+0x20*(b+4-n)//1)
        elif kind=='drop':
            f_=KICK|BASS|HATS|ARP|(DIGI if b==0 else 0)
            if b>=8 and b<12: f_=KICK|BASS|HATS|MEL
            fl.append(f_); prog=[E,E,F,E] if (b//4)%2==0 else [E,E,DM,F]; ch.append(prog[b%4]); roll.append(0); fc.append(0x28+(b%4)*6)
        elif kind=='break': fl.append(MEL|TONE|(HATS if b>=4 else 0)); ch.append([E,F,E,DM][b%4]); roll.append(0); fc.append(0x14)
        else: fl.append(KICK|BASS|MEL); ch.append([E,F,DM,E][b]); roll.append(0); fc.append(0x20)
    if kind=='drop': dropn+=1
N=len(fl)
o.append(f'SONGLEN = {N}')
tab('SONG_FL',fl); tab('SONG_CH',ch); tab('SONG_ROLL',[max(r,1) for r in roll]); tab('SONG_FC',fc)
# chords: bass note, 3 arp notes
CH=[(28,[52,56,59]),(29,[53,57,60]),(26,[50,53,57]),(28,[59,64,68])]
tab('CH_BASS',[c[0] for c in CH]); tab('CH_ARP',sum([c[1] for c in CH],[]))
tab('ARPRHY',[1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,0,1])
R,Hd=255,254
E5,F5,Gs5,D5,C5,B4,A4=64,65,68,62,60,59,57
mel=[E5,Hd,F5,Hd, Gs5,Hd,Hd,F5, Hd,E5,Hd,Hd, D5,Hd,E5,Hd,
     F5,Hd,E5,Hd, D5,Hd,C5,Hd, B4,Hd,Hd,Hd, Hd,Hd,R,R]
tab('MELODY',mel)
tab('KICKF',[0x40,0x12,0x0b,0x07,0x05,0x04])
tab('KICKW',[0x81,0x11,0x11,0x11,0x10,0x10])
tab('VIB',[0,1,2,1,0,255,254,255])
# ---- visual timeline
S=dict(GALAXY=0,TITLE=1,PLANET=2,TUNNEL=3,HYPER=4,WATCH=5,BIGEYE=6,FRACT=7,PLASMA=8,GEOM=9,PENTA=10,EYETRI=11,METAT=12,MSG=13,FLASH=14,CUBE=15,CREDITS=16,RING=17)
for k,v in S.items(): o.append(f'S_{k} = {v}')
pools=[['TUNNEL','HYPER','PLASMA','GEOM','CUBE','FLASH','TUNNEL','HYPER','PENTA','RING'],
       ['WATCH','BIGEYE','TUNNEL','GEOM','FRACT','HYPER','FLASH','RING','PLASMA','WATCH'],
       ['WATCH','FRACT','GEOM','CUBE','METAT','TUNNEL','PLASMA','BIGEYE','HYPER','FLASH'],
       ['TUNNEL','HYPER','WATCH','BIGEYE','FRACT','PLASMA','GEOM','CUBE','RING','PENTA','METAT','EYETRI','FLASH']]
breaks=[['PLANET','PLANET','MSG','GALAXY','PENTA','MSG','METAT','PLANET'],
        ['FRACT','FRACT','MSG','GALAXY','METAT','MSG','FRACT','PLANET'],
        ['GALAXY','PLANET','MSG','PENTA','METAT','MSG','FRACT','GALAXY']]
tl=[[255]*N for _ in range(4)]
prev=None; bi=0; seq=[]
def put(bar,beat,name):
    global prev
    if name==prev: return
    tl[beat][bar]=S[name]; prev=name; seq.append((bar,beat,name))
def pick(pool):
    c=[p for p in pool if p!=prev]; return random.choice(c)
bar=0
for kind,n in sections:
    for b in range(n):
        if kind=='intro': put(bar,0,'GALAXY')
        elif kind=='build':
            k=b+4-n
            if bar<4: put(bar,0,'TITLE')
            elif k==0: put(bar,0,'TUNNEL'); put(bar,2,'HYPER')
            elif k==1: put(bar,0,'TUNNEL'); put(bar,2,'FLASH')
            elif k==2:
                for bt,nm in enumerate(['HYPER','FLASH','TUNNEL','FLASH']): put(bar,bt,nm)
            else:
                for bt,nm in enumerate(['FLASH','TUNNEL','FLASH','HYPER']): put(bar,bt,nm)
        elif kind=='drop':
            d=kinds[bar][3]
            if b==0 and d==1: put(bar,0,'EYETRI')
            elif b==0 and d==2: put(bar,0,'WATCH'); put(bar,2,'BIGEYE')
            elif b%4==2 and b<12: put(bar,0,'MSG')
            elif b>=12:
                for bt in range(4): put(bar,bt,pick(pools[d]))
            else:
                put(bar,0,pick(pools[d])); put(bar,2,pick(pools[d]))
        elif kind=='break':
            put(bar,0,breaks[bi][b]);
            if b==n-1: bi+=1
        else:
            put(bar,0,'GALAXY' if b<2 else 'CREDITS')
        bar+=1
for i in range(4): tab(f'TL{i}',tl[i])
json.dump(seq,open(B+'timeline.json','w'))
print('bars',N,'secs',N*4*20.25/50.0,'cuts',len(seq))
# ---- misc tables
tab('SINE',[int(128+127*math.sin(i*2*math.pi/256)) for i in range(256)])
tab('MUL40L',[(i*40)&255 for i in range(25)]); tab('MUL40H',[(i*40)>>8 for i in range(25)])
cm=[1]*256; cm[32]=0
for q in range(128,143): cm[q]=15
cm[143]=1; cm[160]=1
tab('CMAP',cm)
bars=[0,6,6,4,14,14,3,3,1,1,3,3,14,4,6,0, 0,9,8,8,10,7,7,1,1,7,10,8,9,9,0,0]*2
tab('BARCOL',bars)
tab('STCHR',[46]*8+[152]*8+[153]*8+[155]*8)
tab('STCOL',[6,6,6,11,11,14,14,14, 14,14,4,4,3,3,3,3, 3,3,13,13,1,1,1,1, 1,1,1,1,1,1,1,1])
tab('SCRPAL',[6,14,3,1,7,1,3,14,6,4,10,7,1,7,10,4])
tab('EYECOL',[3,5,14,13,3,10,14,5])
open(B+'song.s','w').write('\n'.join(o)+'\n')
# ---- unrolled render loops
r=[]
r.append('render_single')
for p in range(4):
    r.append('        ldx #0')
    r.append(f'rsl{p}')
    r.append(f'rs_v1_{p}  lda $1000,x')
    r.append('        adc zt1')
    r.append('        tay')
    r.append(f'rs_pal_{p} lda PALS,y')
    r.append(f'        sta $d800+{p*256},x')
    r.append('        inx')
    if p==3: r.append('        cpx #192')
    r.append(f'        bne rsl{p}')
r.append('        rts')
r.append('render_dual')
for p in range(4):
    r.append('        ldx #0')
    r.append(f'rdl{p}')
    r.append(f'rd_v1_{p}  lda $1000,x')
    r.append('        adc zt1')
    r.append('        sta ztmp')
    r.append(f'rd_v2_{p}  lda $1000,x')
    r.append('        adc zt2')
    r.append('        eor ztmp')
    r.append('        tay')
    r.append(f'rd_pal_{p} lda PALS,y')
    r.append(f'        sta $d800+{p*256},x')
    r.append('        inx')
    if p==3: r.append('        cpx #192')
    r.append(f'        bne rdl{p}')
r.append('        rts')
# setter: zv1 (ptr), zv2 (ptr), zpal (hi byte of palette page)
r.append('set_render')
for p in range(4):
    for pre,src in (('rs_v1','zv1'),('rd_v1','zv1'),('rd_v2','zv2')):
        r.append(f'        lda {src}'); r.append(f'        sta {pre}_{p}+1')
        r.append(f'        lda {src}+1'); r.append('        clc' ); r.append(f'        adc #{p}'); r.append(f'        sta {pre}_{p}+2')
    r.append('        lda zpal'); r.append(f'        sta rs_pal_{p}+2'); r.append(f'        sta rd_pal_{p}+2')
r.append('        rts')
open(B+'render.s','w').write('\n'.join(r)+'\n')
