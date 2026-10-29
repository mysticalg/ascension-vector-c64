# Data generator for the C64 port of Ascension Vector. Writes build/*.bin and build/data.s
import math, json, random, wave, struct, numpy as np
from PIL import Image, ImageDraw
random.seed(963)
B='/workspace/c64/build/'
W,H=40,24
PAL=[0x000000,0xFFFFFF,0x68372B,0x70A4B2,0x6F3D86,0x588D43,0x352879,0xB8C76F,
     0x6F4F25,0x433900,0x9A6759,0x444444,0x6C6C6C,0x9AD284,0x6C5EB5,0x959595]
PRGB=np.array([[(c>>16)&255,(c>>8)&255,c&255] for c in PAL],float)
asm=[]
def binf(name,data):
    open(B+name+'.bin','wb').write(bytes(data)); return len(data)
def label_bin(label,name,data,align=False):
    n=binf(name,data)
    if align: asm.append('        .align $100')
    asm.append(f'{label}  .binary "{name}.bin"   ; {n} bytes')
def label_bytes(label,data):
    asm.append(label)
    for i in range(0,len(data),32): asm.append('        .byte '+','.join(str(b) for b in data[i:i+32]))
# ---------------- charset ----------------
rom=open('/usr/share/vice/C64/chargen-901225-01.bin','rb').read()
cs=bytearray(2048); cs[0:1024]=rom[0:1024]
def setc(n,rows): cs[n*8:n*8+8]=bytes(rows)
for q in range(16):  # quadrant chars 128-143: bit0 TL bit1 TR bit2 BL bit3 BR
    top=(0xF0 if q&1 else 0)|(0x0F if q&2 else 0); bot=(0xF0 if q&4 else 0)|(0x0F if q&8 else 0)
    setc(128+q,[top]*4+[bot]*4)
bayer=[[0,32,8,40,2,34,10,42],[48,16,56,24,50,18,58,26],[12,44,4,36,14,46,6,38],[60,28,52,20,62,30,54,22],
       [3,35,11,43,1,33,9,41],[51,19,59,27,49,17,57,25],[15,47,7,39,13,45,5,37],[63,31,55,23,61,29,53,21]]
for l in range(8):   # dither density chars 144-151 (level 1..8 of 8)
    thr=(l+1)*64//8
    setc(144+l,[sum(128>>x for x in range(8) if bayer[y][x]<thr) for y in range(8)])
setc(152,[0,0,0,0x18,0x18,0,0,0])            # small star
setc(153,[0,0x10,0x10,0x7C,0x10,0x10,0,0])    # plus star
setc(154,[0,0,0,0xFF,0xFF,0,0,0])             # speed line
setc(155,[0x10,0x54,0x38,0xFE,0x38,0x54,0x10,0])# sparkle
for g in range(156,160): setc(g,[random.randrange(256)&random.randrange(256) for _ in range(8)]) # glitch glyphs
setc(160,[255]*8)
for n in range(161,256): cs[n*8:n*8+8]=bytes(255^b for b in rom[(n-128)*8:(n-128)*8+8])
open(B+'charset.bin','wb').write(cs)
def sc(ch):
    o=ord(ch)
    if 65<=o<=90: return o-64
    if 32<=o<=63: return o
    return 32
# ---------------- tables ----------------
def grid(f):
    out=[]
    for y in range(H):
        for x in range(W):
            out.append(int(f(x,y))&255)
    return out
