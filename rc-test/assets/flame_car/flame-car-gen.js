// Car 6 flame car (carter 10-30: the Napalm Charger is the car, Dragon Furnace and Tanker Rod are its skins).
// High detail, same style as the Toxic Hot Rod: faceted low-poly body lofted from rings along Z (nose +Z, up +Y,
// ground y = 0, left = +X). The flamethrower is built INTO the body (nozzles, tanks, plumbing); no roof mount.
// One generator for the preview page (kart-preview/flame-tries) and the game files (export.js).
// opt.variant 0 Napalm Charger / 1 Dragon Furnace / 2 Tanker Rod, opt.splitWheels keeps each wheel apart.
// Returns {bufs:{key:[x,y,z,...]}, COL, NEON, FW, RW}.
window.genFlameCar=function(opt){
opt=opt||{};const V=opt.variant||0;
const PAL=[
 {body:[16,17,21],acc:[255,104,18],tank:[210,58,16],glow:[255,190,60],flame2:[255,214,80]},
 {body:[84,10,16],acc:[255,168,24],tank:[150,96,36],glow:[255,120,30],flame2:[255,226,110]},
 {body:[44,47,52],acc:[255,208,22],tank:[120,126,138],glow:[255,150,40],flame2:[255,236,120]}][V];
const COL={body:PAL.body,acc:PAL.acc,tank:PAL.tank,glass:[14,20,32],chrome:[205,210,220],chrome2:[150,155,165],dark:[9,9,11],tire:[22,22,26],trim:[38,40,46],belt:[18,18,18],bone:[226,214,186]};
const NEON={lamp:[255,238,120],glow:PAL.glow,tail:[255,36,36],plate:[235,240,225],flame2:PAL.flame2};
const bufs={};
let KP='';   // key prefix: with opt.splitWheels each wheel's parts are 'FL:tire', 'FL:acc', ...
const B=k=>{k=KP+k;return bufs[k]||(bufs[k]=[]);};
const tri=(k,a,b,c)=>{B(k).push(a[0],a[1],a[2],b[0],b[1],b[2],c[0],c[1],c[2]);};
const quad=(k,a,b,c,d)=>{tri(k,a,b,c);tri(k,a,c,d);};
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]],add=(a,b)=>[a[0]+b[0],a[1]+b[1],a[2]+b[2]];
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const nrm=a=>{const l=Math.hypot(a[0],a[1],a[2])||1;return[a[0]/l,a[1]/l,a[2]/l];};
const fnorm=(a,b,c)=>nrm(cross(sub(b,a),sub(c,a)));
function interp(T,z){if(z>=T[0][0])return T[0][1];for(let i=0;i<T.length-1;i++){const a=T[i],b=T[i+1];if(z<=a[0]&&z>=b[0]){const t=(a[0]-z)/((a[0]-b[0])||1);return a[1]+(b[1]-a[1])*t;}}return T[T.length-1][1];}
function box(k,cx,cy,cz,w,h,l,rot){const P=[[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]].map(v=>{let p=[v[0]*w/2,v[1]*h/2,v[2]*l/2];if(rot)p=rot(p);return[p[0]+cx,p[1]+cy,p[2]+cz];});
 [[0,3,2,1],[4,5,6,7],[0,1,5,4],[3,7,6,2],[0,4,7,3],[1,2,6,5]].forEach(f=>quad(k,P[f[0]],P[f[1]],P[f[2]],P[f[3]]));}
function prism(k,pts,t,map){const n=pts.length;const F=pts.map(p=>map(p[0],p[1],-t/2)),K=pts.map(p=>map(p[0],p[1],t/2));
 const v2=pts.map(p=>({x:p[0],y:p[1]}));const tris=triangulate(pts);
 for(const tr of tris){tri(k,F[tr[0]],F[tr[2]],F[tr[1]]);tri(k,K[tr[0]],K[tr[1]],K[tr[2]]);}
 for(let i=0;i<n;i++){const j=(i+1)%n;quad(k,F[i],F[j],K[j],K[i]);}}
// ear clipping for simple polygons [[u,v]...]
function triangulate(P){const n=P.length;let area=0;for(let i=0;i<n;i++){const a=P[i],b=P[(i+1)%n];area+=a[0]*b[1]-b[0]*a[1];}
 const idx=[...Array(n).keys()];if(area<0)idx.reverse();const out=[];let guard=0;
 const isConvex=(a,b,c)=>((b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]))>1e-9;
 const inside=(p,a,b,c)=>{const d1=(b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0]),d2=(c[0]-b[0])*(p[1]-b[1])-(c[1]-b[1])*(p[0]-b[0]),d3=(a[0]-c[0])*(p[1]-c[1])-(a[1]-c[1])*(p[0]-c[0]);return d1>=0&&d2>=0&&d3>=0;};
 while(idx.length>3&&guard++<5000){let cut=false;for(let i=0;i<idx.length;i++){const ia=idx[(i+idx.length-1)%idx.length],ib=idx[i],ic=idx[(i+1)%idx.length];const a=P[ia],b=P[ib],c=P[ic];
  if(!isConvex(a,b,c))continue;let ok=true;for(const j of idx){if(j===ia||j===ib||j===ic)continue;if(inside(P[j],a,b,c)){ok=false;break;}}
  if(ok){out.push(area<0?[ia,ic,ib]:[ia,ib,ic]);idx.splice(i,1);cut=true;break;}}if(!cut)break;}
 if(idx.length===3)out.push(area<0?[idx[0],idx[2],idx[1]]:[idx[0],idx[1],idx[2]]);return out;}
