// Mine-layer cars (car 5): same faceted style + HIGH detail as the Toxic Hot Rod (kart-preview/toxic-tries).
// nose +Z, up +Y, ground y = 0, car left = +X. Three bodies, each with the mine layer built INTO the body.
window.MINESPEC=[
{name:'Grave Layer',ZF:5.3,ZR:-5.6,DW:2.86,
 col:{body:[16,17,21],acc:[255,170,20]},neon:{glow:[255,190,50]},
 FW:{z:3.2,y:0.95,r:0.95,R:1.08,w:1.0,x:2.55},RW:{z:-3.0,y:1.1,r:1.1,R:1.28,w:1.2,x:2.6},
 WT:[[5.3,2.5],[5.12,2.72],[4.8,2.9],[4.3,2.98],[3.2,3.0],[2.0,2.96],[1.6,2.85],[-1.0,2.85],[-1.6,3.0],[-3.0,3.15],[-4.3,3.2],[-5.0,3.1],[-5.4,2.95],[-5.6,2.75]],
 FT:[[5.3,1.72],[5.12,1.88],[4.8,2.08],[4.3,2.32],[3.2,2.45],[2.0,2.35],[1.3,2.3],[-1.0,2.3],[-2.0,2.35],[-3.0,2.55],[-3.9,2.95],[-4.6,3.25],[-5.1,3.3],[-5.6,3.05]],
 HT:[[5.3,1.7],[5.12,1.86],[4.8,1.95],[4.3,2.0],[3.2,2.04],[2.0,2.07],[1.3,2.1],[-1.2,2.12],[-3.0,2.14],[-5.0,2.14],[-5.6,2.2]],
 CS:[[2.0,2.2,2.17,2.27,2.0],[0.9,2.15,2.2,3.05,1.62],[-0.1,2.15,2.2,3.08,1.62],[-0.5,2.15,2.2,3.08,1.62],[-1.5,2.15,2.2,3.05,1.62],[-2.5,2.2,2.2,2.4,2.0]],
 stripeZ:[2.2,-99],kind:'hearse'},
{name:'Widow Maker',ZF:5.2,ZR:-5.2,DW:2.9,
 col:{body:[14,14,17],acc:[235,28,38]},neon:{glow:[255,70,60],lamp:[255,226,150]},
 FW:{z:3.1,y:0.92,r:0.92,R:1.06,w:0.95,x:2.55},RW:{z:-2.9,y:1.15,r:1.15,R:1.35,w:1.35,x:2.65},
 WT:[[5.2,2.5],[5.0,2.75],[4.6,2.95],[4.0,3.05],[3.1,3.1],[1.6,3.0],[0.5,3.05],[-1.0,3.15],[-2.4,3.3],[-3.6,3.3],[-4.5,3.15],[-5.0,2.95],[-5.2,2.75]],
 FT:[[5.2,1.6],[5.0,1.78],[4.6,1.98],[4.0,2.2],[3.1,2.3],[1.6,2.15],[0.0,2.1],[-1.5,2.25],[-2.6,2.6],[-3.6,2.55],[-4.5,2.4],[-5.0,2.35],[-5.2,2.15]],
 HT:[[5.2,1.6],[5.0,1.76],[4.6,1.86],[4.0,1.9],[3.1,1.93],[1.6,1.98],[-1.0,2.0],[-2.6,2.02],[-3.6,2.0],[-4.6,2.0],[-5.0,2.1],[-5.2,2.1]],
 CS:[[1.9,2.2,2.1,2.2,2.0],[0.7,2.2,2.12,2.88,1.55],[-0.1,2.2,2.12,2.9,1.55],[-0.4,2.2,2.12,2.9,1.55],[-1.3,2.2,2.12,2.88,1.55],[-2.3,2.25,2.12,2.2,2.0]],
 stripeZ:[1.7,-2.3],kind:'drum'},
{name:'Rust Hopper',ZF:5.0,ZR:-4.9,DW:3.0,
 col:{body:[70,48,34],acc:[255,112,16],trim:[44,38,34]},neon:{glow:[255,150,40]},
 FW:{z:2.95,y:1.1,r:1.1,R:1.22,w:1.15,x:2.7},RW:{z:-2.7,y:1.2,r:1.2,R:1.34,w:1.3,x:2.75},
 WT:[[5.0,2.65],[4.85,2.85],[4.5,3.05],[4.0,3.15],[2.95,3.2],[1.0,3.2],[-1.0,3.2],[-2.7,3.25],[-4.0,3.25],[-4.6,3.15],[-4.9,3.0]],
 FT:[[5.0,2.0],[4.85,2.2],[4.5,2.5],[4.0,2.7],[2.95,2.8],[1.0,2.8],[-1.0,2.8],[-2.7,2.85],[-4.0,2.8],[-4.6,2.6],[-4.9,2.4]],
 HT:[[5.0,1.95],[4.85,2.1],[4.5,2.32],[4.0,2.38],[2.95,2.42],[1.0,2.45],[-1.0,2.45],[-2.7,2.3],[-4.0,2.2],[-4.9,2.2]],
 CS:[[1.7,2.55,2.5,2.62,2.3],[0.8,2.6,2.55,3.55,2.2],[-0.2,2.6,2.55,3.6,2.2],[-0.6,2.6,2.55,3.6,2.2],[-1.6,2.6,2.55,3.55,2.2],[-2.4,2.6,2.55,2.7,2.3]],
 stripeZ:[1.7,-99],kind:'hopper'}
];
// Mine-layer generator: one function, opt.car 0/1/2 picks MINESPEC. opt.splitWheels keeps each wheel apart (game files).
// Returns {bufs:{key:[x,y,z,...]}, COL, NEON, FW, RW}. Helpers below are the Toxic Hot Rod's, copied.
window.genMine=function(opt){
opt=opt||{};const S=window.MINESPEC[opt.car||0];
const COL=Object.assign({body:[16,17,21],acc:[48,208,36],glass:[14,20,32],chrome:[205,210,220],chrome2:[150,155,165],dark:[9,9,11],tire:[22,22,26],trim:[38,40,46],belt:[18,18,18],mine:[26,27,32],spike:[120,124,134],rubber:[30,30,34],hinge:[205,210,220]},S.col);
const NEON=Object.assign({lamp:[255,238,120],glow:[255,190,50],tail:[255,36,36],plate:[235,240,225],blink:[255,40,30]},S.neon);
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
const FW=S.FW,RW=S.RW,SILL=0.6,ZF=S.ZF,ZR=S.ZR,WT=S.WT,FT=S.FT,HT=S.HT,K=S.kind;
const mirrorX=s=>s;
// ---------------- mine (the Spike Pro look: black disc, bolts, red spikes, red blinker) ----------------
function mine(o,u,r,sp){u=nrm(u);const s0=Math.abs(u[1])<.9?[0,1,0]:[1,0,0];const p=nrm(cross(u,s0)),q=cross(u,p);const h=r*0.5;
 const at=(d,a)=>[o[0]+u[0]*a+d[0],o[1]+u[1]*a+d[1],o[2]+u[2]*a+d[2]];
 cyl('mine',at([0,0,0],-h/2),at([0,0,0],h/2),r,12,r,0);
 cyl('mine',at([0,0,0],h/2),at([0,0,0],h/2+r*0.18),r*0.66,12,r*0.5,0);
 for(let i=0;i<8;i++){const g=i*Math.PI/4+Math.PI/8,c=Math.cos(g),d=Math.sin(g);const out=[p[0]*c+q[0]*d,p[1]*c+q[1]*d,p[2]*c+q[2]*d];
  const b=at([out[0]*r*0.96,out[1]*r*0.96,out[2]*r*0.96],0),t=at([out[0]*r*1.42,out[1]*r*1.42,out[2]*r*1.42],h*0.62);
  cyl('spike',b,t,r*0.17,4,r*0.03);
  const bo=at([out[0]*r*0.5,out[1]*r*0.5,out[2]*r*0.5],h/2+r*0.18);cyl('chrome',bo,[bo[0]+u[0]*r*0.07,bo[1]+u[1]*r*0.07,bo[2]+u[2]*r*0.07],r*0.07,6);}
 cyl('blink',at([0,0,0],h/2+r*0.18),at([0,0,0],h/2+r*0.3),r*0.2,8);}
function chev(k,x0,x1,z,y,n,wd,ht,dirn){ // top-facing hazard chevrons on a flat panel
 for(let i=0;i<n;i++){const zz=z+i*wd*2;const P=[[x0,zz],[0,zz+ht*dirn],[x1,zz],[x1,zz+wd],[0,zz+ht*dirn+wd],[x0,zz+wd]];
  const tr=triangulate(P.map(p=>[p[0],p[1]]));for(const t of tr)tri(k,[P[t[0]][0],y,P[t[0]][1]],[P[t[2]][0],y,P[t[2]][1]],[P[t[1]][0],y,P[t[1]][1]]);}}

// ---------------- body ----------------
const ST=[];const st=(z,yb)=>ST.push({z,yb});
st(ZF,0.85);st(ZF-0.17,0.72);st(ZF-0.52,SILL);st(ZF-0.77,SILL);
const AN=8;
function arch(Wh){st(Wh.z+Wh.R,SILL);for(let i=0;i<=AN;i++){const g=i*Math.PI/AN;st(Wh.z+Wh.R*Math.cos(g),Wh.y+Wh.R*Math.sin(g));}st(Wh.z-Wh.R,SILL);}
arch(FW);{const g0=FW.z-FW.R,g1=RW.z+RW.R;for(let i=1;i<=5;i++)st(g0+(g1-g0)*i/6,SILL);}arch(RW);
st(ZR+0.72,SILL);st(ZR+0.42,SILL);st(ZR+0.17,0.72);st(ZR,0.85);
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
 if(lab==='stripe'&&(c[2]>S.stripeZ[0]||c[2]<S.stripeZ[1]))return'acc';
 return'body';},true,'body');