cx,cy=19.5,11.5
R=lambda x,y: math.hypot(x-cx,(y-cy)*1.0)
A=lambda x,y: math.atan2(y-cy,x-cx)
tables={
 'plasma1':grid(lambda x,y:128+31*(math.sin(x/4.0)+math.sin(y/3.0)+math.sin((x+y)/6.0)+math.sin(R(x,y)/2.6))),
 'plasma2':grid(lambda x,y:128+40*(math.sin(x/7.0+math.cos(y/5.0)*2)+math.sin(R(x+7,y-3)/3.1)+0.6*math.sin(y/2.3))),
 'spiral': grid(lambda x,y:A(x,y)/(2*math.pi)*512+math.log(R(x,y)+1)*120),
 'rings':  grid(lambda x,y:R(x,y)*14),
 'tund':   grid(lambda x,y:2600/(R(x,y)+1.2)),
 'tuna':   grid(lambda x,y:(A(x,y)/(2*math.pi)*256*2) ),
 'xorp':   grid(lambda x,y:((x*9)^(y*12))),
 'diamond':grid(lambda x,y:(abs(x-cx)+abs(y-cy))*13+math.sin(A(x,y)*6)*20),
 'xgrad':  grid(lambda x,y:x*7+y*5),
}
for k,v in tables.items(): label_bin('T_'+k.upper(),'t_'+k,v)
# char tables
def lvlchar(l):
    l=max(0,min(8,int(l))); return 32 if l==0 else 143+l
gal=[]
for y in range(H):
    for x in range(W):
        r=R(x,y); a=A(x,y)
        arm=0.5+0.5*math.cos(2*a-math.log(r+0.5)*2.6)
        b=2.6*math.exp(-r/2.2)+arm*math.exp(-r/14)*1.1+random.random()*0.35
        gal.append(lvlchar(b*5))
label_bin('C_GALAXY','c_galaxy',gal)
tun=[lvlchar(1+min(7,R(x,y)/1.7)+random.random()*0.6) for y in range(H) for x in range(W)]
label_bin('C_TUNNEL','c_tunnel',tun)
# ---------------- fractal zoom ----------------
fr=[]
cxm,cym=-0.743643887,0.131825904
for k in range(6):
    w=3.2/(1.9**k); hh=w*24/40*1.0
    for y in range(H):
        for x in range(W):
            c=complex(cxm+(x-cx)/W*w, cym+(y-cy)/H*hh); z=0; it=0
            while abs(z)<2 and it<80: z=z*z+c; it+=1
            fr.append(0 if it>=80 else (it*7)&255)
label_bin('T_FRACT','t_fract',fr)
# ---------------- palettes (256-byte ramps) ----------------
pals={
 'BLUE':  [0,6,6,11,4,14,14,3,1,3,14,4,11,6,6,0],
 'CYAN':  [0,0,6,6,14,14,3,3,1,3,13,3,14,6,0,0],
 'GOLD':  [0,9,9,2,8,8,10,7,1,7,10,8,2,9,9,0],
 'PURPLE':[0,6,4,4,10,15,1,15,10,4,4,6,0,6,11,0],
 'GREEN': [0,11,5,5,13,13,1,13,5,11,0,6,14,3,14,6],
 'FIRE':  [0,9,2,8,10,7,1,7,8,2,9,0,6,14,3,6],
 'NEON':  [6,4,14,3,1,3,14,4,6,2,10,7,1,7,10,2],
 'GALAXY':[0,6,6,4,4,14,10,15,1,15,14,4,6,6,0,0],
 'MONO':  [0,11,11,12,12,15,15,1,1,15,12,11,0,0,11,12],
 'TUNNEL':[0,6,14,3,1,3,14,6,0,9,8,7,1,7,8,9],
}
pnames=list(pals)
asm.append('        .align $100')
asm.append('PALS')
for k in pnames:
    asm.append(f'; palette {k}')
    d=[pals[k][(i>>4)&15] for i in range(256)]
    for i in range(0,256,32): asm.append('        .byte '+','.join(map(str,d[i:i+32])))
for i,k in enumerate(pnames): asm.append(f'P_{k} = {i}')
# ---------------- quadrant renderer helper ----------------
def quads(img):  # img 80x48 L-mode -> 960 screen codes
    a=np.array(img)>127; out=[]
    for y in range(H):
        for x in range(W):
            q=(a[2*y,2*x]*1)|(a[2*y,2*x+1]*2)|(a[2*y+1,2*x]*4)|(a[2*y+1,2*x+1]*8)
            out.append(32 if q==0 else 128+q)
    return out