function cyl(k,a,b,r,n,r2,rot0){r2=r2===undefined?r:r2;const u=nrm(sub(b,a));let s=Math.abs(u[1])<.9?[0,1,0]:[1,0,0];const p=nrm(cross(u,s)),q=cross(u,p);
 const A=[],Bq=[];for(let i=0;i<n;i++){const g=(rot0===undefined?Math.PI/n:rot0)+i*2*Math.PI/n;const c=Math.cos(g),d=Math.sin(g);const o=[p[0]*c+q[0]*d,p[1]*c+q[1]*d,p[2]*c+q[2]*d];A.push([a[0]+o[0]*r,a[1]+o[1]*r,a[2]+o[2]*r]);Bq.push([b[0]+o[0]*r2,b[1]+o[1]*r2,b[2]+o[2]*r2]);}
 for(let i=0;i<n;i++){const j=(i+1)%n;quad(k,A[i],A[j],Bq[j],Bq[i]);tri(k,a,A[j],A[i]);tri(k,b,Bq[i],Bq[j]);}}
function ngon(n,r,ph){const p=[];for(let i=0;i<n;i++){const g=(ph===undefined?Math.PI/n:ph)+i*2*Math.PI/n;p.push([Math.cos(g)*r,Math.sin(g)*r]);}return p;}
function ringPrism(k,n,rin,rout,t,map,ph){const o=ngon(n,rout,ph),i2=ngon(n,rin,ph);
 for(let a=0;a<n;a++){const b=(a+1)%n;const F=p=>map(p[0],p[1],-t/2),K=p=>map(p[0],p[1],t/2);
  quad(k,F(o[a]),F(o[b]),F(i2[b]),F(i2[a]));quad(k,K(o[a]),K(i2[a]),K(i2[b]),K(o[b]));quad(k,F(o[a]),K(o[a]),K(o[b]),F(o[b]));quad(k,F(i2[a]),F(i2[b]),K(i2[b]),K(i2[a]));}}
const rotY=g=>{const c=Math.cos(g),s=Math.sin(g);return p=>[p[0]*c+p[2]*s,p[1],-p[0]*s+p[2]*c];};
const rotX=g=>{const c=Math.cos(g),s=Math.sin(g);return p=>[p[0],p[1]*c-p[2]*s,p[1]*s+p[2]*c];};

// ---------------- variants ----------------
const ZF=5.12,ZR=-5.12;
const TB={
0:{WT:[[5.12,2.5],[4.95,2.72],[4.6,2.9],[4.1,2.98],[3.05,3.0],[2.0,2.96],[1.6,2.8],[-1.0,2.8],[-1.5,2.98],[-2.85,3.25],[-4.0,3.2],[-4.6,3.05],[-4.95,2.9],[-5.12,2.7]],
 FT:[[5.12,1.72],[4.95,1.88],[4.6,2.08],[4.1,2.3],[3.05,2.42],[2.0,2.3],[1.3,2.15],[-1.0,2.16],[-1.6,2.36],[-2.85,2.75],[-3.9,2.62],[-4.6,2.36],[-4.95,2.5],[-5.12,2.2]],
 HT:[[5.12,1.7],[4.95,1.86],[4.6,1.95],[4.1,2.0],[3.05,2.04],[2.0,2.07],[1.3,2.1],[-1.2,2.12],[-2.9,2.14],[-3.9,2.14],[-4.6,2.12],[-4.95,2.42],[-5.12,2.18]],
 CS:[[1.85,2.2,2.17,2.27,2.0],[0.9,2.15,2.2,2.9,1.65],[-0.6,2.15,2.2,2.92,1.62],[-1.6,2.15,2.2,2.8,1.62],[-2.7,2.2,2.2,2.3,2.0]],
 FW:{z:3.05,y:1.02,r:1.02,R:1.16,w:1.1,x:2.55},RW:{z:-2.85,y:1.12,r:1.12,R:1.3,w:1.3,x:2.6}},
1:{WT:[[5.12,2.0],[4.95,2.3],[4.6,2.65],[4.1,2.95],[3.05,3.0],[2.0,2.96],[1.6,2.8],[-1.0,2.8],[-1.5,2.98],[-2.85,3.2],[-4.0,3.1],[-4.6,2.95],[-4.95,2.8],[-5.12,2.6]],
 FT:[[5.12,1.9],[4.95,2.0],[4.6,2.2],[4.1,2.5],[3.05,2.7],[2.0,2.55],[1.3,2.38],[-1.0,2.3],[-1.6,2.45],[-2.85,2.7],[-3.9,2.6],[-4.6,2.4],[-4.95,2.5],[-5.12,2.3]],
 HT:[[5.12,1.85],[4.95,1.98],[4.6,2.2],[4.1,2.4],[3.05,2.5],[2.0,2.45],[1.3,2.36],[-1.2,2.3],[-2.9,2.3],[-3.9,2.3],[-4.6,2.3],[-4.95,2.4],[-5.12,2.25]],
 CS:[[1.6,2.2,2.3,2.4,2.0],[0.5,2.15,2.35,3.0,1.6],[-0.7,2.15,2.35,3.02,1.6],[-1.7,2.15,2.35,2.9,1.6],[-2.6,2.2,2.35,2.4,2.0]],
 FW:{z:3.2,y:1.1,r:1.1,R:1.25,w:1.15,x:2.55},RW:{z:-2.9,y:1.2,r:1.2,R:1.38,w:1.4,x:2.62}},
2:{WT:[[5.12,2.0],[4.95,2.15],[4.6,2.3],[4.1,2.55],[3.05,2.7],[2.0,2.8],[1.6,2.8],[-1.0,2.8],[-1.5,2.9],[-2.85,3.0],[-4.0,3.0],[-4.6,2.9],[-4.95,2.8],[-5.12,2.6]],
 FT:[[5.12,1.6],[4.95,1.72],[4.6,1.9],[4.1,2.1],[3.05,2.2],[2.0,2.2],[1.3,2.2],[-1.0,2.2],[-1.6,2.3],[-2.85,2.5],[-3.9,2.5],[-4.6,2.4],[-4.95,2.4],[-5.12,2.2]],
 HT:[[5.12,1.55],[4.95,1.66],[4.6,1.8],[4.1,1.95],[3.05,2.05],[2.0,2.1],[1.3,2.15],[-1.2,2.15],[-2.9,2.3],[-3.9,2.3],[-4.6,2.3],[-4.95,2.3],[-5.12,2.2]],
 CS:[[1.5,2.0,2.2,2.3,1.9],[0.7,1.95,2.2,2.75,1.6],[-0.4,1.95,2.2,2.78,1.6],[-1.2,1.95,2.2,2.75,1.6],[-1.9,2.0,2.2,2.3,1.9]],
 FW:{z:3.1,y:1.0,r:1.0,R:1.1,w:1.0,x:2.45},RW:{z:-3.0,y:1.25,r:1.25,R:1.42,w:1.5,x:2.7}}};
