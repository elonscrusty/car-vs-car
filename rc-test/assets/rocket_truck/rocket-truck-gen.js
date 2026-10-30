// Rocket Truck (car 3): heavy pickup with the rocket pods built INTO the body. Same faceted low-poly lofted-ring
// style as the Toxic Hot Rod (nose +Z, up +Y, ground y = 0, car left = +X). One generator for the preview page
// and the game files: opt.variant 0 Blast Hauler (bed battery) / 1 Missile Mule (twin bed pods) / 2 Fender Fury
// (nose pods); opt.splitWheels keeps each wheel apart. Returns {bufs,COL,NEON,FW,RW}.
window.genRocketTruck=function(opt){
opt=opt||{};const V=opt.variant||0;const D=2;
const ACCS=[[255,112,22],[232,40,44],[255,206,26]];
const ACC=opt.acc||ACCS[V];
const COL={body:[22,23,28],acc:ACC,glass:[24,38,60],chrome:[205,210,220],chrome2:[150,155,165],dark:[9,9,11],tire:[22,22,26],trim:[40,42,48],belt:[18,18,18],bed:[30,31,37],warhead:ACC};
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
const FW={z:3.5,y:1.25,r:1.25,R:1.42,w:1.25,x:2.62};
const RW={z:-3.6,y:1.25,r:1.25,R:1.42,w:1.4,x:2.62};
const SILL=0.8,W0=3.1,ZF=5.35,ZR=-5.35;
const WT=[[5.35,2.7],[5.2,2.95],[4.85,3.1],[-4.9,3.1],[-5.2,2.95],[-5.35,2.75]];
const FT=[[5.35,2.95],[5.2,3.15],[4.9,3.4],[-4.9,3.4],[-5.2,3.2],[-5.35,3.05]];
const HT=[[5.35,3.05],[5.0,3.5],[4.7,3.62],[2.45,3.62],[2.15,3.4],[-5.35,3.4]];
const ST=[];
const st=(z,yb)=>ST.push({z,yb});
st(5.35,0.95);st(5.2,0.85);st(4.85,SILL);
const AN=8;
function arch(Wh){st(Wh.z+Wh.R,SILL);for(let i=0;i<=AN;i++){const g=i*Math.PI/AN;st(Wh.z+Wh.R*Math.cos(g),Wh.y+Wh.R*Math.sin(g));}st(Wh.z-Wh.R,SILL);}
arch(FW);[2.3,1.2,0.2,-0.6,-1.3].forEach(z=>st(z,SILL));arch(RW);
[-5.0].forEach(z=>st(z,SILL));st(-5.2,0.85);st(-5.35,0.95);
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
 if(lab==='stripe'&&c[2]>2.6)return'acc';
 return'body';},true,'body');
// wheel well liners so you can't see through
for(const Wh of[FW,RW])for(const s of[1,-1]){box('dark',s*1.95,(SILL+Wh.y+Wh.R)/2,Wh.z,0.06,Wh.y+Wh.R-SILL,2*Wh.R);
 box('dark',0,Wh.y+Wh.R-0.05,Wh.z,3.9,0.06,2*Wh.R);}
// fender flares: chunky trim ribbon round every arch
for(const Wh of[FW,RW])for(const s of[1,-1]){const X=s*3.17;let p0=null;
 for(let i=0;i<=AN;i++){const g=i*Math.PI/AN;const p=[X,Wh.y+(Wh.R+0.07)*Math.sin(g),Wh.z+(Wh.R+0.07)*Math.cos(g)];
  if(p0)cyl('trim',p0,p,0.1,6);if(i>0&&i<AN&&i%2===0)box('chrome',X+s*0.04,p[1],p[2],0.05,0.1,0.1);p0=p;}
 cyl('trim',[X,SILL+0.02,Wh.z+Wh.R+0.07],[X,Wh.y,Wh.z+Wh.R+0.07],0.1,6);cyl('trim',[X,Wh.y,Wh.z-Wh.R-0.07],[X,SILL+0.02,Wh.z-Wh.R-0.07],0.1,6);}