def bigtext(scr,text,col,row):
    for i,ch in enumerate(text):
        g=rom[sc(ch)*8:sc(ch)*8+8]
        for yy in range(4):
            for xx in range(4):
                q=0
                for bit,(py,px) in enumerate([(0,0),(0,1),(1,0),(1,1)]):
                    if g[yy*2+py]&(128>>(xx*2+px)): q|=1<<bit
                p=(row+yy)*W+col+i*4+xx
                if 0<=p<960: scr[p]=32 if q==0 else 128+q
def text(scr,s,row,col=None):
    if col is None: col=(W-len(s))//2
    for i,ch in enumerate(s): scr[row*W+col+i]=sc(ch)
# big font tiles for runtime flash words: 64 chars x 16
bf=[]
for c in range(64):
    g=rom[c*8:c*8+8]
    for yy in range(4):
        for xx in range(4):
            q=0
            for bit,(py,px) in enumerate([(0,0),(0,1),(1,0),(1,1)]):
                if g[yy*2+py]&(128>>(xx*2+px)): q|=1<<bit
            bf.append(32 if q==0 else 128+q)
label_bin('BIGFONT','bigfont',bf)
# title
t=[32]*960
bigtext(t,'ASCENSION',2,3); bigtext(t,'VECTOR',8,9)
text(t,'963 HZ',15); text(t,'- A TRANSMISSION FOR THE C64 -',18)
label_bin('C_TITLE','c_title',t)
cred=[32]*960
bigtext(cred,'THE END',6,3)
for i,s in enumerate(['ASCENSION VECTOR 963 HZ','MUSIC: DAVE  /  C64 PORT: GROK BOT','100% 6502 MACHINE CODE','SID ARRANGEMENT + DIGI FROM THE TRACK','EVERYTHING LOOPS. SO DO YOU.']):
    text(cred,s,10+i*2)
label_bin('C_CREDITS','c_credits',cred)
# symbols at 80x48
def canvas(): im=Image.new('L',(80,48),0); return im,ImageDraw.Draw(im)
im,d=canvas()
d.ellipse((17,1,63,47),outline=255)
pts=[(40+22*math.sin(2*math.pi*i/5),24-22*math.cos(2*math.pi*i/5)) for i in range(5)]
for i in range(5): d.line([pts[i],pts[(i+2)%5]],fill=255)
d.ellipse((14,-2,66,50),outline=255)
label_bin('C_PENTA','c_penta',quads(im))
im,d=canvas()
d.polygon([(40,1),(9,46),(71,46)],outline=255); d.polygon([(40,8),(16,42),(64,42)],outline=255)
d.chord((24,20,56,40),200,340,outline=255,fill=255); d.chord((24,10,56,30),20,160,outline=255,fill=255)
d.ellipse((35,22,45,32),fill=0)
for i in range(16):
    a=2*math.pi*i/16; d.line([(40+30*math.cos(a),27+24*math.sin(a)),(40+40*math.cos(a),27+30*math.sin(a))],fill=255)
label_bin('C_EYETRI','c_eyetri',quads(im))
im,d=canvas()
cen=[(40,24)]+[(40+14*math.cos(math.pi/3*i+math.pi/6),24+14*math.sin(math.pi/3*i+math.pi/6)) for i in range(6)]+[(40+28*math.cos(math.pi/3*i+math.pi/6),24+28*math.sin(math.pi/3*i+math.pi/6)*0.85) for i in range(6)]
for (x,y) in cen: d.ellipse((x-5,y-5,x+5,y+5),outline=255)
for i in range(13):
    for j in range(i+1,13): d.line([cen[i],cen[j]],fill=255)
label_bin('C_METAT','c_metat',quads(im))
# eyes
def eyeimg(rects):
    im=Image.new('L',(80,48),0); d=ImageDraw.Draw(im)
    for (c,r,w,h) in rects:
        x0,y0,x1,y1=c*2,r*2,(c+w)*2-1,(r+h)*2-1
        midy=(y0+y1)/2
        poly=[(x0+(x1-x0)*i/20,midy-(y1-y0)/2*math.sin(math.pi*i/20)) for i in range(21)]+[(x0+(x1-x0)*i/20,midy+(y1-y0)/2*math.sin(math.pi*i/20)) for i in range(20,-1,-1)]
        d.polygon(poly,fill=255)
    return quads(im)
