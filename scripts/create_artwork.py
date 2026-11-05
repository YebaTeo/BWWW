from pathlib import Path
import json, math
root=Path(__file__).resolve().parent.parent
phases=['Narawas','Nyacar','Ngaganggang','Ngahuru','Ngaseuk','Ngored','NgubaranPare','Dibuat','DryingRice','Ngunjal','NgaleuitkeunPare']
ids=['narawas','nyacar','ngaganggang','ngahuru','ngaseuk','ngored','ngubaran_pare','dibuat','drying_rice','ngunjal','ngaleuitkeun_pare']
def asset(cat,name,svg):
 d=cat/(name+'.imageset');d.mkdir(parents=True,exist_ok=True)
 (d/(name+'.svg')).write_text(svg)
 (d/'Contents.json').write_text(json.dumps({'images':[{'filename':name+'.svg','idiom':'universal'}],'info':{'author':'xcode','version':1},'properties':{'preserves-vector-representation':True}}))
def rice(x,y,gold=False,bundle=False):
 c='#C59C44' if gold else '#47734F';s=f'<path d="M{x} {y}q-4 -35 -18 -48M{x} {y}q5 -40 20 -56M{x} {y}v-55" fill="none" stroke="{c}" stroke-width="4" stroke-linecap="round"/>'
 if gold:
  for j in range(5):s+=f'<ellipse cx="{x+14-j*2}" cy="{y-53+j*5}" rx="5" ry="3" fill="#E7C56D"/>'
 if bundle:s+=f'<path d="M{x-9} {y-17}h18" stroke="#6E4F32" stroke-width="5"/>'
 return s
def leuit(full):
 s='<path d="M378 232v55m142-55v55" stroke="#60482E" stroke-width="14"/><path d="M358 148h183v95H358z" fill="#B68E59"/><path d="M342 151l107-93 110 93z" fill="#5B6447"/><path d="M366 168h167m-167 20h167m-167 20h167m-167 20h167" stroke="#D5B17A" stroke-width="4"/><path d="M385 161h126v70H385z" fill="#574C38"/>'
 if full:
  for x in [402,448,494]:s+=rice(x,224,True,True)
 return s
for i,(folder,pid) in enumerate(zip(phases,ids)):
 cat=root/'BeBaduy/Features/Phases'/folder/'Resources'/f'{folder}.xcassets';cat.mkdir(parents=True,exist_ok=True);(cat/'Contents.json').write_text('{"info":{"author":"xcode","version":1}}')
 for result in [False,True]:
  s='<svg xmlns="http://www.w3.org/2000/svg" width="600" height="340" viewBox="0 0 600 340"><rect width="600" height="340" fill="#E5EDE5"/><circle cx="488" cy="57" r="26" fill="#E9CB82"/><path d="M0 149Q95 26 208 139Q340 10 470 139Q550 74 600 113V340H0Z" fill="#9CAF91"/><path d="M0 194Q177 86 337 185Q480 120 600 171V340H0Z" fill="#6F8B6B"/><path d="M22 269Q168 173 400 220L574 318H22Z" fill="#BC9A70"/><path d="M70 278Q222 209 464 271M103 303Q272 239 505 295" fill="none" stroke="#A3825D" stroke-width="3"/>'
  # Retained trees remain through every field state.
  for x,y in [(45,185),(556,193)]:s+=f'<path d="M{x} {y+30}v-65" stroke="#705A3B" stroke-width="9"/><ellipse cx="{x}" cy="{y-32}" rx="30" ry="42" fill="#3F654D"/>'
  if i==0:
   for j,(x,y) in enumerate([(115,215),(267,230),(408,248)]):s+=f'<path d="M{x} {y}l80 12-25 44-80-14z" fill="{("#3E7351" if result and j==1 else "#D1B286")}" stroke="#F5F1DF" stroke-width="3"/>'
   s+='<path d="M20 212q-2-55 46-82" fill="none" stroke="#3E7351" stroke-width="10"/>'
  if i in [1,2,3]:
   for j in range(4):
    if not (i==1 and result) and not(i==3 and result):
     x=152+j*77;y=255+j%2*25;c='#B19757' if (i==2 and result) or i==3 else '#557750'
     s+=f'<path d="M{x-18} {y}l36-10m-30-14l26 34m-14-24l-8-12" stroke="{c}" stroke-width="7" stroke-linecap="round"/>'
   if i==3 and result:s+='<ellipse cx="300" cy="268" rx="135" ry="24" fill="#746A53"/>'
  if i==4:
   for x,y in [(180,252),(300,273),(420,293)]:
    s+=f'<ellipse cx="{x}" cy="{y}" rx="15" ry="8" fill="#60472E"/>' if result else f'<ellipse cx="{x}" cy="{y}" rx="16" ry="8" fill="none" stroke="#F5F1DF" stroke-width="3" stroke-dasharray="5 4"/>'
    if result:s+=f'<ellipse cx="{x}" cy="{y-2}" rx="6" ry="2" fill="#E7C56D"/>'
   s+='<path d="M352 128l-50 102" stroke="#6F5034" stroke-width="9" stroke-linecap="round"/>'
  if i in [5,6,7]:
   for j in range(8):
    if i==7 and result and j%2==0:continue
    s+=rice(127+j*48,266+(j%2)*36,i==7)
   if i==5 and not result:
    for x in [163,259,355,451]:s+=f'<path d="M{x} 293q-28-30-30-9q8 17 30 9q28-30 30-9q-8 17-30 9" fill="#567D69"/>'
   if i==7 and result:
    for x in [178,244]:s+=rice(x,315,True,True)
  if i==8:
   s+='<path d="M105 213h370M125 213v96m330-96v96" fill="none" stroke="#7C8A50" stroke-width="11"/>'
   for j in range(3):s+=rice(185+j*110,286 if result else 325,True,True)
  if i>=9:
   s+='<path d="M110 315Q190 272 240 277T362 268" fill="none" stroke="#E2C795" stroke-width="23"/>'
   s+=leuit(i==10 and result)
   if i==9:
    for x in ([330,365] if result else [120,160]):s+=rice(x,305,True,True)
  s+='</svg>'
  asset(cat,pid+('_after' if result else '_before'),s)