for(const Wh of[FW,RW])for(const s of[1,-1]){box('dark',s*1.9,(SILL+Wh.y+Wh.R)/2,Wh.z,0.06,Wh.y+Wh.R-SILL,2*Wh.R);
 box('dark',0,Wh.y+Wh.R-0.05,Wh.z,3.8,0.06,2*Wh.R);}

// ---------------- cabin ----------------
const CS=S.CS;
const CLR=['cbase','cside','cedge','roof','rstripe'];const CLAB=[...CLR,'rgap',...CLR.slice().reverse(),'cfloor'];
const cabR=CS.map(([z,wb,ybl,yr,wr])=>{const R=[[wb,1.95],[wb,ybl],[Math.min(wb-0.02,wr+0.24),Math.max(ybl,yr-0.12)],[wr,yr],[0.62,yr],[0.12,yr]];const L=R.slice().reverse().map(p=>[-p[0],p[1]]);return[...R,...L].map(p=>[p[0],p[1],z]);});
loftL(cabR,CLAB,(c,n,lab,i)=>{
 if(lab==='cfloor')return'dark';
 if(lab==='cbase'||lab==='cedge')return'body';
 if(lab==='cside')return(i===2||i===4)?'body':'glass';
 if(i===0||i===4)return'glass';
 return lab==='rstripe'?'acc':'body';},true,'body');