const T=TB[V];const {WT,FT,HT,CS,FW,RW}=T;
const SILL=0.6;
// ---------------- body ----------------
const ST=[];const st=(z,yb)=>ST.push({z,yb});
st(5.12,0.85);st(4.95,0.72);st(4.6,SILL);st(4.35,SILL);
const AN=8;
function arch(Wh){st(Wh.z+Wh.R,SILL);for(let i=0;i<=AN;i++){const g=i*Math.PI/AN;st(Wh.z+Wh.R*Math.cos(g),Wh.y+Wh.R*Math.sin(g));}st(Wh.z-Wh.R,SILL);}
arch(FW);[1.6,1.0,0.3,-0.4,-1.0,-1.3].forEach(z=>st(z,SILL));arch(RW);
[-4.4,-4.7].forEach(z=>st(z,SILL));st(-4.95,0.72);st(-5.12,0.85);
ST.sort((a,b)=>b.z-a.z);
for(const s of ST){s.W=interp(WT,s.z);s.top=interp(FT,s.z);s.hood=interp(HT,s.z);s.belt=s.top-0.38;s.yb=Math.min(s.yb,s.belt-0.22);}
const LABR=['lowch','side','crease','shoulder','ftop','fin1','fin2','hood','stripe'];
const LAB=[...LABR,'gap',...LABR.slice().reverse(),'floor'];
function bodyRing(s){const {W,yb,top,hood,belt,z}=s;
 const R=[[W-0.3,yb],[W,yb+0.14],[W,belt],[W-0.1,belt+0.16],[W-0.42,top],[W-0.62,top],[W-1.0,hood+(top-hood)*0.35],[W-1.36,hood],[0.62,hood],[0.12,hood]];
 const L=R.slice().reverse().map(p=>[-p[0],p[1]]);return[...R,...L].map(p=>[p[0],p[1],z]);}
function loftL(rings,labels,colorFn,caps,capKey){const n=rings[0].length;
 for(let i=0;i<rings.length-1;i++){const A=rings[i],Q=rings[i+1];
  const mid=[0,0,0];for(const q of A)for(let a=0;a<3;a++)mid[a]+=q[a]/n;
  for(let j=0;j<n;j++){const j2=(j+1)%n;const a=A[j],b=A[j2],c=Q[j2],d=Q[j];
   const ar=Math.hypot(...cross(sub(c,a),sub(d,b)));if(ar<1e-7)continue;
   const ctr=[(a[0]+b[0]+c[0]+d[0])/4,(a[1]+b[1]+c[1]+d[1])/4,(a[2]+b[2]+c[2]+d[2])/4];
   let nn=nrm(cross(sub(c,a),sub(d,b)));if(nn[0]*(ctr[0]-mid[0])+nn[1]*(ctr[1]-mid[1])<0)nn=nn.map(v=>-v);
   const k=colorFn(ctr,nn,labels[j],i);
   const fn=fnorm(a,b,c);if(fn[0]*nn[0]+fn[1]*nn[1]+fn[2]*nn[2]<0)quad(k,a,d,c,b);else quad(k,a,b,c,d);}}
 if(caps){[[rings[0],1],[rings[rings.length-1],-1]].forEach(([R,sg])=>{const c=[0,0,0];R.forEach(p=>{for(let a=0;a<3;a++)c[a]+=p[a]/n;});
  for(let j=0;j<n;j++){const a=R[j],b=R[(j+1)%n];const f=fnorm(a,b,c);if(f[2]*sg<0)tri(capKey,a,c,b);else tri(capKey,a,b,c);}});}}
loftL(ST.map(bodyRing),LAB,(c,n,lab)=>{
 if(lab==='floor'||n[1]<-0.35)return'dark';
 if(lab==='stripe'&&(c[2]>1.7||c[2]<-2.3))return'acc';
 return'body';},true,'body');
for(const Wh of[FW,RW])for(const s of[1,-1]){box('dark',s*1.9,(SILL+Wh.y+Wh.R)/2,Wh.z,0.06,Wh.y+Wh.R-SILL,2*Wh.R);
 box('dark',0,Wh.y+Wh.R-0.05,Wh.z,3.8,0.06,2*Wh.R);}