# Three clear, schematic reference drawings. Labels live in accessible SwiftUI text.
cat=root/'BeBaduy/Features/Phases/NgubaranPare/Resources/NgubaranPare.xcassets'
plant_svgs=[
'<path d="M50 122V30m0 40q-48-45-40-5q15 23 40 5m0-15q48-45 40-5q-15 23-40 5" fill="#4B7855" stroke="#36543D" stroke-width="3"/><ellipse cx="52" cy="92" rx="22" ry="30" fill="#C7CA7D"/>'+''.join(f'<circle cx="{x}" cy="{y}" r="3" fill="#758957"/>' for x,y in [(44,77),(57,83),(40,92),(60,102),(48,111)]),
'<path d="M45 104V24m0 40Q7 2 12 43q7 27 33 21m0-12q48-55 40-12q-8 22-40 12" fill="#558456" stroke="#36543D" stroke-width="3"/><path d="M25 113q-9-26 13-25l33 10q28 2 13 21l-28-4q-26 18-31-2" fill="#C39977" stroke="#876447" stroke-width="3"/>',
'<path d="M51 127V39m0 0Q14 7 3 41q26-10 48-2m0 0Q88 4 97 40Q70 26 51 39m0 0Q63 0 38 3" fill="#4D7954" stroke="#4D7954" stroke-width="6"/><ellipse cx="52" cy="72" rx="23" ry="29" fill="#8FA954"/><path d="M52 47q-10 28 1 47" fill="none" stroke="#647B3C" stroke-width="3"/>'
]
for i,s in enumerate(plant_svgs):asset(cat,f'care_plant_{i}',f'<svg xmlns="http://www.w3.org/2000/svg" width="100" height="140" viewBox="0 0 100 140">{s}</svg>')
cat=root/'BeBaduy/Resources/Assets.xcassets';cat.mkdir(parents=True,exist_ok=True);(cat/'Contents.json').write_text('{"info":{"author":"xcode","version":1}}')
for name,light,dark in [('AccentColor',(0.19,0.37,0.25),(0.58,0.78,0.59)),('Paper',(0.98,0.97,0.94),(0.08,0.11,0.09)),('Earth',(0.45,0.33,0.22),(0.76,0.62,0.45))]:
 d=cat/(name+'.colorset');d.mkdir(exist_ok=True)
 colors=[]
 for rgb,appearance in [(light,None),(dark,[{'appearance':'luminosity','value':'dark'}])]:
  c={'idiom':'universal','color':{'color-space':'srgb','components':dict(zip(['red','green','blue','alpha'],(format(v,'.3f') for v in (*rgb,1))))}}
  if appearance:c['appearances']=appearance
  colors.append(c)
 (d/'Contents.json').write_text(json.dumps({'colors':colors,'info':{'author':'xcode','version':1}}))