const zb0=CS[1][0],zb1=CS[4][0],yBelt=CS[1][2],wBelt=CS[1][1];
for(const s of[1,-1]){box('chrome',s*(wBelt+0.04),yBelt,(zb0+zb1)/2,0.05,0.05,zb0-zb1+0.3);
 cyl('chrome',[s*(CS[1][4]+0.12),CS[1][3]-0.1,zb0],[s*(CS[1][4]+0.12),CS[4][3]-0.1,zb1],0.035,6);}
// ---------------- side details ----------------
const DW=S.DW,dz0=CS[1][0]+1.05,dz1=CS[4][0]+0.35,dzm=(dz0+dz1)/2;
function sideDecal(k,pts,off){const tr=triangulate(pts);for(const s of[1,-1])for(const t of tr){const P=t.map(i=>[s*(DW+off),pts[i][1],pts[i][0]]);if(s>0)tri(k,P[0],P[2],P[1]);else tri(k,P[0],P[1],P[2]);}}
function starDecal(k,zc,yc,R,off){const P=[];for(let i=0;i<16;i++){const g=i*Math.PI/8+Math.PI/16,r=i%2?R*0.66:R*1.04;P.push([zc+Math.cos(g)*r,yc+Math.sin(g)*r]);}sideDecal(k,P,off);}
function mineIcon(zc,yc,R){starDecal('acc',zc,yc,R,0.016);sideDecal('dark',ngon(12,R*0.6,0).map(p=>[zc+p[0],yc+p[1]]),0.022);
 sideDecal('acc',ngon(8,R*0.3,0).map(p=>[zc+p[0],yc+p[1]]),0.026);}