// ---------------- cabin ----------------
const CLR=['cbase','cside','cedge','roof','rstripe'];const CLAB=[...CLR,'rgap',...CLR.slice().reverse(),'cfloor'];
const cabR=CS.map(([z,wb,ybl,yr,wr])=>{const R=[[wb,1.95],[wb,ybl],[Math.min(wb-0.02,wr+0.24),Math.max(ybl,yr-0.12)],[wr,yr],[0.62,yr],[0.12,yr]];const L=R.slice().reverse().map(p=>[-p[0],p[1]]);return[...R,...L].map(p=>[p[0],p[1],z]);});
loftL(cabR,CLAB,(c,n,lab,i)=>{
 if(lab==='cfloor')return'dark';
 if(lab==='cbase'||lab==='cedge')return'body';
 if(lab==='cside')return(i===1||i===2)?'glass':'body';
 if(i===0||i===CS.length-2)return'glass';
 return lab==='rstripe'?'acc':'body';},true,'body');
const czA=CS[1][0],czB=CS[CS.length-2][0],cyB=CS[1][2],cwb=CS[1][1];
for(const s of[1,-1]){box('chrome',s*(cwb+0.04),cyB,(czA+czB)/2,0.05,0.05,czA-czB);
 cyl('chrome',[s*(CS[1][4]+0.12),CS[1][3]-0.02,czA],[s*(CS[1][4]+0.12),CS[1][3]-0.02,czB],0.035,6);}
// ---------------- side details ----------------
const DW=2.8;
function sideDecal(k,pts,off){const tr=triangulate(pts);for(const s of[1,-1])for(const t of tr){const P=t.map(i=>[s*(DW+off),pts[i][1],pts[i][0]]);if(s>0)tri(k,P[0],P[2],P[1]);else tri(k,P[0],P[1],P[2]);}}
// flame tongues along the doors (front = z+)
function flames(k,z0,z1,yb,hs,off,inner){const P=[[z0,yb-0.02]];const n=hs.length,step=(z0-z1)/n;
 hs.forEach((h,i)=>{const c=z0-step*(i+0.5)*(inner?1:1);const w=step*0.5;
  const hh=inner?h*0.62:h;
  P.push([c+w,yb+0.04],[c+w*0.9,yb+hh*0.3],[c+w*0.35,yb+hh*0.62],[c-w*0.55,yb+hh],[c-w*0.25,yb+hh*0.5],[c-w*0.45,yb+hh*0.28],[c-w*0.9,yb+0.04]);});
 P.push([z1,yb-0.02]);sideDecal(k,P,off);}
const DOOR=T===TB[0]?[1.52,-0.92]:[1.52,-0.92];
for(const zz of DOOR)sideDecal('dark',[[zz+0.018,0.78],[zz+0.018,1.78],[zz-0.018,1.78],[zz-0.018,0.78]],0.008);
for(const s of[1,-1]){box('chrome',s*2.85,1.47,-0.68,0.06,0.07,0.32);
 cyl('dark',[s*2.62,2.13,1.48],[s*2.98,2.3,1.42],0.04,6);box('dark',s*3.06,2.33,1.4,0.14,0.22,0.36);box('chrome',s*3.06,2.33,1.21,0.1,0.18,0.03);}
// ---------------- front end ----------------
const NW=interp(WT,ZF)*2-0.5;box('dark',0,1.3,ZF+0.01,NW,0.74,0.04);
const BCS=[[-0.17,-0.15],[0.1,-0.15],[0.2,-0.06],[0.2,0.07],[0.1,0.15],[-0.17,0.15]];
function bar(k,x0,x1,place){prism(k,BCS,x1-x0,(u,v,t)=>place([(x0+x1)/2+t,v,u]));}
function hose(k,pts,r,n){for(let i=0;i<pts.length-1;i++)cyl(k,pts[i],pts[i+1],r,n||6);}
function gauge(x,y,z,r){ringPrism('chrome',10,r,r*1.4,0.08,(u,v,t)=>[x+u,y+v,z+t]);prism('plate',ngon(10,r),0.04,(u,v,t)=>[x+u,y+v,z+t]);box('dark',x+r*0.15,y+r*0.2,z+0.05,r*0.12,r*1.1,0.02,p=>{const c=Math.cos(0.7),s=Math.sin(0.7);return[p[0]*c-p[1]*s,p[0]*s+p[1]*c,p[2]];});}
// flame nozzle built into the body: collar, finned barrel, flared mouth, glowing core, pilot light
function nozzle(x,y,z0,len,r,fins){
 ringPrism('chrome',8,r+0.04,r+0.2,0.1,(u,v,t)=>[x+u,y+v,z0+t]);
 cyl('chrome2',[x,y,z0-0.5],[x,y,z0+len],r,8);
 for(let i=1;i<=fins;i++){const z=z0+len*i/(fins+1)-0.05;ringPrism('chrome',8,r-0.01,r+0.07,0.07,(u,v,t)=>[x+u,y+v,z+t]);}
 cyl('chrome',[x,y,z0+len],[x,y,z0+len+0.28],r,8,r*1.38);
 prism('dark',ngon(8,r*1.34),0.02,(u,v,t)=>[x+u,y+v,z0+len+0.28+t]);
 prism('glow',ngon(8,r*0.8),0.02,(u,v,t)=>[x+u,y+v,z0+len+0.295+t]);
 cyl('chrome',[x,y+r+0.04,z0+len*0.35],[x,y+r+0.04,z0+len*0.35+0.5],0.035,6);
 box('glow',x,y+r+0.04,z0+len*0.35+0.54,0.08,0.08,0.08);}