// ---------------- cab ----------------
const CS=[[2.3,3.1,3.55,3.7,2.7],[1.2,3.1,4.0,5.15,2.4],[-0.4,3.1,4.0,5.2,2.45],[-0.7,3.1,4.0,5.2,2.45],[-1.5,3.1,4.0,5.2,2.45],[-1.72,3.1,3.8,5.05,2.35]];
const CLR=['cbase','cside','cedge','roof','rstripe'];const CLAB=[...CLR,'rgap',...CLR.slice().reverse(),'cfloor'];
const cabR=CS.map(([z,wb,ybl,yr,wr])=>{const R=[[wb,2.95],[wb,ybl],[Math.min(wb-0.02,wr+0.26),Math.max(ybl,yr-0.14)],[wr,yr],[0.62,yr],[0.12,yr]];const L=R.slice().reverse().map(p=>[-p[0],p[1]]);return[...R,...L].map(p=>[p[0],p[1],z]);});
loftL(cabR,CLAB,(c,n,lab,i)=>{
 if(lab==='cfloor')return'dark';
 if(lab==='cbase'||lab==='cedge')return'body';
 if(lab==='cside')return(i===2||i===4)?'body':'glass';
 if(i===0)return'glass';
 return lab==='rstripe'?'acc':'body';},true,'body');
// rear window + dark frame
box('glass',0,4.55,-1.74,3.4,0.75,0.04);
// chrome belt trim + drip rails
for(const s of[1,-1]){box('chrome',s*3.13,4.0,0.4,0.05,0.05,3.2);
 cyl('chrome',[s*2.52,5.14,1.2],[s*2.52,5.19,-1.6],0.04,6);}
// roof light bar
(function(){const z=0.95,y=5.32;box('dark',0,y,z-0.05,3.6,0.16,0.36);box('chrome',0,y+0.1,z-0.05,3.7,0.05,0.4);
 for(let i=-3;i<=3;i++)prism('lamp',ngon(8,0.2),0.05,(u,v,t)=>[i*0.5+u,y+0.02+v*0.6,z+0.17+t]);
 for(const s of[1,-1]){box('dark',s*1.2,5.2,z-0.05,0.14,0.14,0.14);box('chrome',s*1.2,5.1,z-0.05,0.24,0.06,0.3);}})();

// ---------------- side details ----------------
const DW=3.1; // flat side of cab + body
function sideDecal(k,pts,off){const tr=triangulate(pts);for(const s of[1,-1])for(const t of tr){const P=t.map(i=>[s*(DW+off),pts[i][1],pts[i][0]]);if(s>0)tri(k,P[0],P[2],P[1]);else tri(k,P[0],P[1],P[2]);}}
// rocket painted on each door (nose toward the front), exhaust flame behind it
(function(){const y=1.98,o=0.014;
 sideDecal('acc',[[-1.1,y-0.27],[0.85,y-0.27],[0.85,y+0.27],[-1.1,y+0.27]],o);
 sideDecal('acc',[[0.85,y-0.27],[1.55,y-0.17],[1.55,y+0.17],[0.85,y+0.27]],o);
 sideDecal('chrome2',[[1.55,y-0.17],[2.05,y],[1.55,y+0.17]],0.02);
 sideDecal('acc',[[-0.75,y+0.27],[-1.3,y+0.75],[-1.1,y+0.27]],o);sideDecal('acc',[[-1.1,y-0.27],[-1.3,y-0.75],[-0.75,y-0.27]],o);
 for(const z of[0.2,-0.5])sideDecal('dark',[[z,y-0.27],[z+0.1,y-0.27],[z+0.1,y+0.27],[z,y+0.27]],0.02);
 sideDecal('dark',ngon(10,0.11,0).map(p=>[1.0+p[0],y+p[1]]),0.02);
 sideDecal('glow',[[-1.1,y-0.2],[-1.65,y-0.09],[-2.0,y],[-1.65,y+0.09],[-1.1,y+0.2]],0.012);})();