// hazard band between the door seams (parallelograms)
function hazard(y0,y1,z0,z1,w,slant){const n=Math.floor((z0-z1)/w);for(let i=0;i<n;i+=2){const a=z0-i*w;sideDecal('acc',[[a,y0],[a-w,y0],[a-w-slant,y1],[a-slant,y1]],0.014);}}
if(K==='hearse'){hazard(1.28,1.72,dz0-0.05,dz1+0.05,0.3,-0.2);sideDecal('acc',[[dz0,1.745],[dz1,1.745],[dz1,1.775],[dz0,1.775]],0.014);mineIcon(dzm,0.98,0.3);}
if(K==='drum'){sideDecal('acc',[[dz0+0.2,1.62],[dz1-1.0,1.62],[dz1-1.0,1.5],[dz0+0.2,1.5]],0.014);
 sideDecal('acc',[[dz0+0.5,1.4],[dz1-1.4,1.4],[dz1-1.4,1.34],[dz0+0.5,1.34]],0.014);mineIcon(dzm,1.0,0.33);}
if(K==='hopper'){hazard(1.55,1.95,dz0-0.05,dz1+0.05,0.32,-0.22);mineIcon(dzm,1.0,0.36);
 for(const zz of[dz0+0.25,dz1-0.25])for(const yy of[1.3,2.0])for(const s of[1,-1])cyl('chrome2',[s*DW,yy,zz],[s*(DW+0.05),yy,zz],0.05,6);}
for(const zz of[dz0,dz1])sideDecal('dark',[[zz+0.018,0.78],[zz+0.018,1.78],[zz-0.018,1.78],[zz-0.018,0.78]],0.008);
for(const s of[1,-1]){box('chrome',s*(DW+0.04),1.47,dz1+0.5,0.06,0.07,0.32);
 const mz=CS[1][0]+0.9;cyl('dark',[s*(CS[1][1]+0.47),2.13,mz],[s*(CS[1][1]+0.83),2.3,mz-0.06],0.04,6);box('dark',s*(CS[1][1]+0.91),2.33,mz-0.08,0.14,0.22,0.36);box('chrome',s*(CS[1][1]+0.91),2.33,mz-0.27,0.1,0.18,0.03);
 if(K!=='hopper'){const zf=ZR+1.7,tf=interp(FT,zf),wf=interp(WT,zf);cyl('chrome',[s*(wf-0.52),tf-0.01,zf],[s*(wf-0.52),tf+0.04,zf],0.14,8,0.14,0);}}
// side pipes with glowing tips
for(const s of[1,-1]){const X=s*(DW+0.18),Y=0.74,za=FW.z-FW.R+0.5,zb=RW.z+RW.R+0.13;
 cyl('chrome',[X,Y,za],[X,Y,za-0.25],0.1,10,0.15);cyl('chrome',[X,Y,za-0.25],[X,Y,zb+0.27],0.15,10);cyl('chrome',[X,Y,zb+0.27],[X,Y,zb],0.15,10,0.19);cyl('glow',[X,Y,zb-0.005],[X,Y,zb-0.01],0.15,10);
 box('chrome2',X+s*0.13,Y+0.02,(za+zb)/2,0.05,0.24,za-zb-0.3);for(let i=0;i<8;i++)box('dark',X+s*0.16,Y+0.02,za-0.4-i*(za-zb-0.9)/7,0.02,0.07,0.1);
 for(const zq of[za-0.55,zb+0.55])box('dark',s*(DW+0.06),Y+0.02,zq,0.22,0.06,0.1);}

// ---------------- front ----------------
box('dark',0,1.3,ZF+0.01,4.5,0.74,0.04);
box('dark',0,1.3,ZF+0.03,1.9,0.52,0.06);
box('chrome',0,1.58,ZF+0.06,2.04,0.06,0.06);box('chrome',0,1.02,ZF+0.06,2.04,0.06,0.06);
for(const s of[1,-1])box('chrome',s*0.99,1.3,ZF+0.06,0.06,0.62,0.06);
for(let i=-3;i<=3;i++)box('chrome',i*0.24,1.3,ZF+0.06,0.035,0.5,0.04);
box('chrome',0,1.3,ZF+0.07,1.9,0.035,0.04);
prism('acc',ngon(6,0.13,0),0.06,(u,v,t)=>[u,1.3+v,ZF+0.1+t]);
for(const s of[1,-1]){box('trim',s*1.62,1.3,ZF+0.02,1.12,0.56,0.05);
 for(const x of[1.33,1.9]){prism('lamp',ngon(8,0.2),0.05,(u,v,t)=>[s*x+u,1.3+v,ZF+0.06+t]);
  ringPrism('chrome',8,0.2,0.26,0.08,(u,v,t)=>[s*x+u,1.3+v,ZF+0.07+t]);prism('lamp',ngon(8,0.07),0.02,(u,v,t)=>[s*x+u,1.3+v,ZF+0.1+t]);}}