function bone(k,x,y0,y1,z,r){cyl(k,[x,y0,z],[x,y1,z],r,4,0.012,Math.PI/4);}
// tank: capsule with chrome straps; axis a->b
function tank(k,a,b,r,band){band=band||'chrome';const u=nrm(sub(b,a));const e=0.36*r;const a1=add(a,u.map(v=>v*e)),b1=sub(b,u.map(v=>v*e));
 cyl(k,a1,b1,r,10);cyl(k,a,a1,r*0.55,10,r);cyl(k,b1,b,r,10,r*0.55);
 for(const t of[0.2,0.5,0.8]){const p=[a1[0]+(b1[0]-a1[0])*t,a1[1]+(b1[1]-a1[1])*t,a1[2]+(b1[2]-a1[2])*t];const q=add(p,u.map(v=>v*0.12));cyl(band,p,q,r*1.06,10);}
 cyl('chrome',b,add(b,u.map(v=>v*0.1)),r*0.28,6);}
if(V===0){
 // headlights
 for(const s of[1,-1]){box('trim',s*1.62,1.3,ZF+0.02,1.12,0.56,0.05);
  for(const x of[1.33,1.9]){prism('lamp',ngon(8,0.2),0.05,(u,v,t)=>[s*x+u,1.3+v,ZF+0.06+t]);ringPrism('chrome',8,0.2,0.26,0.08,(u,v,t)=>[s*x+u,1.3+v,ZF+0.07+t]);prism('lamp',ngon(8,0.07),0.02,(u,v,t)=>[s*x+u,1.3+v,ZF+0.1+t]);}}
 box('dark',0,1.3,ZF+0.03,1.9,0.52,0.06);
 for(let i=-3;i<=3;i++)box('chrome',i*0.24,1.3,ZF+0.06,0.035,0.5,0.04);
 box('chrome',0,1.58,ZF+0.06,2.04,0.06,0.06);box('chrome',0,1.02,ZF+0.06,2.04,0.06,0.06);
 for(const s of[1,-1]){box('chrome',s*0.99,1.3,ZF+0.06,0.06,0.62,0.06);nozzle(s*0.5,1.3,ZF+0.04,0.55,0.2,2);}
 // hood bulge scoops + hood pins
 for(const s of[1,-1]){const zc=4.0,y0=interp(HT,zc);box('dark',s*0.85,y0+0.04,zc,0.7,0.08,1.5);prism('chrome',[[-0.3,0],[0.3,0],[0.34,0.16],[0.2,0.3],[-0.2,0.3],[-0.34,0.16]],1.4,(u,v,t)=>[s*0.85+u,y0+0.08+v,zc+t]);
  for(let i=0;i<5;i++)box('glow',s*0.85,y0+0.34,zc-0.55+i*0.28,0.5,0.02,0.1);
  cyl('chrome',[s*1.35,interp(HT,4.7),4.7],[s*1.35,interp(HT,4.7)+0.06,4.7],0.06,8);}
 // rear: twin fuel tanks on the deck, manifold + gauge
 for(const s of[1,-1]){const y=interp(FT,-3.7)-0.02;box('dark',s*0.95,y+0.04,-3.8,0.3,0.08,2.4);tank('tank',[s*0.95,y+0.55,-2.7],[s*0.95,y+0.55,-4.9],0.5);
  for(const zz of[-3.1,-4.5])box('chrome2',s*0.95,y+0.2,zz,0.16,0.4,0.16);}
 cyl('chrome',[-0.95,3.0,-2.95],[0.95,3.0,-2.95],0.07,6);gauge(0,3.0,-2.95,0.17);
 hose('dark',[[0.95,3.0,-2.95],[1.7,2.8,-2.8],[2.45,2.3,-2.6]],0.075);hose('dark',[[-0.95,3.0,-2.95],[-1.7,2.8,-2.8],[-2.45,2.3,-2.6]],0.075);
 // doors: orange flame stripes
 flames('acc',1.5,-0.9,0.9,[0.72,0.5,0.8,0.56,0.7,0.44],0.014,false);flames('flame2',1.5,-0.9,0.9,[0.72,0.5,0.8,0.56,0.7,0.44],0.02,true);
 for(const s of[1,-1]){const X=s*3.04,Y=0.76;cyl('chrome',[X,Y,1.6],[X,Y,-1.3],0.12,8);for(const zz of[1.2,0.3,-0.6])cyl('acc',[X,Y,zz],[X,Y,zz-0.14],0.145,8);
  for(const zb of[0.95,-0.75])box('dark',s*2.92,Y+0.02,zb,0.22,0.06,0.1);}
}
// side fuel line + clamps
function sidePipe(band,r0){for(const s of[1,-1]){const X=s*3.04,Y=0.76;cyl('chrome',[X,Y,1.6],[X,Y,-1.3],r0,8);for(const zz of[1.2,0.3,-0.6])cyl(band,[X,Y,zz],[X,Y,zz-0.14],r0*1.2,8);
  for(const zb of[0.95,-0.75])box('dark',s*2.92,Y+0.02,zb,0.22,0.06,0.1);}}
