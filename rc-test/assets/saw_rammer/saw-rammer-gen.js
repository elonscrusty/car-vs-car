// Saw Rammer (car 7, carter picked the Road Saw 10-30; Big Saw + Twin Saws are skins): same style + High detail as the Toxic Hot Rod. Faceted low-poly body lofted from rings along Z (nose +Z, up +Y,
// ground y = 0, car left = +X). A buzzsaw is built INTO the nose: opt.saw = 'plow' (road saw, the car) | 'nose' (big saw skin) | 'twin' (twin saws skin)
// | 'none'. The saw kit has its own colour keys ('kit:acc', ...); the blades (sawB/sawH) are centred on their spin axis.
// Returns {bufs,COL,NEON,spins}.
window.genSawRam=function(opt){
opt=opt||{};const D=opt.detail===undefined?2:opt.detail;   // 0 low, 1 middle, 2 high
const ACC=opt.acc||[255,112,18];
const COL={body:[34,36,42],acc:ACC,glass:[14,20,32],chrome:[205,210,220],chrome2:[150,155,165],dark:[9,9,11],tire:[22,22,26],trim:[54,56,62],sawB:[150,156,170],sawH:ACC,sawBL:[150,156,170],sawBR:[150,156,170],sawHL:ACC,sawHR:ACC,belt:[18,18,18]};
const NEON={lamp:opt.lamp||[255,238,150],glow:opt.glow||[255,150,40],tail:[255,36,36],plate:[235,240,225]};
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

// ---------------- layout ----------------
const FW={z:2.75,y:1.0,r:1.0,R:1.15,w:1.1,x:2.5};      // front wheel
const RW={z:-2.75,y:1.1,r:1.1,R:1.25,w:1.3,x:2.6};     // rear wheel (a bit fatter)
const SILL=0.6;
const ZF=4.5, ZR=-4.9;
const WT=[[4.5,2.4],[4.35,2.58],[4.05,2.72],[3.6,2.8],[2.75,2.82],[1.9,2.8],[-1.0,2.8],[-1.6,2.95],[-2.75,3.1],[-4.0,3.1],[-4.6,2.98],[-4.9,2.85]];
const FT=[[4.5,1.75],[4.35,1.92],[4.05,2.12],[3.6,2.3],[2.75,2.42],[1.9,2.34],[1.3,2.16],[-1.0,2.16],[-1.6,2.36],[-2.75,2.62],[-4.0,2.6],[-4.6,2.4],[-4.9,2.25]];
const HT=[[4.5,1.7],[4.35,1.84],[4.05,1.95],[3.6,2.0],[2.75,2.04],[1.9,2.07],[1.3,2.1],[-1.2,2.12],[-2.9,2.14],[-4.0,2.14],[-4.6,2.12],[-4.9,2.2]];
const ST=[];
const st=(z,yb)=>ST.push({z,yb});
st(ZF,0.85);st(4.35,0.72);st(4.05,SILL);st(3.95,SILL);
const AN=D===0?4:D===1?6:8;
function arch(Wh){st(Wh.z+Wh.R,SILL);for(let i=0;i<=AN;i++){const g=i*Math.PI/AN;st(Wh.z+Wh.R*Math.cos(g),Wh.y+Wh.R*Math.sin(g));}st(Wh.z-Wh.R,SILL);}
arch(FW);[1.2,0.6,0,-0.6,-1.1].forEach(z=>st(z,SILL));arch(RW);
[-4.2,-4.5].forEach(z=>st(z,SILL));st(-4.72,0.72);st(ZR,0.85);
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
// wheel well liners so you can't see through
for(const Wh of[FW,RW])for(const s of[1,-1]){box('dark',s*1.9,(SILL+Wh.y+Wh.R)/2,Wh.z,0.06,Wh.y+Wh.R-SILL,2*Wh.R);
 box('dark',0,Wh.y+Wh.R-0.05,Wh.z,3.8,0.06,2*Wh.R);}

// ---------------- cabin (short, set back, flat roof) ----------------
const CS=[[1.7,2.2,2.17,2.27,2.0],[0.3,2.15,2.2,2.97,1.62],[-0.25,2.15,2.2,3.0,1.62],[-0.55,2.15,2.2,3.0,1.62],[-1.5,2.15,2.2,2.97,1.62],[-2.6,2.2,2.2,2.3,1.98]];
const CLR=['cbase','cside','cedge','roof','rstripe'];const CLAB=[...CLR,'rgap',...CLR.slice().reverse(),'cfloor'];
const cabR=CS.map(([z,wb,ybl,yr,wr])=>{const R=[[wb,1.95],[wb,ybl],[Math.min(wb-0.02,wr+0.24),Math.max(ybl,yr-0.12)],[wr,yr],[0.62,yr],[0.12,yr]];const L=R.slice().reverse().map(p=>[-p[0],p[1]]);return[...R,...L].map(p=>[p[0],p[1],z]);});
loftL(cabR,CLAB,(c,n,lab,i)=>{
 if(lab==='cfloor')return'dark';
 if(lab==='cbase'||lab==='cedge')return'body';
 if(lab==='cside')return(i===2||i===4)?'body':'glass';
 if(i===0||i===4)return'glass';
 return lab==='rstripe'?'acc':'body';},true,'body');
// chrome window trim along the belt + drip rails
if(D>=1)for(const s of[1,-1]){box('chrome',s*2.19,2.2,-0.45,0.05,0.05,4.2);
 cyl('chrome',[s*1.74,2.95,0.3],[s*1.74,2.98,-1.5],0.035,6);}

// ---------------- side details ----------------
const DW=2.8; // door width (flat area)
function sideDecal(k,pts,off){const tr=triangulate(pts);for(const s of[1,-1])for(const t of tr){const P=t.map(i=>[s*(DW+off),pts[i][1],pts[i][0]]);if(s>0)tri(k,P[0],P[2],P[1]);else tri(k,P[0],P[1],P[2]);}}
// saw-tooth band along the belt line (teeth hang down)
(function(){const top=1.71,base=1.56,z0=1.45,z1=-1.45;
 if(D===0){sideDecal('acc',[[z0,top],[z1,top],[z1,base-0.1],[z0,base-0.1]],0.014);return;}
 const P=[[z0,top],[z1,top],[z1,base]];
 for(let z=z1;z<z0-0.27;z+=0.27){P.push([z,base],[z+0.04,base-0.2],[z+0.27,base]);}
 P.push([z0,base]);
 sideDecal('acc',P,0.014);
 sideDecal('acc',[[z0,1.745],[z1,1.745],[z1,1.765],[z0,1.765]],0.014);})();
// saw-blade emblem on the door
if(D>=1)(function(){const zc=0.3,yc=1.02,NT=14;const star=[];
 for(let i=0;i<NT;i++){const a=i*2*Math.PI/NT;const a1=a+0.2*(2*Math.PI/NT),a2=a+2*Math.PI/NT;
  star.push([zc+Math.cos(a)*0.3,yc+Math.sin(a)*0.3],[zc+Math.cos(a1)*0.4,yc+Math.sin(a1)*0.4]);}
 sideDecal('acc',star,0.016);
 sideDecal('dark',ngon(14,0.22,0).map(p=>[zc+p[0],yc+p[1]]),0.022);
 sideDecal('acc',ngon(10,0.12,0).map(p=>[zc+p[0],yc+p[1]]),0.028);
 sideDecal('dark',ngon(6,0.045,0).map(p=>[zc+p[0],yc+p[1]]),0.034);})();
// door seams + handle
if(D>=1)for(const zz of[1.52,-0.92])sideDecal('dark',[[zz+0.018,0.78],[zz+0.018,1.78],[zz-0.018,1.78],[zz-0.018,0.78]],0.008);
for(const s of[1,-1]){if(D>=1)box('chrome',s*2.85,1.47,-0.68,0.06,0.07,0.32);
 // mirror
 cyl('dark',[s*2.62,2.13,1.48],[s*2.98,2.3,1.42],0.04,6);box('dark',s*3.06,2.33,1.4,0.14,0.22,0.36);if(D>=1)box('chrome',s*3.06,2.33,1.21,0.1,0.18,0.03);
 // gas cap on the rear hip
 if(D>=2){const zf=-3.45,tf=interp(FT,zf),wf=interp(WT,zf);cyl('chrome',[s*(wf-0.52),tf-0.01,zf],[s*(wf-0.52),tf+0.04,zf],0.14,8,0.14,0);}
 // heavy side skirt with spikes
 box('dark',s*2.9,0.72,0.1,0.2,0.2,2.8);
 if(D>=1)for(let i=0;i<6;i++){cyl('chrome',[s*2.98,0.72,1.25-i*0.5],[s*3.28,0.72,1.25-i*0.5],0.07,6,0.0,0);}
}
// smoke stacks behind the cab
for(const s of[1,-1]){const x=s*1.75,z=-3.1,y0=interp(FT,z)-0.1;
 cyl('dark',[x,y0,z],[x,y0+1.2,z],0.17,8);
 if(D>=1){cyl('chrome',[x,y0+1.15,z],[x,y0+1.32,z],0.2,8);cyl('glow',[x,y0+1.325,z],[x,y0+1.33,z],0.14,8);}
 if(D>=2){cyl('chrome2',[x,y0+0.35,z],[x,y0+0.45,z],0.22,8);cyl('chrome2',[x,y0+0.8,z],[x,y0+0.9,z],0.22,8);}
 box('dark',x,y0+0.02,z+0.2,0.16,0.3,0.4);}

// ---------------- front (armoured nose, the saw bolts to it) ----------------
box('dark',0,1.3,ZF+0.01,4.4,0.74,0.04);
box('dark',0,1.3,ZF+0.03,1.9,0.52,0.06);
box('chrome',0,1.58,ZF+0.06,2.04,0.06,0.06);box('chrome',0,1.02,ZF+0.06,2.04,0.06,0.06);
for(const s of[1,-1])box('chrome',s*0.99,1.3,ZF+0.06,0.06,0.62,0.06);
for(let i=-3;i<=3;i+=(D===0?3:1))box('chrome',i*0.24,1.3,ZF+0.06,0.035,0.5,0.04);
// big octagon lamps at the outer corners (the saw covers the middle)
for(const s of[1,-1]){box('trim',s*2.02,1.3,ZF+0.02,0.74,0.62,0.05);
 prism('lamp',ngon(8,0.25),0.05,(u,v,t)=>[s*2.02+u,1.3+v,ZF+0.06+t]);
 if(D>=1)ringPrism('chrome',8,0.25,0.31,0.08,(u,v,t)=>[s*2.02+u,1.3+v,ZF+0.07+t]);
 if(D>=2)prism('lamp',ngon(8,0.09),0.02,(u,v,t)=>[s*2.02+u,1.3+v,ZF+0.1+t]);}
// chrome wrap bumper (faceted cross-section)
const BCS=[[-0.17,-0.15],[0.1,-0.15],[0.2,-0.06],[0.2,0.07],[0.1,0.15],[-0.17,0.15]];
function bar(k,x0,x1,place){prism(k,BCS,x1-x0,(u,v,t)=>place([(x0+x1)/2+t,v,u]));}
bar('chrome',-2.0,2.0,p=>[p[0],0.86+p[1],ZF+0.18+p[2]]);
if(D>=1)for(const s of[1,-1]){const piv=[s*2.0,0.86,ZF+0.18];bar('chrome',0,0.6,p=>{const q=rotY(s*0.6)([p[0]*s,p[1],p[2]]);return[piv[0]+q[0],piv[1]+q[1],piv[2]+q[2]];});
 box('glow',s*1.45,0.86,ZF+0.385,0.42,0.1,0.02);
 if(D>=2)box('chrome',s*0.75,0.98,ZF+0.27,0.12,0.1,0.14);}
box('dark',0,0.62,ZF-0.05,4.4,0.12,0.7);box('dark',0,0.58,ZF+0.3,3.6,0.05,0.2);

// ---------------- rear ----------------
box('dark',0,1.55,ZR-0.01,4.6,0.9,0.04);
for(const s of[1,-1])for(const x of[1.3,1.95]){prism('tail',ngon(8,0.2),0.05,(u,v,t)=>[s*x+u,1.72+v,ZR-0.05+t]);if(D>=1)ringPrism('chrome',8,0.2,0.26,0.08,(u,v,t)=>[s*x+u,1.72+v,ZR-0.06+t]);}
box('trim',0,1.72,ZR-0.04,1.6,0.34,0.05);box('acc',0,1.72,ZR-0.07,1.4,0.06,0.02);
box('plate',0,1.25,ZR-0.04,0.9,0.42,0.04);box('dark',0,1.25,ZR-0.07,0.7,0.12,0.02);
bar('chrome',-2.1,2.1,p=>[p[0],0.95+p[1],ZR-0.18-p[2]]);
if(D>=1)for(const s of[1,-1]){box('chrome',s*2.3,0.95,ZR-0.1,0.6,0.3,0.36,rotY(-s*0.6));box('chrome',s*2.6,0.95,ZR+0.25,0.3,0.3,0.6);}
box('dark',0,0.66,ZR+0.2,3.6,0.14,0.7);
if(D>=2)for(let i=-3;i<=3;i++)box('dark',i*0.45,0.55,ZR+0.05,0.05,0.2,0.5);

// ---------------- roof weapon spot (flat steel plate, shared weapons clip on here) ----------------
(function(){const zc=-0.4,y=3.0;
 prism('trim',ngon(8,0.8,Math.PI/8),0.06,(u,v,t)=>[u,y+t,zc+v]);
 if(D>=1)ringPrism('chrome',8,0.8,0.9,0.05,(u,v,t)=>[u,y+0.02+t,zc+v],Math.PI/8);
 if(D>=2)for(let i=0;i<8;i++){const a=i*Math.PI/4+Math.PI/8;cyl('chrome2',[Math.cos(a)*0.62,y+0.03,zc+Math.sin(a)*0.62],[Math.cos(a)*0.62,y+0.1,zc+Math.sin(a)*0.62],0.06,6);}
})();

// ---------------- THE BUZZSAW (built into the nose) ----------------
// A frame puts a flat disc anywhere: local x/y = the disc plane, local z = its spin axis.
function frame(C,yaw,pitch,roll){const f=rotY(yaw),g=rotX(pitch);const h=rotZ(roll||0);
 return(u,v,t)=>{const p=f(g(h([u,v,t])));return[C[0]+p[0],C[1]+p[1],C[2]+p[2]];};}
const rotZ=g=>{const c=Math.cos(g),s=Math.sin(g);return p=>[p[0]*c-p[1]*s,p[0]*s+p[1]*c,p[2]];};
// a piece of a ring (angles a0..a1, rad), thickness t
function annSector(k,r0,r1,a0,a1,t,map,segs){segs=segs||Math.max(2,Math.ceil((a1-a0)/(Math.PI/10)));
 for(let i=0;i<segs;i++){const p=a0+(a1-a0)*i/segs,q=a0+(a1-a0)*(i+1)/segs;
  const O=a=>[Math.cos(a)*r1,Math.sin(a)*r1],I=a=>[Math.cos(a)*r0,Math.sin(a)*r0];
  const F=pt=>map(pt[0],pt[1],-t/2),K=pt=>map(pt[0],pt[1],t/2);
  quad(k,F(O(p)),F(O(q)),F(I(q)),F(I(p)));quad(k,K(O(p)),K(I(p)),K(I(q)),K(O(q)));
  quad(k,F(O(p)),K(O(p)),K(O(q)),F(O(q)));quad(k,F(I(p)),F(I(q)),K(I(q)),K(I(p)));}
 for(const a of[a0,a1]){const O=[Math.cos(a)*r1,Math.sin(a)*r1],I=[Math.cos(a)*r0,Math.sin(a)*r0];
  quad(k,map(O[0],O[1],-t/2),map(O[0],O[1],t/2),map(I[0],I[1],t/2),map(I[0],I[1],-t/2));}}
// ratchet teeth ring: N hooked teeth from radius rb out to rt, ring starts at rin
function toothRing(k,N,rin,rb,rt,t,map,hook){const st2=2*Math.PI/N;
 const P=a=>[Math.cos(a),Math.sin(a)];const at=(r,a)=>{const q=P(a);return[q[0]*r,q[1]*r];};
 const F=pt=>map(pt[0],pt[1],-t/2),K=pt=>map(pt[0],pt[1],t/2);
 for(let i=0;i<N;i++){const a0=i*st2,a1=a0+hook*st2,a2=a0+st2;
  const I0=at(rin,a0),I1=at(rin,a1),I2=at(rin,a2),O0=at(rb,a0),O1=at(rt,a1),O2=at(rb,a2);
  quad(k,F(I0),F(O0),F(O1),F(I1));quad(k,F(I1),F(O1),F(O2),F(I2));
  quad(k,K(I0),K(I1),K(O1),K(O0));quad(k,K(I1),K(I2),K(O2),K(O1));
  quad(k,F(O0),K(O0),K(O1),F(O1));quad(k,F(O1),K(O1),K(O2),F(O2));
  quad(k,F(I0),F(I1),K(I1),K(I0));quad(k,F(I1),F(I2),K(I2),K(I1));}}
// one saw: blade (steel, spins), hub (accent, spins). B/H = the colour keys, R = outer radius
function sawBlade(B,H,R,map,NT,TH){TH=TH||0.15;
 toothRing(B,NT,R*0.66,R*0.9,R,TH,map,0.22);
 // spokes between the hub and the tooth ring (the gaps are lightening holes)
 for(let i=0;i<6;i++){const a=i*Math.PI/3;annSector(B,R*0.22,R*0.68,a+0.12,a+Math.PI/3-0.12,TH,map);}
 annSector(B,R*0.2,R*0.3,0,Math.PI*2,0.2,map,12);
 // hub: dark ring, orange boss, chrome cap, bolts
 prism(H,ngon(12,R*0.22),0.3,(u,v,t)=>map(u,v,t));
 prism(H,ngon(8,R*0.12),0.46,(u,v,t)=>map(u,v,t));
 if(D>=1)for(let i=0;i<6;i++){const a=i*Math.PI/3;cyl(B,map(Math.cos(a)*R*0.17,Math.sin(a)*R*0.17,0.15),map(Math.cos(a)*R*0.17,Math.sin(a)*R*0.17,0.28),0.035*R/1.5,6);}
 // a ring of orange paint on the plate
 if(D>=1)annSector(H,R*0.6,R*0.66,0,Math.PI*2,TH+0.02,map,16);
}
const spins=[];
const SAW=opt.saw||'plow';
KP=SAW==='none'?'':'kit:';   // the saw kit keeps its own colour keys ('kit:acc', ...) so skins can swap it
if(SAW==='nose'){
 // ONE giant vertical saw, raked back a little, behind a steel guard; a fat axle + braces bolt it to the nose
 const R=1.5,C=[0,1.7,ZF+1.15],M=frame(C,0,-0.12);
 sawBlade('sawB','sawH',R,M,22);
 spins.push({keys:['sawB','sawH'],center:C,axis:nrm(sub(M(0,0,1),M(0,0,0)))});
 cyl('chrome2',M(0,0,-1.15),M(0,0,-0.15),0.3,10);
 cyl('chrome',M(0,0,-0.95),M(0,0,-0.8),0.4,10);cyl('chrome',M(0,0,-0.35),M(0,0,-0.2),0.38,10);
 box('trim',0,1.5,ZF+0.2,2.6,1.7,0.3);
 box('acc',0,2.38,ZF+0.2,2.6,0.1,0.34);box('acc',0,0.62,ZF+0.2,2.6,0.1,0.34);
 for(const s of[1,-1]){ // braces: low and high, nose corner to axle
  cyl('chrome2',[s*1.3,0.7,ZF+0.2],M(s*0.12,-0.25,-0.8),0.13,8);
  cyl('chrome2',[s*1.3,2.3,ZF+0.2],M(s*0.12,0.25,-0.8),0.13,8);}
 // upper guard: orange arc over the top half of the blade, held by two steel struts
 annSector('acc',R*1.06,R*1.3,0.18,Math.PI-0.18,0.5,(u,v,t)=>M(u,v,t-0.3),14);
 annSector('chrome',R*1.3,R*1.33,0.18,Math.PI-0.18,0.52,(u,v,t)=>M(u,v,t-0.3),14);
 for(const s of[1,-1]){const a=M(s*R*1.18,0.28,-0.3);cyl('chrome2',a,[s*1.2,2.1,ZF+0.3],0.11,8);}
} else if(SAW==='twin'){
 // TWO medium saws at the front corners, splayed out; a steel wedge ram between them
 const R=1.2;
 for(const s of[1,-1]){
  const C=[s*1.85,1.35,ZF+0.85],M=frame(C,s*0.32,-0.12);const id=s>0?'L':'R';
  sawBlade('sawB'+id,'sawH'+id,R,M,18);
  spins.push({keys:['sawB'+id,'sawH'+id],center:C,axis:nrm(sub(M(0,0,1),M(0,0,0)))});
  cyl('chrome2',M(0,0,-0.95),M(0,0,-0.2),0.22,10);
  cyl('chrome',M(0,0,-0.7),M(0,0,-0.6),0.3,10);
  box('trim',s*1.85,1.35,ZF+0.15,1.5,1.5,0.2);
  cyl('chrome2',[s*2.4,0.8,ZF+0.2],M(0,-0.3,-0.55),0.11,8);cyl('chrome2',[s*1.0,2.1,ZF+0.2],M(0,0.3,-0.55),0.11,8);
  const G=frame(C,s*0.32,-0.12);
  annSector('acc',R*1.06,R*1.28,0.2,Math.PI-0.2,0.45,(u,v,t)=>G(u,v,t-0.3),12);
  annSector('chrome',R*1.28,R*1.31,0.2,Math.PI-0.2,0.47,(u,v,t)=>G(u,v,t-0.3),12);
  const a=G(0,-R*1.05,-0.3);cyl('chrome2',a,[s*1.85,0.9,ZF+0.2],0.1,8);
 }
 // centre ram: armoured wedge with orange tip and a glowing slot
 const W=[[ZF-0.1,0.6],[ZF+1.7,0.9],[ZF+1.7,1.2],[ZF+0.6,1.78],[ZF-0.1,1.78]];
 prism('chrome2',W,1.0,(u,v,t)=>[t,v,u]);
 prism('acc',[[ZF+1.2,0.92],[ZF+1.72,0.92],[ZF+1.72,1.17],[ZF+1.2,1.4]],1.04,(u,v,t)=>[t,v,u]);
 prism('glow',[[ZF+0.45,1.42],[ZF+0.85,1.55],[ZF+0.85,1.6],[ZF+0.45,1.5]],0.5,(u,v,t)=>[t,v,u]);
 for(const s of[1,-1])cyl('chrome',[s*0.5,0.95,ZF+0.2],[s*0.5,1.1,ZF+1.5],0.07,6);
} else if(SAW==='plow'){
 // LOW road saw: a flat saw lying under a steel plough nose, blade ripping the ground ahead
 const R=1.85,C=[0,0.62,ZF+1.65],M=frame(C,0,-Math.PI/2);
 sawBlade('sawB','sawH',R,M,22,0.24);
 spins.push({keys:['sawB','sawH'],center:C,axis:nrm(sub(M(0,0,1),M(0,0,0)))});
 // axle stem + cover plate over the back half of the blade
 cyl('chrome2',[0,0.8,ZF+0.2],[0,1.0,C[2]],0.3,10);
 const G=frame([0,1.02,C[2]],0,-Math.PI/2);
 annSector('acc',R*0.28,R*1.1,0.15,Math.PI-0.15,0.2,G,12);
 annSector('chrome',R*1.1,R*1.14,0.15,Math.PI-0.15,0.22,G,12);
 prism('chrome2',ngon(10,R*0.28),0.22,G);
 // plough wedge from the nose up over the cover, with two stout arms
 prism('trim',[[ZF-0.1,0.5],[ZF+1.3,0.85],[ZF+1.3,1.05],[ZF-0.1,1.75]],2.6,(u,v,t)=>[t,v,u]);
 prism('acc',[[ZF+0.9,0.84],[ZF+1.32,0.9],[ZF+1.32,1.08],[ZF+0.9,1.3]],2.64,(u,v,t)=>[t,v,u]);
 for(const s of[1,-1]){cyl('chrome2',[s*1.2,0.8,ZF+0.2],[s*1.2,0.95,C[2]+0.2],0.14,8);
  box('glow',s*1.45,0.86,ZF+0.43,0.42,0.1,0.02);}
}

KP='';
// ---------------- wheels ----------------
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
return{bufs,COL,NEON,FW,RW,spins};};