for(const s of[1,-1]){const zh=ZF-0.55;cyl('chrome',[s*1.15,interp(HT,zh)-0.01,zh],[s*1.15,interp(HT,zh)+0.05,zh],0.06,8);}
const BCS=[[-0.17,-0.15],[0.1,-0.15],[0.2,-0.06],[0.2,0.07],[0.1,0.15],[-0.17,0.15]];
function bar(k,x0,x1,place){prism(k,BCS,x1-x0,(u,v,t)=>place([(x0+x1)/2+t,v,u]));}
bar('chrome',-1.95,1.95,p=>[p[0],0.86+p[1],ZF+0.18+p[2]]);
for(const s of[1,-1]){const piv=[s*1.95,0.86,ZF+0.18];bar('chrome',0,0.7,p=>{const q=rotY(s*0.6)([p[0]*s,p[1],p[2]]);return[piv[0]+q[0],piv[1]+q[1],piv[2]+q[2]];});
 bar('chrome',0,0.6,p=>{const q=rotY(s*Math.PI/2)([p[0]*s,p[1],p[2]]);return[s*2.53+q[0],0.86+q[1],ZF-0.215+q[2]];});
 box('glow',s*1.45,0.86,ZF+0.385,0.42,0.1,0.02);box('chrome',s*0.75,0.98,ZF+0.27,0.12,0.1,0.14);}
box('dark',0,0.62,ZF-0.05,4.4,0.12,0.7);box('dark',0,0.58,ZF+0.3,3.6,0.05,0.2);
// hood feature
const hy=z=>interp(HT,z);
if(K==='hearse'){ // chrome hood ornament: pyramid + swept wings
 const z0=4.35,y0=hy(z0);cyl('chrome',[0,y0,z0],[0,y0+0.36,z0+0.1],0.2,4,0.04,Math.PI/4);
 for(const s of[1,-1]){box('chrome',s*0.3,y0+0.13,z0-0.02,0.5,0.05,0.2,rotY(s*0.5));}}
if(K==='drum'){const z0=3.1,y0=hy(z0);box('dark',0,y0+0.12,z0,1.5,0.24,1.5);
 prism('trim',[[-0.75,0],[0.75,0],[0.5,0.2],[-0.5,0.2]],1.5,(u,v,t)=>[u,y0+0.24+v,z0+t]);
 for(let i=0;i<5;i++)box('glow',0,y0+0.27,z0-0.6+i*0.3,1.1,0.02,0.07);
 box('chrome',0,y0+0.47,z0,1.5,0.04,1.5);chev('acc',-1.4,1.4,4.2,hy(4.4)+0.012,3,0.18,0.3,1);}
if(K==='hopper'){// light brush guard, armour plates, roll hoops, roof beacon
 for(const x of[-0.5,0.5])cyl('chrome',[x,0.95,ZF+0.5],[x,1.62,ZF+0.5],0.06,8);
 for(const y of[0.95,1.62])cyl('chrome',[-1.5,y,ZF+0.5],[1.5,y,ZF+0.5],0.08,8);
 for(const s of[1,-1]){cyl('chrome',[s*1.5,0.95,ZF+0.5],[s*1.5,1.62,ZF+0.5],0.08,8);cyl('chrome',[s*1.5,1.62,ZF+0.5],[s*1.5,1.62,ZF-0.1],0.08,8);cyl('chrome',[s*1.5,0.95,ZF+0.5],[s*1.5,0.9,ZF+0.1],0.08,8);}
 for(const s of[1,-1]){cyl('dark',[s*0.7,hy(3.6)+0.3,3.7],[s*0.7,hy(3.6)+0.3,3.55],0.3,10);cyl('lamp',[s*0.7,hy(3.6)+0.3,3.71],[s*0.7,hy(3.6)+0.3,3.72],0.24,10);
  for(const [z0,w0] of[[dz0-0.55,0.9],[dzm-0.1,1.2],[dz1+0.45,0.9]]){box('trim',s*(DW+0.05),1.45,z0,0.1,0.95,w0*0.85);
   for(const [a,b] of[[-1,-1],[1,-1],[-1,1],[1,1]])cyl('chrome2',[s*(DW+0.1),1.45+b*0.38,z0+a*w0*0.34],[s*(DW+0.15),1.45+b*0.38,z0+a*w0*0.34],0.045,6);}
  const rz=CS[2][0];for(const zz of[CS[1][0]-0.3,CS[4][0]+0.3]){cyl('chrome',[s*(CS[2][4]-0.1),CS[2][3],zz],[s*(CS[2][4]-0.1),CS[2][3]+0.25,zz],0.06,6);}}
 for(const zz of[CS[1][0]-0.3,CS[4][0]+0.3])cyl('chrome',[-(CS[2][4]-0.1),CS[2][3]+0.25,zz],[CS[2][4]-0.1,CS[2][3]+0.25,zz],0.06,6);
 cyl('chrome',[-(CS[2][4]-0.1),CS[2][3]+0.25,CS[1][0]-0.3],[-(CS[2][4]-0.1),CS[2][3]+0.25,CS[4][0]+0.3],0.06,6);cyl('chrome',[(CS[2][4]-0.1),CS[2][3]+0.25,CS[1][0]-0.3],[(CS[2][4]-0.1),CS[2][3]+0.25,CS[4][0]+0.3],0.06,6);
 cyl('dark',[0,CS[2][3]+0.27,-0.6],[0,CS[2][3]+0.33,-0.6],0.32,10);cyl('glow',[0,CS[2][3]+0.33,-0.6],[0,CS[2][3]+0.55,-0.6],0.24,10,0.2);}