if(V===1){
 // ---- Dragon Furnace: snarling snout, nozzle in the throat, horns, spine, back tanks ----
 box('dark',0,1.3,ZF+0.03,1.9,0.52,0.06);box('glow',0,1.3,ZF+0.065,1.5,0.1,0.01);
 for(const s of[1,-1]){
  // slanted eye slits + brows
  const eye=[[-0.45*s,-0.04],[0.45*s,0.2],[0.45*s,0.36],[-0.45*s,0.12]];
  prism('trim',eye.map(p=>[p[0]*1.18,p[1]+0.04]),0.1,(u,v,t)=>[s*1.55+u,1.5+v,ZF+0.04+t]);
  prism('lamp',eye,0.05,(u,v,t)=>[s*1.55+u,1.45+v,ZF+0.09+t]);
  box('dark',s*1.55,1.55,ZF+0.12,0.07,0.22,0.02);
  // brow ridge
  prism('body',[[-0.6*s,0.0],[0.6*s,0.3],[0.6*s,0.5],[-0.6*s,0.28]],0.12,(u,v,t)=>[s*1.55+u,1.78+v,ZF-0.3+t]);
  // corner fangs on the bumper
  bone('bone',s*1.15,0.95,1.6,ZF+0.12,0.16);bone('bone',s*0.75,0.95,1.38,ZF+0.12,0.12);}
 for(let i=-3;i<=3;i++){if(Math.abs(i)<1)continue;const x=i*0.3;bone('bone',x,1.62,1.2,ZF+0.1,0.09);}
 for(let i=-3;i<=3;i++){if(Math.abs(i)<1||Math.abs(i)===3)continue;bone('bone',i*0.3,0.98,1.34,ZF+0.1,0.09);}
 box('chrome',0,1.62,ZF+0.07,2.0,0.06,0.06);box('chrome',0,0.98,ZF+0.07,2.0,0.06,0.06);
 nozzle(0,1.3,ZF+0.02,0.7,0.22,2);
 // horns
 for(const s of[1,-1]){const H=[[1.4,2.32,4.3,0.27],[1.85,2.8,3.7,0.21],[2.3,3.35,2.95,0.15],[2.85,4.05,2.15,0.03]];
  for(let i=0;i<3;i++)cyl('bone',[s*H[i][0],H[i][1],H[i][2]],[s*H[i+1][0],H[i+1][1],H[i+1][2]],H[i][3],6,H[i+1][3]);
  ringPrism('chrome',8,0.24,0.34,0.1,(u,v,t)=>[s*1.4+u,2.3+v,4.3+t]);}
 // spine spikes on the hood and the deck
 for(const z of[3.9,3.2,2.5])cyl('bone',[0,interp(HT,z)-0.02,z],[0,interp(HT,z)+0.55,z-0.28],0.14,5,0.01);
 for(const z of[-3.0,-3.7,-4.4])cyl('bone',[0,interp(HT,z)-0.02,z],[0,interp(HT,z)+0.55,z-0.28],0.14,5,0.01);
 // hood vents
 for(const s of[1,-1])for(let i=0;i<4;i++)box('glow',s*0.95,interp(HT,3.8)+0.02,3.1+i*0.28,0.9,0.02,0.1);
 // back tanks, tilted like a pack, chrome Y manifold + gauge
 for(const s of[1,-1]){const y0=interp(HT,-3.5);box('chrome2',s*1.05,y0+0.1,-3.45,0.9,0.2,1.0);
  tank('tank',[s*1.05,y0+0.1,-3.55],[s*1.05,y0+2.2,-4.05],0.44,'chrome');
  cyl('chrome',[s*1.05,y0+2.2,-4.05],[s*1.05,y0+2.4,-4.1],0.14,6);hose('dark',[[s*1.05,y0+2.4,-4.1],[s*0.5,y0+2.6,-4.2],[0,y0+2.45,-4.25]],0.07);}
 gauge(0,interp(HT,-3.5)+2.45,-4.2,0.16);
 // twin stacks
 for(const s of[1,-1]){cyl('chrome',[s*2.2,2.45,-2.3],[s*2.2,3.45,-2.45],0.14,8,0.17);cyl('dark',[s*2.2,3.45,-2.45],[s*2.2,3.47,-2.45],0.15,8);box('glow',s*2.2,3.4,-2.45,0.14,0.04,0.14);}
 flames('acc',1.5,-0.9,0.92,[0.8,0.55,0.9,0.6,0.8,0.5],0.014,false);flames('flame2',1.5,-0.9,0.92,[0.8,0.55,0.9,0.6,0.8,0.5],0.02,true);
 sidePipe('acc',0.11);
}
if(V===2){
 // ---- Tanker Rod: rat-rod, giant fuel drum on the back, big cannon nozzle on the nose, roll cage ----
 for(const s of[1,-1]){cyl('chrome',[s*1.9,1.75,4.4],[s*1.9,2.35,4.4],0.05,6);
  prism('lamp',ngon(10,0.34),0.08,(u,v,t)=>[s*1.9+u,2.5+v,4.4+t+0.2]);ringPrism('chrome',10,0.34,0.44,0.14,(u,v,t)=>[s*1.9+u,2.5+v,4.4+t+0.2]);
  prism('trim',ngon(10,0.34),0.2,(u,v,t)=>[s*1.9+u,2.5+v,4.4+t]);}
 // radiator shell
 box('chrome',0,1.35,ZF+0.04,2.7,0.95,0.08);box('dark',0,1.35,ZF+0.07,2.4,0.7,0.04);
 for(let i=-5;i<=5;i++)box('chrome2',i*0.22,1.35,ZF+0.1,0.045,0.66,0.04);
 prism('acc',ngon(6,0.14),0.05,(u,v,t)=>[u,1.82+v,ZF+0.0+t]);
 // cannon nozzle + feed hose from the drum
 nozzle(0,1.35,ZF+0.0,1.3,0.34,3);box('chrome2',0,0.98,ZF+0.5,0.5,0.1,1.1);
 hose('dark',[[0,interp(HT,3.4)+0.1,3.4],[0,2.55,4.2],[0,2.2,4.85],[0,1.8,5.05]],0.1,6);
 for(const z of[3.4,4.2])box('chrome',0,interp(HT,z)+0.12+(z>4?0.35:0),z,0.34,0.14,0.14);
 // exposed header pipes along the hood
 for(const s of[1,-1]){hose('chrome',[[s*0.85,interp(HT,4.3)+0.1,4.4],[s*0.85,interp(HT,3.6)+0.12,3.6],[s*0.85,interp(HT,2.8)+0.12,2.4]],0.1,8);
  for(const z of[4.0,3.2])cyl('chrome2',[s*0.85,interp(HT,z)+0.05,z],[s*0.85,interp(HT,z)+0.22,z],0.14,8);}
 // roll cage + light bar
 for(const s of[1,-1])hose('chrome',[[s*1.55,2.4,-2.15],[s*1.5,3.55,-2.2],[s*1.5,3.6,-0.3],[s*1.55,2.9,0.0]],0.075,6);
 cyl('chrome',[-1.5,3.6,-2.2],[1.5,3.6,-2.2],0.075,6);cyl('chrome',[-1.5,3.6,-0.3],[1.5,3.6,-0.3],0.075,6);
 for(let i=-2;i<=2;i++){box('lamp',i*0.48,3.78,-0.3,0.34,0.2,0.1);}box('dark',0,3.66,-0.3,2.6,0.12,0.14);
 // giant fuel drum with hazard bands, hatch, level strip
 const dy=3.55;for(const z of[-2.6,-4.4])box('chrome2',0,dy-1.1,z,2.6,0.4,0.3);
 tank('tank',[0,dy,-2.0],[0,dy,-5.0],1.12,'acc');
 for(const s of[1,-1])box('glow',s*1.1,dy,-3.5,0.03,0.5,1.4);
 ringPrism('chrome',8,0.28,0.4,0.12,(u,v,t)=>[u,dy+1.1+t,-3.0+v],Math.PI/8);prism('dark',ngon(8,0.28,Math.PI/8),0.1,(u,v,t)=>[u,dy+1.1+t,-3.0+v]);
 gauge(0,dy+0.15,-1.95,0.25);
 hose('chrome',[[0,dy+1.1,-3.0],[0,dy+1.35,-3.0]],0.05);
 // hazard stripes on the doors
 for(let i=0;i<6;i++){const z=1.3-i*0.38;sideDecal('acc',[[z,0.9],[z-0.2,0.9],[z-0.5,1.5],[z-0.3,1.5]],0.014);}
 sidePipe('acc',0.13);
}
// ---------------- rear end (shared) ----------------
box('dark',0,1.55,ZR-0.01,4.6,0.9,0.04);
for(const s of[1,-1])for(const x of[1.3,1.95]){prism('tail',ngon(8,0.2),0.05,(u,v,t)=>[s*x+u,1.72+v,ZR-0.05+t]);ringPrism('chrome',8,0.2,0.26,0.08,(u,v,t)=>[s*x+u,1.72+v,ZR-0.06+t]);}
box('trim',0,1.72,ZR-0.04,1.6,0.34,0.05);box('acc',0,1.72,ZR-0.07,1.4,0.06,0.02);
box('plate',0,1.25,ZR-0.04,0.9,0.42,0.04);box('dark',0,1.25,ZR-0.07,0.7,0.12,0.02);
bar('chrome',-2.1,2.1,p=>[p[0],0.95+p[1],ZR-0.18-p[2]]);
for(const s of[1,-1]){box('chrome',s*2.3,0.95,ZR-0.1,0.6,0.3,0.36,rotY(-s*0.6));box('chrome',s*2.6,0.95,ZR+0.25,0.3,0.3,0.6);}
box('dark',0,0.66,ZR+0.2,3.6,0.14,0.7);
// front bumper (shared)
bar('chrome',-1.95,1.95,p=>[p[0],0.86+p[1],ZF+0.18+p[2]]);
for(const s of[1,-1]){const piv=[s*1.95,0.86,ZF+0.18];bar('chrome',0,0.7,p=>{const q=rotY(s*0.6)([p[0]*s,p[1],p[2]]);return[piv[0]+q[0],piv[1]+q[1],piv[2]+q[2]];});
 bar('chrome',0,0.6,p=>{const q=rotY(s*Math.PI/2)([p[0]*s,p[1],p[2]]);return[s*2.53+q[0],0.86+q[1],ZF-0.215+q[2]];});
 box('glow',s*1.45,0.86,ZF+0.385,0.42,0.1,0.02);box('chrome',s*0.75,0.98,ZF+0.27,0.12,0.1,0.14);}
