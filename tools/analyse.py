import wave, json, numpy as np
w=wave.open('/workspace/demo/music.wav'); sr=w.getframerate()
x=np.frombuffer(w.readframes(w.getnframes()),dtype=np.int16).reshape(-1,2).mean(1)/32768
d=json.load(open('/workspace/demo/beats.json')); beats=np.array(d['beats'])
NAMES=['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
def spec(t0,t1,n=16384):
    a=int(t0*sr); seg=x[a:a+n] if int((t1-t0)*sr)>=n else x[a:int(t1*sr)]
    seg=np.pad(seg,(0,n-len(seg)))*np.hanning(n)
    return np.abs(np.fft.rfft(seg)), np.fft.rfftfreq(n,1/sr)
def chroma(S,f,lo,hi):
    c=np.zeros(12); m=(f>lo)&(f<hi)
    midi=69+12*np.log2(f[m]/440); 
    for p,s in zip(np.round(midi).astype(int)%12, S[m]**2): c[p]+=s
    return c/(c.sum()+1e-12)
# global key
tot=np.zeros(12)
for i in range(0,len(beats)-1,2):
    S,f=spec(beats[i],beats[i+1]); tot+=chroma(S,f,60,2000)
maj=np.array([6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88]);mn=np.array([6.33,2.68,3.52,5.38,2.6,3.53,2.54,4.75,3.98,2.69,3.34,3.17])
best=max([(np.corrcoef(np.roll(p,k),tot)[0,1],NAMES[k]+(' major' if p is maj else ' minor')) for p in (maj,mn) for k in range(12)])
print('KEY',best); print('chroma',dict(zip(NAMES,np.round(tot/tot.sum(),3))))
# bass per beat (40-160Hz)
bass=[]
for i in range(len(beats)-1):
    S,f=spec(beats[i],beats[i+1]); m=(f>35)&(f<170)
    k=np.argmax(S[m]); fr=f[m][k]; e=S[m][k]
    bass.append((int(round(69+12*np.log2(fr/440))),float(e)))
# lead per 8th note (400-2500Hz) strongest peak
lead=[]
for i in range(len(beats)-1):
    for h in range(2):
        t0=beats[i]+h*(beats[i+1]-beats[i])/2
        S,f=spec(t0,t0+0.2,8192); m=(f>350)&(f<2500)
        k=np.argmax(S[m]); lead.append((int(round(69+12*np.log2(f[m][k]/440))),float(S[m][k])))
# chords per bar (4 beats)
tmpl={}
for r in range(12):
    for q,iv in (('',(0,4,7)),('m',(0,3,7))):
        t=np.zeros(12); t[[ (r+j)%12 for j in iv]]=1; tmpl[NAMES[r]+q]=t
bars=[]
for i in range(0,len(beats)-4,4):
    c=np.zeros(12)
    for j in range(4):
        S,f=spec(beats[i+j],beats[i+j+1]); c+=chroma(S,f,100,1200)
    bars.append(max(tmpl,key=lambda k:np.dot(tmpl[k],c)))
# drums: quantise snares/hats to 16th grid within bar
def pat(ev):
    h=np.zeros(16)
    for t in ev:
        i=np.searchsorted(beats,t)-1
        if i<0 or i>=len(beats)-1: continue
        pos=(i%4)*4+int(round((t-beats[i])/(beats[i+1]-beats[i])*4))%4
        h[pos]+=1
    return h
out=dict(key=best[1],bpm=d['bpm'],bass=bass,lead=lead,bars=bars,snare=pat(d['snares']).tolist(),hat=pat(d['hats']).tolist(),sections=d['sections'],drops=d['drops'],builds=d['builds'],breaks=d['breaks'],beats=beats.tolist())
json.dump(out,open('/workspace/c64/tools/analysis.json','w'))
from collections import Counter
print('bars',len(bars)); 
for s in range(0,len(bars),16): print(s, ' '.join(bars[s:s+16]))
print('snare16',out['snare']); print('hat16',out['hat'])
bn=[b[0]%12 for b in bass]; print('bass pc',Counter(NAMES[p] for p in bn).most_common(6))
print('lead pc',Counter(NAMES[p[0]%12] for p in lead).most_common(8))