// pin lines + door seams
for(const[a,b]of[[1.1,1.16],[-1.04,-0.98]])sideDecal('dark',[[a,1.0],[a,4.0],[b,4.0],[b,1.0]],0.01);
sideDecal('acc',[[2.0,2.86],[-1.9,2.86],[-1.9,2.9],[2.0,2.9]],0.014);
for(const s of[1,-1]){
 box('chrome',s*3.16,2.7,0.45,0.06,0.07,0.34);box('chrome',s*3.16,2.7,-1.4,0.06,0.07,0.34);
 // running board with grip ribs
 box('dark',s*3.32,0.95,0.1,0.5,0.1,3.6);box('chrome',s*3.58,0.97,0.1,0.04,0.12,3.6);
 for(let i=0;i<9;i++)box('chrome2',s*3.32,1.01,1.7-i*0.4,0.4,0.03,0.08);
 for(const z of[1.6,-1.4])box('dark',s*3.2,1.2,z,0.28,0.4,0.16);
 // big tow mirrors on arms
 cyl('dark',[s*3.1,4.2,1.15],[s*3.5,4.4,1.5],0.05,6);cyl('dark',[s*3.1,3.6,1.15],[s*3.5,3.9,1.5],0.05,6);
 box('trim',s*3.56,4.12,1.55,0.14,0.95,0.5);box('chrome',s*3.5,4.12,1.55,0.03,0.8,0.4);
 // exhaust stack behind the cab
 const X=s*3.38,Z=-1.98;
 cyl('chrome',[X,1.5,Z],[X,5.7,Z],0.2,10);cyl('chrome2',[X,5.7,Z],[X,5.86,Z],0.2,10,0.26);cyl('glow',[X,5.87,Z],[X,5.88,Z],0.2,10);
 for(const y of[2.2,3.3,4.4])cyl('dark',[X-s*0.2,y,Z],[X+s*0.0,y,Z],0.24,10,0.24);
 box('chrome2',X+s*0.22,3.8,Z,0.05,2.6,0.34);for(let i=0;i<9;i++)box('dark',X+s*0.26,2.6+i*0.28,Z,0.03,0.08,0.28);
 box('dark',s*3.2,2.5,Z,0.4,0.2,0.3);box('dark',s*3.2,3.9,Z,0.4,0.2,0.3);
 // fuel cap on the rear hip
 cyl('chrome',[s*2.3,3.42,-5.0],[s*2.3,3.47,-5.0],0.16,8,0.16,0);
}

// ---------------- bed ----------------
(function(){const zc=-3.55,len=3.5,yb=3.4;
 for(const s of[1,-1]){box('body',s*2.95,yb+0.44,zc,0.3,0.88,len);box('chrome',s*2.95,yb+0.9,zc,0.36,0.05,len+0.04);
  box('dark',s*2.8,yb+0.45,zc,0.04,0.78,len-0.2);
  for(let i=0;i<4;i++)box('chrome2',s*3.12,yb+0.44,-2.1-i*0.85,0.03,0.5,0.1);
  box('bed',s*2.35,yb+0.23,RW.z,1.1,0.42,2.4);}   // wheel humps
 box('bed',0,yb+0.03,zc,5.4,0.06,len-0.1);
 for(let i=0;i<9;i++)box('dark',0,yb+0.07,-2.1-i*0.38,5.3,0.025,0.1);
 box('body',0,yb+0.32,-1.93,5.9,0.64,0.26);box('chrome',0,yb+0.66,-1.93,5.95,0.05,0.3);
 for(const s of[1,-1])box('trim',s*1.0,yb+0.32,-1.77,1.6,0.24,0.06);
 // tailgate with hazard badge
 box('body',0,yb+0.44,-5.22,5.9,0.88,0.24);box('chrome',0,yb+0.9,-5.22,5.96,0.05,0.3);
 box('trim',0,yb+0.44,-5.36,4.6,0.5,0.04);box('acc',0,yb+0.44,-5.39,3.6,0.1,0.02);
 prism('acc',ngon(6,0.2,0),0.04,(u,v,t)=>[u,yb+0.44+v,-5.42+t]);})();