box('dark',0,0.62,ZF-0.05,4.4,0.12,0.7);box('dark',0,0.58,ZF+0.3,3.6,0.05,0.2);
// ---------------- wheels ----------------
const D=2;
function wheel(Wh,s,id){KP=opt.splitWheels?id+':':'';const {x,y,z,r,w}=Wh;const P=(xo,rad,a)=>[s*x+s*xo,y+rad*Math.sin(a),z+rad*Math.cos(a)];
 const n=D===0?10:D===1?12:14;
 const prof=[[0.64*r,-w/2],[0.84*r,-w/2],[r,-w/2+0.13*w],[r,w/2-0.13*w],[0.84*r,w/2],[0.64*r,w/2]];
 for(let k=0;k<n;k++){const a0=k*2*Math.PI/n,a1=(k+1)*2*Math.PI/n;
  for(let j=0;j<prof.length;j++){const p=prof[j],q=prof[(j+1)%prof.length];const A=P(p[1],p[0],a0),Bq=P(q[1],q[0],a0),C=P(q[1],q[0],a1),D=P(p[1],p[0],a1);
   const ctr=[(A[0]+C[0])/2,(A[1]+C[1])/2,(A[2]+C[2])/2];const out=sub(ctr,[s*x,y,z]);const f=fnorm(A,Bq,C);
   if(f[0]*out[0]+f[1]*out[1]+f[2]*out[2]<0)quad('tire',A,D,C,Bq);else quad('tire',A,Bq,C,D);}}
 const pb=(k,x0,x1,r0,r1,a0,a1)=>{const C=[P(x0,r0,a0),P(x1,r0,a0),P(x1,r1,a0),P(x0,r1,a0),P(x0,r0,a1),P(x1,r0,a1),P(x1,r1,a1),P(x0,r1,a1)];
  [[0,3,2,1],[4,5,6,7],[0,1,5,4],[3,7,6,2],[0,4,7,3],[1,2,6,5]].forEach(f=>quad(k,C[f[0]],C[f[1]],C[f[2]],C[f[3]]));};
 // tread blocks
 if(D>=2)for(let k=0;k<n*2;k++){const a=(k+0.5)*Math.PI/n,h=Math.PI/n*0.42;const off=(k%2)?0.12*w:-0.12*w;
  pb('tire',off-0.22*w,off+0.22*w,r-0.01,r+0.045,a-h,a+h);}
 // green pin line on the sidewall
 const O=w/2;for(let k=0;k<n;k++){const a0=k*2*Math.PI/n,a1=(k+1)*2*Math.PI/n;if(D>=1)pb('acc',O-0.005,O+0.012,0.76*r,0.8*r,a0,a1);
  pb('dark',O-0.32,O-0.28,0,0.64*r,a0,a1);
  if(D>=1)pb('chrome',O-0.07,O+0.02,0.58*r,0.66*r,a0,a1);
  if(D>=2)pb('acc',O-0.16,O-0.06,0.48*r,0.58*r,a0,a1);}
 for(let i=0;i<5;i++){const a=i*2*Math.PI/5+Math.PI/2;pb('acc',O-0.2,O-0.09,0.17*r,0.5*r,a-0.2,a+0.2);pb('dark',O-0.2,O-0.1,0.2*r,0.47*r,a+Math.PI/5-0.03,a+Math.PI/5+0.03);}
 for(let k=0;k<10;k++){const a0=k*Math.PI/5,a1=(k+1)*Math.PI/5;pb('chrome',O-0.22,O-0.03,0,0.2*r,a0,a1);if(D>=1)pb('acc',O-0.03,O+0.0,0,0.08*r,a0,a1);}
 if(D>=2)for(let i=0;i<5;i++){const a=i*2*Math.PI/5+Math.PI/2+Math.PI/5;pb('chrome2',O-0.04,O+0.02,0.11*r,0.16*r,a-0.13,a+0.13);}
}
// nose +Z, so the car's left is +X: FL = front, +X
for(const s of[1,-1]){wheel(FW,s,s>0?'FL':'FR');wheel(RW,s,s>0?'RL':'RR');}KP='';