// ---------------- rear ----------------
box('dark',0,1.55,ZR-0.01,4.6,0.9,0.04);
for(const s of[1,-1])for(const x of[1.3,1.95]){prism('tail',ngon(8,0.2),0.05,(u,v,t)=>[s*x+u,1.72+v,ZR-0.05+t]);ringPrism('chrome',8,0.2,0.26,0.08,(u,v,t)=>[s*x+u,1.72+v,ZR-0.06+t]);}
box('trim',0,1.72,ZR-0.03,1.9,0.62,0.05);box('dark',0,1.72,ZR-0.06,1.7,0.5,0.04);mine([0,1.72,ZR-0.1],[0,0,-1],0.2);for(const s of[1,-1])box('acc',s*0.97,1.72,ZR-0.07,0.05,0.62,0.04);
box('plate',0,1.25,ZR-0.04,0.9,0.42,0.04);box('dark',0,1.25,ZR-0.07,0.7,0.12,0.02);
bar('chrome',-2.1,2.1,p=>[p[0],0.95+p[1],ZR-0.18-p[2]]);
for(const s of[1,-1]){box('chrome',s*2.3,0.95,ZR-0.1,0.6,0.3,0.36,rotY(-s*0.6));box('chrome',s*2.6,0.95,ZR+0.25,0.3,0.3,0.6);}
box('dark',0,0.66,ZR+0.2,3.6,0.14,0.7);
for(let i=-3;i<=3;i++)box('dark',i*0.45,0.55,ZR+0.05,0.05,0.2,0.5);
// ---------------- the mine layer, built into the body ----------------
// swing arm (catapult): spoon with a loaded mine hangs past the tail, counterweight over the hinge
function arm(zh,yh,yfl,len){
 for(const s of[1,-1]){box('trim',s*1.15,(yfl+yh)/2,zh,0.28,yh-yfl,0.5);box('acc',s*1.15,yfl+0.05,zh,0.4,0.08,0.6);}
 cyl('hinge',[-1.4,yh,zh],[1.4,yh,zh],0.13,8); // the hinge pin: its centre is the pivot the arm turns about
 const zs=zh-len-0.35;
 KP='arm:'; // everything that swings with the arm (pivot = the hinge)
 for(const s of[1,-1])box('chrome2',s*0.5,yh,zh-len/2,0.2,0.2,len);
 box('chrome2',0,yh,zh-len*0.55,1.0,0.12,0.12);
 box('chrome2',0,yh-0.02,zs,1.3,0.12,0.9);
 for(const s of[1,-1])box('acc',s*0.65,yh+0.14,zs,0.1,0.34,0.9);
 box('acc',0,yh+0.14,zs-0.45,1.3,0.34,0.1);
 box('acc',0,yh+0.12,zh+0.3,1.1,0.7,0.7);box('trim',0,yh+0.5,zh+0.3,1.0,0.1,0.6);
 for(const s of[1,-1])cyl('chrome2',[s*0.3,yh+0.48,zh+0.3],[s*0.3,yh+0.56,zh+0.3],0.05,6);
 KP='lm:'; // the loaded mine, thrown from the spoon
 mine([0,yh+0.04+0.085,zs],[0,1,0],0.34);
 KP='';ARM={y:yh,z:zh,zs:zs,my:yh+0.04+0.085};}