// ---------------- front ----------------
box('dark',0,1.9,ZF+0.01,5.2,2.2,0.04);
// tall grille with chrome frame, bars and hex badge
box('trim',0,2.25,ZF+0.04,3.3,1.55,0.06);box('dark',0,2.25,ZF+0.07,3.0,1.3,0.06);
box('chrome',0,3.03,ZF+0.1,3.34,0.09,0.08);box('chrome',0,1.47,ZF+0.1,3.34,0.09,0.08);
for(const s of[1,-1])box('chrome',s*1.65,2.25,ZF+0.1,0.09,1.65,0.08);
for(let i=-5;i<=5;i++)box('chrome',i*0.27,2.25,ZF+0.12,0.045,1.2,0.05);
box('chrome',0,2.25,ZF+0.14,3.0,0.05,0.05);box('chrome',0,2.6,ZF+0.14,3.0,0.04,0.05);box('chrome',0,1.9,ZF+0.14,3.0,0.04,0.05);
prism('acc',ngon(6,0.26,0),0.06,(u,v,t)=>[u,2.25+v,ZF+0.18+t]);ringPrism('chrome',6,0.26,0.33,0.07,(u,v,t)=>[u,2.25+v,ZF+0.18+t],0);
// quad octagon headlights with chrome bezels
for(const s of[1,-1]){box('trim',s*2.3,2.55,ZF+0.03,0.9,1.5,0.05);
 for(const [x,y,r] of[[2.3,2.95,0.28],[2.3,2.15,0.28]]){prism('lamp',ngon(8,r),0.05,(u,v,t)=>[s*x+u,y+v,ZF+0.07+t]);
  ringPrism('chrome',8,r,r+0.07,0.09,(u,v,t)=>[s*x+u,y+v,ZF+0.08+t]);prism('lamp',ngon(8,0.09),0.02,(u,v,t)=>[s*x+u,y+v,ZF+0.11+t]);}}
// hood: raised center bulge, vents, pins
(function(){
 for(let i=0;i<6;i++)for(const s of[1,-1])box('dark',s*1.12,3.64,4.45-i*0.28,0.5,0.03,0.1);
 for(const s of[1,-1])cyl('chrome',[s*1.9,3.38,4.55],[s*1.9,3.45,4.55],0.06,8);})();
// heavy chrome ram bumper + brush guard + winch
box('chrome',0,0.95,ZF+0.26,5.6,0.5,0.4);box('dark',0,0.95,ZF+0.48,5.0,0.22,0.06);
for(const s of[1,-1]){box('chrome',s*2.95,0.95,ZF+0.04,0.4,0.5,0.4,rotY(-s*0.5));box('glow',s*1.55,0.95,ZF+0.5,0.5,0.1,0.02);
 for(const x of[1.8,0.85])cyl('chrome',[s*x,1.1,ZF+0.44],[s*x,2.95,ZF+0.52],0.07,6);
 cyl('chrome',[s*2.55,1.1,ZF+0.34],[s*2.55,2.4,ZF+0.46],0.07,6);box('acc',s*2.0,0.95,ZF+0.5,0.16,0.14,0.04);}
cyl('chrome',[-2.6,2.45,ZF+0.46],[2.6,2.45,ZF+0.46],0.07,6);cyl('chrome',[-1.85,3.0,ZF+0.52],[1.85,3.0,ZF+0.52],0.07,6);
cyl('chrome',[-1.85,1.7,ZF+0.5],[1.85,1.7,ZF+0.5],0.06,6);
box('dark',0,0.5,ZF-0.1,4.8,0.14,0.7);box('dark',0,0.46,ZF+0.3,3.6,0.05,0.24);
box('dark',0,1.25,ZF+0.3,1.1,0.4,0.42);cyl('chrome2',[-0.45,1.25,ZF+0.38],[0.45,1.25,ZF+0.38],0.17,10);box('acc',0,1.25,ZF+0.52,0.3,0.12,0.04);
// ---------------- rear ----------------
box('dark',0,2.2,ZR-0.01,5.0,1.6,0.04);
for(const s of[1,-1]){box('trim',s*2.55,3.0,ZR-0.04,0.5,1.0,0.05);for(let i=0;i<3;i++)prism('tail',ngon(8,0.17),0.05,(u,v,t)=>[s*2.55+u,2.65+i*0.35+v,ZR-0.07+t]);
 ringPrism('chrome',8,0.17,0.22,0.08,(u,v,t)=>[s*2.55+u,3.35+v,ZR-0.07+t]);}
box('plate',0,2.0,ZR-0.04,1.0,0.5,0.04);box('dark',0,2.0,ZR-0.07,0.76,0.14,0.02);
box('chrome',0,0.95,ZR-0.28,5.6,0.46,0.42);for(const s of[1,-1])box('chrome',s*2.95,0.95,ZR+0.02,0.4,0.46,0.4,rotY(s*0.5));
box('dark',0,0.6,ZR+0.2,4.2,0.14,0.7);
cyl('chrome2',[0,1.28,ZR-0.35],[0,1.5,ZR-0.55],0.09,8);prism('chrome',ngon(10,0.2),0.4,(u,v,t)=>[u,1.62,ZR-0.55+t]);
for(const x of[-0.9,0.9])box('dark',x,1.1,ZR-0.4,0.2,0.4,0.2);