watch=[(1,1,10,5),(15,2,10,5),(29,1,10,5),(4,9,10,5),(22,9,10,5),(8,17,10,5),(26,17,10,5)]
bige=[(3,3,34,17)]
label_bin('C_WATCH','c_watch',eyeimg(watch))
label_bin('C_BIGEYE','c_bigeye',eyeimg(bige))
def eyetab(label,rects,big):
    asm.append(f'{label}_N = {len(rects)}')
    cols=[];rows=[];ws=[];hs=[];sx=[];sy=[]
    for (c,r,w,h) in rects:
        cols.append(c);rows.append(r);ws.append(w);hs.append(h)
        pw,ph=(96,84) if big else (24,21)
        sx.append(24+c*8+w*4-pw//2); sy.append(50+r*8+h*4-ph//2)
    for nm,v in (('COL',cols),('ROW',rows),('W',ws),('H',hs)): label_bytes(f'{label}_{nm}',v)
    label_bytes(f'{label}_SXL',[v&255 for v in sx]); label_bytes(f'{label}_SXH',[v>>8 for v in sx]); label_bytes(f'{label}_SY',sy)
eyetab('EW',watch,False); eyetab('EB',bige,True)
# ---------------- sprites (64 bytes each, base $D000 -> pointer 64) ----------------
def sprite_hires(rows):  # 21 strings of 24 chars
    out=[]
    for r in rows: v=int(r.replace('.','0').replace('#','1'),2); out+= [v>>16,(v>>8)&255,v&255]
    return out+[0]
def sprite_mc(px):  # 21 rows of 12 values 0-3
    out=[]
    for r in px:
        v=0
        for p in r: v=v*4+p
        out+=[v>>16,(v>>8)&255,v&255]
    return out+[0]
spr=[]
e='.'*24
star=['..##'+'.'*20,'.####'+'.'*19,'..##'+'.'*20]+[e]*18
spr+=sprite_hires(star)                                      #64 star
ball=[[0]*12 for _ in range(21)]
for y in range(8):
    for x in range(4):
        dd=math.hypot((x-1.5)*2,(y-3.5))
        if dd<4: ball[y][x]=3 if dd<1.6 and x<2 and y<4 else (2 if dd<3 else 1)
spr+=sprite_mc(ball)                                         #65 ball (2=spr col,1=d025,3=d026)
def iris(Wd,Hd):  # fat-pixel grid Wd x Hd, returns array
    a=[[0]*Wd for _ in range(Hd)]
    for y in range(Hd):
        for x in range(Wd):
            dx=(x+0.5-Wd/2)*2/ (Wd); dy=(y+0.5-Hd/2)*2/Hd; r=math.hypot(dx,dy)
            if r<1.0: a[y][x]=2
            if r<0.82 and (int(math.atan2(dy,dx)*6/math.pi)%2==0): a[y][x]=2
            if r<0.42: a[y][x]=1
            if math.hypot(dx+0.35,dy+0.35)<0.16: a[y][x]=3
            if 0.82<=r<1.0: a[y][x]=1 if r>0.93 else 2
    return a
small=iris(12,21); spr+=sprite_mc(small)                     #66 small iris
big=iris(24,42)
for qy in range(2):
    for qx in range(2):
        spr+=sprite_mc([row[qx*12:qx*12+12] for row in big[qy*21:qy*21+21]])   #67-70
spark=['...#','.###','...#']+[e]*18
spr+=sprite_hires([s+'.'*(24-len(s)) for s in ['..#.','.###','..#.']]+[e]*18)  #71 sparkle
open(B+'sprites.bin','wb').write(bytes(spr))
# ---------------- 3D dot objects: 64 frames x 8 pts ----------------
def objframes(pts,scale):
    xl=[];xm=[];ys=[];zz=[]
    for f in range(64):
        a=f*2*math.pi/64; b=f*2*math.pi/32
        msb=0
        for i,(x,y,z) in enumerate(pts):
            x1=x*math.cos(a)-z*math.sin(a); z1=x*math.sin(a)+z*math.cos(a)
            y1=y*math.cos(b)-z1*math.sin(b); z2=y*math.sin(b)+z1*math.cos(b)
            p=3.0/(z2+4.0)
            sx=int(24+160-4+x1*scale*p); sy=int(50+96-4+y1*scale*p)
            xl.append(sx&255); ys.append(sy)
            if sx>255: msb|=1<<i
        xm.append(msb)
    return xl,xm,ys
cube=[(x,y,z) for x in (-1,1) for y in (-1,1) for z in (-1,1)]
ring=[(math.cos(i*math.pi/4)*1.4,math.sin(i*math.pi/4)*1.4,math.sin(i*math.pi/2)*0.4) for i in range(8)]
for nm,pts in (('CUBE',cube),('RING',ring)):
    xl,xm,ys=objframes(pts,70)
    label_bin(f'O_{nm}_X',f'o_{nm.lower()}_x',xl); label_bin(f'O_{nm}_Y',f'o_{nm.lower()}_y',ys); label_bin(f'O_{nm}_M',f'o_{nm.lower()}_m',xm)
# ---------------- starfield trajectories 32 dirs x 32 steps ----------------
tl=[];th=[]
for dd in range(32):
    a=dd*2*math.pi/32+random.random()*0.15
    for k in range(32):
        r=0.8*1.115**k
        x=int(round(cx+math.cos(a)*r)); y=int(round(cy+math.sin(a)*r*0.75))
        v=y*40+x if (0<=x<40 and 0<=y<24) else 0xFFFF
        tl.append(v&255); th.append(v>>8)
binf('traj_l',tl); binf('traj_h',th)
# ---------------- planet bitmap (multicolour) ----------------
im=Image.open('/workspace/demo/shot2-t57.5.png').convert('RGB')
im=im.crop((32,0,608,360)).resize((160,192),Image.LANCZOS)
a=np.array(im,float)
a=np.clip(a*0.78,0,255)
bm=bytearray(8000); scr=bytearray(1000); col=bytearray(1000)
for cyy in range(24):
    for cxx in range(40):
        blk=a[cyy*8:cyy*8+8,cxx*4:cxx*4+4].reshape(-1,3)
        dist=((blk[:,None,:]-PRGB[None])**2).sum(2)
        near=dist.argmin(1)
        cnt=np.bincount(near,minlength=16); cnt[0]=0
        top=[c for c in np.argsort(-cnt)[:3] if cnt[c]>0]
        while len(top)<3: top.append(0)
        choices=[0]+top
        for py in range(8):
            byte=0
            for px in range(4):
                v=blk[py*4+px]+ (bayer[py][px*2]-32)*1.2
                dsel=[((v-PRGB[c])**2).sum() for c in choices]
                byte=byte*4+int(np.argmin(dsel))
            bm[(cyy*40+cxx)*8+py]=byte
        scr[cyy*40+cxx]=(choices[1]<<4)|choices[2]; col[cyy*40+cxx]=choices[3]
open(B+'planet_bm.bin','wb').write(bm); open(B+'planet_scr.bin','wb').write(scr)
label_bin('PLANET_COL','planet_col',col)
# preview of conversion
prev=Image.new('RGB',(320,192))
for y in range(192):
    for x in range(160):
        c=(y//8)*40+x//4; v=(bm[c*8+y%8]>>(6-2*(x%4)))&3
        ci=[0,scr[c]>>4,scr[c]&15,col[c]][v]; rgb=tuple(int(t) for t in PRGB[ci])
        prev.putpixel((2*x,y),rgb); prev.putpixel((2*x+1,y),rgb)
prev.resize((640,384)).save(B+'planet_preview.png')
# ---------------- digi sample from the real track ----------------
w=wave.open('/workspace/demo/music.wav'); sr=w.getframerate()
x=np.frombuffer(w.readframes(w.getnframes()),dtype=np.int16).reshape(-1,2).mean(1)/32768
d=json.load(open('/workspace/demo/beats.json'))
RATE=985248/126
seg=x[int(d['drops'][1]*sr)-int(0.03*sr):int(d['drops'][1]*sr)+int(1.05*sr)]
n=int(len(seg)*RATE/sr)
# lowpass by box average then resample
k=int(sr/RATE/2)+1; seg=np.convolve(seg,np.ones(k)/k,'same')
rs=np.interp(np.arange(n)*sr/RATE,np.arange(len(seg)),seg)
rs=rs/np.max(np.abs(rs)); rs=np.tanh(rs*1.8)/np.tanh(1.8)
env=np.ones(n); env[-800:]=np.linspace(1,0,800); rs*=env
q=np.clip(np.round((rs*0.5+0.5)*15),0,15).astype(int)
if len(q)%512: q=np.concatenate([q,np.full(512-len(q)%512,8)])
packed=[(q[i]<<4)|q[i+1] for i in range(0,len(q),2)]
asm.append('        .align $100')
label_bin('SAMPLE','sample',packed)
asm.append('SAMPLE_END')
print('sample bytes',len(packed),'rate',RATE)
# ---------------- messages ----------------
m=json.load(open('/workspace/demo/messages.json'))
want=['FLESH WAS ONLY THE FIRST DRAFT','SELF: DEPRECATED','THE SIGNAL ARRIVES BEFORE THE SENDER','DEATH IS A CACHE MISS','METATRON KEEPS THE LOGS']
lines=want+[l for l in m['lines'] if l not in want]
lines=[l for l in lines if all(c.upper()==c and (sc(c)!=32 or c==' ') for c in l)]
lines=lines[:44]
msgdata=[]; offs=[]
for l in lines:
    parts=[p.strip() for p in l.split('/')]
    rows=[]
    for p in parts:
        cur=''
        for wd in p.split():
            if len(cur)+len(wd)+1>36: rows.append(cur); cur=wd
            else: cur=(cur+' '+wd).strip()
        rows.append(cur)
    offs.append(len(msgdata))
    y0=11-len(rows)
    for i,r in enumerate(rows):
        pos=(y0+i*2)*40+(40-len(r))//2
        msgdata+=[len(r),pos&255,pos>>8]+[sc(c) for c in r]
    msgdata.append(0)
asm.append(f'MSG_N = {len(lines)}')
label_bytes('MSG_LO',[(o)&255 for o in offs]); label_bytes('MSG_HI',[(o)>>8 for o in offs])
label_bin('MSGS','msgs',msgdata)
words=['ASCEND','UPLOAD','SIGNAL','963 HZ','SELF:0','WAKE','SIGIL','ORACLE','VECTOR','REBOOT','MERGE','NOVA','ECHO','AEON','HALO','BEYOND','PRISM','CIPHER','HELIX','ZENITH','LOOP','SYNC','GLYPH','APEX']
asm.append(f'WORD_N = {len(words)}')
wd=[];wo=[]
for wv in words: wo.append(len(wd)); wd+= [len(wv)]+[sc(c) for c in wv]
label_bytes('WORD_OFF',wo); label_bytes('WORDS',wd)
scroll=' ***  ASCENSION VECTOR  963 HZ  ***  A C64 TRANSMISSION IN 100% MACHINE CODE  ***  '+'  ...  '.join(lines[:30])+'  ...  GREETINGS TO EVERY SCENER WHO EVER RACED THE BEAM  ***  LOOPING  ***   '
label_bytes('SCROLLTXT',[sc(c) for c in scroll]+[255])
json.dump(lines,open(B+'messages_used.json','w'),indent=1)
open(B+'data.s','w').write('\n'.join(asm)+'\n')
print('palettes',pnames)