let ARM=null;
const UP=[0,1,0];
if(K==='hearse'){ // open rack on the hearse deck: 3 shelves x 2 mines, chute ramp out the tail
 const zc=-3.6,yf=hy(zc)+0.03;
 box('dark',0,yf,zc,3.5,0.06,2.5);
 for(const s of[1,-1])for(const z of[zc+1.05,zc-1.05]){cyl('chrome',[s*1.6,yf,z],[s*1.6,yf+1.95,z],0.065,8);box('acc',s*1.6,yf+0.03,z,0.3,0.06,0.3);}
 for(const s of[1,-1])for(const y of[yf+0.55,yf+1.15,yf+1.75]){cyl('chrome',[s*1.6,y,zc+1.05],[s*1.6,y,zc-1.05],0.04,6);}
 for(let i=0;i<3;i++){const y=yf+0.06+i*0.6;box('trim',0,y+0.0,zc,3.1,0.05,2.1);box('acc',0,y+0.03,zc-1.07,3.1,0.03,0.04);
  for(const x of[-0.85,0.85])mine([x,y+0.04+0.125,zc],UP,0.5);}
 // top rail + amber hazard light
 cyl('chrome',[-1.6,yf+1.95,zc+1.05],[1.6,yf+1.95,zc+1.05],0.065,8);cyl('chrome',[-1.6,yf+1.95,zc-1.05],[1.6,yf+1.95,zc-1.05],0.065,8);
 for(const s of[1,-1]){cyl('chrome',[s*1.6,yf+1.95,zc+1.05],[s*1.6,yf+1.95,zc-1.05],0.065,8);}
 cyl('dark',[0,yf+1.97,zc-1.05],[0,yf+2.05,zc-1.05],0.26,8);cyl('glow',[0,yf+2.05,zc-1.05],[0,yf+2.3,zc-1.05],0.2,8,0.14);
}
if(K==='drum'){ // revolver drum sunk into the trunk deck: chambers carry mines, red ready lights
 const zc=-3.45,yc=2.12,rd=0.72;
 cyl('trim',[-1.6,yc,zc],[1.6,yc,zc],rd,12,rd,0);
 for(const s of[1,-1]){cyl('chrome',[s*1.58,yc,zc],[s*1.72,yc,zc],rd+0.08,12,rd+0.08,0);cyl('acc',[s*1.72,yc,zc],[s*1.76,yc,zc],rd*0.55,12,rd*0.55,0);cyl('chrome',[s*1.76,yc,zc],[s*1.84,yc,zc],0.2,8);
  box('trim',s*1.78,yc-0.55,zc,0.2,1.1,0.5);box('chrome',s*1.78,yc-0.15,zc+0.55,0.16,0.9,0.1);box('chrome',s*1.78,yc-0.15,zc-0.55,0.16,0.9,0.1);}
 for(const x of[-0.55,0.55])cyl('acc',[x-0.08,yc,zc],[x+0.08,yc,zc],rd+0.03,12,rd+0.03,0);
 for(const a of[30,90,150,210,330]){const g=a*Math.PI/180,rad=[0,Math.sin(g),Math.cos(g)];const rr=rd+0.06;
  for(const x of[-1.0,0,1.0]){if(x===0&&false)continue;mine([x*0.9,yc+rad[1]*rr,zc+rad[2]*rr],rad,0.34);}}
}
if(K==='hopper'){ // three vertical tubes, 4 mines stacked in each, conveyor tray out the back
 const yf=hy(-3.6)+0.04;
 const tubes=[[-0.75,-3.4],[0.75,-3.4]];
 box('dark',0,yf,-3.6,3.4,0.08,2.2);
 for(const [x,z] of tubes){const R=0.62;cyl('trim',[x,yf,z],[x,yf+0.22,z],R+0.1,10,R+0.1,0);
  for(let i=0;i<3;i++)mine([x,yf+0.3+i*0.42,z],UP,0.44);
  for(let i=0;i<4;i++){const g=i*Math.PI/2+Math.PI/4;cyl('chrome2',[x+Math.cos(g)*R,yf+0.22,z+Math.sin(g)*R],[x+Math.cos(g)*R,yf+1.75,z+Math.sin(g)*R],0.045,6);}
  for(const y of[yf+0.95])cyl('chrome',[x,y,z],[x,y+0.07,z],R+0.04,10,R+0.04,0);
  cyl('acc',[x,yf+1.72,z],[x,yf+1.82,z],R+0.07,10,R+0.07,0);}
}