// ---------------- rocket pods (the weapon, built into the body) ----------------
// A pod is built in its own space (tubes point along local +Z) and tilted/turned into place.
function pod(c,pitch,yaw,cols,rows,sp,L,o){o=o||{};
 const rotT=p=>rotY(yaw)(rotX(-pitch)(p));const T=p=>{const q=rotT(p);return[q[0]+c[0],q[1]+c[1],q[2]+c[2]];};
 const lbox=(k,a,b,d,w,h,l)=>{const q=T([a,b,d]);box(k,q[0],q[1],q[2],w,h,l,rotT);};
 const lcyl=(k,a,b,r,n,r2,r0)=>cyl(k,T(a),T(b),r,n,r2,r0);
 const w=cols*sp+0.3,h=rows*sp+0.3,F=L/2;
 // armoured housing + front plate + back plate
 lbox('trim',0,0,0,w,h,L);lbox('body',0,0,-0.1,w+0.08,h-0.5,L-0.5);lbox('dark',0,0,F,w+0.02,h+0.02,0.12);lbox('dark',0,0,-F,w,h,0.1);
 for(const s of[1,-1]){lbox('chrome2',s*(w/2+0.02),0,0,0.06,h*0.5,L*0.55);for(let i=0;i<5;i++)lbox('dark',s*(w/2+0.06),0,-F*0.7+i*F*0.35,0.02,h*0.3,0.08);}
 // hazard stripes on the lid, hinge, rivets
 for(let i=0;i<7;i++)lbox(i%2?'dark':'acc',0,h/2+0.02,-F+0.3+i*(L-0.6)/6,w*0.8,0.04,(L-0.6)/7);
 lcyl('chrome',[-w/2,h/2+0.05,-F+0.15],[w/2,h/2+0.05,-F+0.15],0.07,6);lbox('chrome',0,h/2+0.04,F-0.1,w+0.05,0.07,0.16);
 for(const sx of[1,-1])for(const sy of[1,-1]){lcyl('chrome',[sx*(w/2-0.1),sy*(h/2-0.1),F+0.06],[sx*(w/2-0.1),sy*(h/2-0.1),F+0.12],0.05,6);}
 // tubes: chrome mouth, dark throat, a warhead with nose cone peeking out
 for(let i=0;i<cols;i++)for(let j=0;j<rows;j++){const a=(i-(cols-1)/2)*sp,b=(j-(rows-1)/2)*sp;
  const q=T([a,b,F+0.2]);ringPrism('chrome',8,0.27,0.37,0.34,(u,v,t)=>T([a+u,b+v,F+0.22+t]));
  lcyl('dark',[a,b,F+0.05],[a,b,F+0.38],0.3,8);   // back of the throat so you can't see inside
  lcyl('chrome',[a,b,F+0.08],[a,b,F+0.2],0.22,8);lcyl('acc',[a,b,F+0.2],[a,b,F+0.36],0.21,8,0.15);
  lcyl('warhead',[a,b,F+0.36],[a,b,F+0.62],0.17,8,0.03);lcyl('chrome',[a,b,F+0.34],[a,b,F+0.4],0.2,8);}
 // vents + back nozzle glow
 for(let i=0;i<cols;i++)for(let j=0;j<rows;j++){const a=(i-(cols-1)/2)*sp,b=(j-(rows-1)/2)*sp;lcyl('dark',[a,b,-F-0.02],[a,b,-F-0.1],0.26,8);lcyl('glow',[a,b,-F-0.1],[a,b,-F-0.11],0.18,8);}
 return{T,w,h};}
// pod whose rear-bottom-centre sits at P0 (tilts up by pitch)
function podAt(P0,pitch,yaw,cols,rows,sp,L){const h=rows*sp+0.3;const r=rotY(yaw)(rotX(-pitch)([0,-h/2,-L/2]));
 return pod([P0[0]-r[0],P0[1]-r[1],P0[2]-r[2]],pitch,yaw,cols,rows,sp,L);}