// Outward winding for every piece: the page draws both sides, but Roblox hides back faces. Triangles that
// share an edge are made to agree, then a closed piece with negative volume is turned inside out.
function orient(arr){const n=arr.length/9;if(!n)return arr;
 const ids=new Map(),P=[];const vid=(x,y,z)=>{const k=Math.round(x*2e4)+','+Math.round(y*2e4)+','+Math.round(z*2e4);let i=ids.get(k);if(i===undefined){i=P.length;ids.set(k,i);P.push([x,y,z]);}return i;};
 const T=[];for(let t=0;t<n;t++)T.push([vid(arr[t*9],arr[t*9+1],arr[t*9+2]),vid(arr[t*9+3],arr[t*9+4],arr[t*9+5]),vid(arr[t*9+6],arr[t*9+7],arr[t*9+8])]);
 const E=new Map();const ek=(a,b)=>a<b?a*1e6+b:b*1e6+a;
 T.forEach((v,t)=>{for(let i=0;i<3;i++){const a=v[i],b=v[(i+1)%3];if(a===b)continue;const k=ek(a,b);(E.get(k)||E.set(k,[]).get(k)).push(t);}});
 const flip=new Uint8Array(n),comp=new Int32Array(n).fill(-1);
 const dirs=(t)=>{const v=flip[t]?[T[t][0],T[t][2],T[t][1]]:T[t];return[[v[0],v[1]],[v[1],v[2]],[v[2],v[0]]];};
 let nc=0;const out=arr.slice();
 for(let s=0;s<n;s++){if(comp[s]>=0)continue;const q=[s];comp[s]=nc;const members=[s];let closed=true;
  while(q.length){const t=q.pop();for(const [a,b] of dirs(t)){if(a===b)continue;const L=E.get(ek(a,b));if(L.length!==2){closed=false;continue;}
    const u=L[0]===t?L[1]:L[0];if(comp[u]>=0)continue;
    // u must walk this edge as b->a
    const same=dirs(u).some(([x,y])=>x===a&&y===b);if(same)flip[u]^=1;comp[u]=nc;members.push(u);q.push(u);}}
  if(closed){let vol=0;for(const t of members){const v=flip[t]?[T[t][0],T[t][2],T[t][1]]:T[t];const A=P[v[0]],B=P[v[1]],C=P[v[2]];
    vol+=A[0]*(B[1]*C[2]-B[2]*C[1])-A[1]*(B[0]*C[2]-B[2]*C[0])+A[2]*(B[0]*C[1]-B[1]*C[0]);}
   if(vol<0)for(const t of members)flip[t]^=1;}
  nc++;}
 for(let t=0;t<n;t++)if(flip[t]){for(let a=0;a<3;a++){const x=out[t*9+3+a];out[t*9+3+a]=out[t*9+6+a];out[t*9+6+a]=x;}}
 return out;}
if(opt.orient!==false){ // all pieces at once: a surface split across colours is one closed shape
 const keys=Object.keys(bufs),all=[];for(const k of keys)for(const v of bufs[k])all.push(v);
 const fixed=orient(all);let at=0;for(const k of keys){const n=bufs[k].length;bufs[k]=fixed.slice(at,at+n);at+=n;}}
return{bufs,COL,NEON,FW,RW};};