if(K==='hearse')arm(-4.95,2.75,hy(-4.95),2.0);
if(K==='drum')arm(-4.75,2.45,hy(-4.75),2.0);
if(K==='hopper')arm(-4.45,2.7,hy(-4.45),1.9);
// ---------------- wheels ----------------
function wheel(Wh,s,id){KP=opt.splitWheels?id+':':'';const {x,y,z,r,w}=Wh;const P=(xo,rad,a)=>[s*x+s*xo,y+rad*Math.sin(a),z+rad*Math.cos(a)];
 const n=14;
 const prof=[[0.64*r,-w/2],[0.84*r,-w/2],[r,-w/2+0.13*w],[r,w/2-0.13*w],[0.84*r,w/2],[0.64*r,w/2]];
 for(let k=0;k<n;k++){const a0=k*2*Math.PI/n,a1=(k+1)*2*Math.PI/n;
  for(let j=0;j<prof.length;j++){const p=prof[j],q=prof[(j+1)%prof.length];const A=P(p[1],p[0],a0),Bq=P(q[1],q[0],a0),C=P(q[1],q[0],a1),E=P(p[1],p[0],a1);
   const ctr=[(A[0]+C[0])/2,(A[1]+C[1])/2,(A[2]+C[2])/2];const out=sub(ctr,[s*x,y,z]);const f=fnorm(A,Bq,C);
   if(f[0]*out[0]+f[1]*out[1]+f[2]*out[2]<0)quad('tire',A,E,C,Bq);else quad('tire',A,Bq,C,E);}}
 const pb=(k,x0,x1,r0,r1,a0,a1)=>{const C=[P(x0,r0,a0),P(x1,r0,a0),P(x1,r1,a0),P(x0,r1,a0),P(x0,r0,a1),P(x1,r0,a1),P(x1,r1,a1),P(x0,r1,a1)];
  [[0,3,2,1],[4,5,6,7],[0,1,5,4],[3,7,6,2],[0,4,7,3],[1,2,6,5]].forEach(f=>quad(k,C[f[0]],C[f[1]],C[f[2]],C[f[3]]));};
 for(let k=0;k<n*2;k++){const a=(k+0.5)*Math.PI/n,h=Math.PI/n*0.42;const off=(k%2)?0.12*w:-0.12*w;
  pb('tire',off-0.22*w,off+0.22*w,r-0.01,r+0.045,a-h,a+h);}
 const O=w/2;for(let k=0;k<n;k++){const a0=k*2*Math.PI/n,a1=(k+1)*2*Math.PI/n;pb('acc',O-0.005,O+0.012,0.76*r,0.8*r,a0,a1);
  pb('dark',O-0.32,O-0.28,0,0.64*r,a0,a1);
  pb('chrome',O-0.07,O+0.02,0.58*r,0.66*r,a0,a1);
  pb('acc',O-0.16,O-0.06,0.48*r,0.58*r,a0,a1);}
 for(let i=0;i<5;i++){const a=i*2*Math.PI/5+Math.PI/2;pb('acc',O-0.2,O-0.09,0.17*r,0.5*r,a-0.2,a+0.2);pb('dark',O-0.2,O-0.1,0.2*r,0.47*r,a+Math.PI/5-0.03,a+Math.PI/5+0.03);}
 for(let k=0;k<10;k++){const a0=k*Math.PI/5,a1=(k+1)*Math.PI/5;pb('chrome',O-0.22,O-0.03,0,0.2*r,a0,a1);pb('acc',O-0.03,O+0.0,0,0.08*r,a0,a1);}
 for(let i=0;i<5;i++){const a=i*2*Math.PI/5+Math.PI/2+Math.PI/5;pb('chrome2',O-0.04,O+0.02,0.11*r,0.16*r,a-0.13,a+0.13);}
}
for(const s of[1,-1]){wheel(FW,s,s>0?'FL':'FR');wheel(RW,s,s>0?'RL':'RR');}KP='';

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
if(opt.orient!==false){const keys=Object.keys(bufs),all=[];for(const k of keys)for(const v of bufs[k])all.push(v);
 const fixed=orient(all);let at=0;for(const k of keys){const n=bufs[k].length;bufs[k]=fixed.slice(at,at+n);at+=n;}}
return{bufs,COL,NEON,FW,RW,ARM};};