const DECK=3.4;
if(V===0){ // Blast Hauler: one big 3x2 battery on a tilting cradle in the bed
 const pitch=0.56,L=2.5;const p=podAt([0,DECK+0.5,-4.05],pitch,0,3,2,0.8,L);
 // cradle: turntable, axle, A-frame, two hydraulic rams
 prism('trim',ngon(12,1.5,0),0.14,(u,v,t)=>[u,DECK+0.1+t,-3.7+v]);ringPrism('chrome',12,1.38,1.55,0.1,(u,v,t)=>[u,DECK+0.17+t,-3.7+v],0);
 cyl('chrome',[-1.5,DECK+0.5,-4.05],[1.5,DECK+0.5,-4.05],0.13,8);
 for(const s of[1,-1]){box('trim',s*1.45,DECK+0.45,-4.1,0.18,0.7,0.9,rotX(0.0));box('chrome',s*1.45,DECK+0.82,-4.05,0.22,0.1,0.3);
  const a=[s*1.3,DECK+0.15,-3.0],b=p.T([s*1.0,-0.7,0.2]);cyl('chrome2',a,b,0.1,6);cyl('chrome',a,[a[0],a[1]+0.5,a[2]-0.18],0.17,8);
  box('dark',s*1.3,DECK+0.1,-3.0,0.34,0.2,0.34);}
 // ammo drums on the bed floor
 for(const s of[1,-1])for(const z of[-5.0]){cyl('trim',[s*2.2,DECK+0.1,z],[s*2.2,DECK+0.62,z],0.35,10);cyl('acc',[s*2.2,DECK+0.62,z],[s*2.2,DECK+0.68,z],0.3,10);}
}
if(V===1){ // Missile Mule: twin 2x2 pods, one per side of the bed, plus a rack of spare rockets down the middle
 const pitch=0.5,L=2.4;for(const s of[1,-1]){podAt([s*1.55,DECK+0.45,-4.2],pitch,-s*0.05,2,2,0.78,L);
  cyl('chrome',[s*1.55-0.9,DECK+0.45,-4.2],[s*1.55+0.9,DECK+0.45,-4.2],0.11,8);
  for(const x of[-0.8,0.8])box('trim',s*1.55+x,DECK+0.3,-4.2,0.18,0.5,0.7);
  for(const z of[-3.0,-3.6])cyl('chrome2',[s*1.55,DECK+0.1,z],[s*1.55,DECK+0.7,z-0.5],0.08,6);}
 box('trim',0,DECK+0.2,-3.7,0.6,0.3,2.8);
 for(let i=0;i<4;i++){const z=-5.0+i*0.62;box('chrome',0,DECK+0.4,z,0.5,0.06,0.1);}
 for(const s of[1,-1]){cyl('acc',[s*0.18,DECK+0.46,-2.7],[s*0.18,DECK+0.46,-4.8],0.14,8);cyl('warhead',[s*0.18,DECK+0.46,-2.7],[s*0.18,DECK+0.46,-2.45],0.14,8,0.02);}
}
if(V===2){ // Fender Fury: two 2x2 pods built into the front fenders, muzzles flush with the grille
 for(const s of[1,-1]){const q=pod([s*2.2,4.2,3.75],0.05,0,2,2,0.7,2.9);
  box('body',s*2.2,3.62,3.7,1.7,0.5,3.1);box('chrome',s*2.2,3.62,3.7,1.76,0.05,3.14);
  for(const z of[4.6,3.1])cyl('chrome',[s*1.5,3.5,z],[s*1.5,3.95,z],0.08,6);}
 // ammo crates + roll hoop in the bed
 for(const s of[1,-1]){box('trim',s*1.3,DECK+0.35,-4.3,1.7,0.7,1.4);box('acc',s*1.3,DECK+0.72,-4.3,1.5,0.06,1.2);box('dark',s*1.3,DECK+0.36,-3.6,1.6,0.3,0.02);}
 cyl('chrome',[-2.4,DECK+0.05,-2.4],[-2.4,DECK+2.0,-2.4],0.1,8);cyl('chrome',[2.4,DECK+0.05,-2.4],[2.4,DECK+2.0,-2.4],0.1,8);cyl('chrome',[-2.45,DECK+2.0,-2.4],[2.45,DECK+2.0,-2.4],0.1,8);
 box('dark',0,DECK+2.1,-2.4,1.0,0.3,0.3);prism('lamp',ngon(8,0.12),0.05,(u,v,t)=>[u,DECK+2.1+v,-2.2+t]);
}
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
return{bufs,COL,NEON,FW,RW};};
