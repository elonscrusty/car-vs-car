// Toxic Hot Rod (carter picked High, 10-29): faceted low-poly body lofted from rings along Z (nose +Z, up +Y,
// ground y = 0, car left = +X). One generator for the preview page (kart-preview/toxic-tries) and the game files
// (export.js): opt.detail 0 low / 1 middle / 2 high, opt.splitWheels keeps each wheel apart. No weapon on the body.
// Returns {bufs:{key:[x,y,z,...]}, COL, NEON}.
window.genHotRod=function(opt){
opt=opt||{};const D=opt.detail===undefined?2:opt.detail;   // 0 low, 1 middle, 2 high
const ACC=opt.acc||[48,208,36];
const COL={body:[16,17,21],acc:ACC,glass:[14,20,32],chrome:[205,210,220],chrome2:[150,155,165],dark:[9,9,11],tire:[22,22,26],trim:[38,40,46],belt:[18,18,18]};
const NEON={lamp:opt.lamp||[255,238,120],glow:opt.glow||[120,255,70],tail:[255,36,36],plate:[235,240,225]};
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
const FW={z:3.05,y:0.92,r:0.92,R:1.06,w:0.95,x:2.5};   // front wheel (skinny)
const RW={z:-2.85,y:1.12,r:1.12,R:1.3,w:1.25,x:2.6};    // rear wheel (fat)
const SILL=0.6;
const WT=[[5.12,2.5],[4.95,2.72],[4.6,2.9],[4.1,2.98],[3.05,3.0],[2.0,2.96],[1.6,2.8],[-1.0,2.8],[-1.5,2.98],[-2.85,3.25],[-4.0,3.2],[-4.6,3.05],[-4.95,2.9],[-5.12,2.7]];
const FT=[[5.12,1.72],[4.95,1.88],[4.6,2.08],[4.1,2.32],[3.05,2.45],[2.0,2.32],[1.3,2.15],[-1.0,2.16],[-1.6,2.36],[-2.85,2.75],[-3.9,2.62],[-4.6,2.36],[-4.95,2.5],[-5.12,2.2]];
const HT=[[5.12,1.7],[4.95,1.86],[4.6,1.95],[4.1,2.0],[3.05,2.04],[2.0,2.07],[1.3,2.1],[-1.2,2.12],[-2.9,2.14],[-3.9,2.14],[-4.6,2.12],[-4.95,2.42],[-5.12,2.18]];
const ST=[];
const st=(z,yb)=>ST.push({z,yb});
st(5.12,0.85);st(4.95,0.72);st(4.6,SILL);st(4.35,SILL);
const AN=D===0?4:D===1?6:8;
function arch(Wh){st(Wh.z+Wh.R,SILL);for(let i=0;i<=AN;i++){const g=i*Math.PI/AN;st(Wh.z+Wh.R*Math.cos(g),Wh.y+Wh.R*Math.sin(g));}st(Wh.z-Wh.R,SILL);}
arch(FW);[1.6,1.0,0.3,-0.4,-1.0,-1.3].forEach(z=>st(z,SILL));arch(RW);
[-4.4,-4.7].forEach(z=>st(z,SILL));st(-4.95,0.72);st(-5.12,0.85);
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
   // keep winding outward
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

// ---------------- cabin ----------------
const CS=[[1.85,2.2,2.17,2.27,2.0],[0.45,2.15,2.2,2.97,1.62],[-0.2,2.15,2.2,3.0,1.62],[-0.45,2.15,2.2,3.0,1.62],[-1.25,2.15,2.2,2.97,1.62],[-2.45,2.2,2.2,2.3,1.98]];
const CLR=['cbase','cside','cedge','roof','rstripe'];const CLAB=[...CLR,'rgap',...CLR.slice().reverse(),'cfloor'];
const cabR=CS.map(([z,wb,ybl,yr,wr])=>{const R=[[wb,1.95],[wb,ybl],[Math.min(wb-0.02,wr+0.24),Math.max(ybl,yr-0.12)],[wr,yr],[0.62,yr],[0.12,yr]];const L=R.slice().reverse().map(p=>[-p[0],p[1]]);return[...R,...L].map(p=>[p[0],p[1],z]);});
loftL(cabR,CLAB,(c,n,lab,i)=>{
 if(lab==='cfloor')return'dark';
 if(lab==='cbase'||lab==='cedge')return'body';
 if(lab==='cside')return(i===2||i===4)?'body':'glass';
 if(i===0||i===4)return'glass';
 return lab==='rstripe'?'acc':'body';},true,'body');
// chrome window trim along the belt + drip rails
if(D>=1)for(const s of[1,-1]){box('chrome',s*2.19,2.2,-0.3,0.05,0.05,4.2);
 cyl('chrome',[s*1.74,2.95,0.45],[s*1.74,2.98,-1.25],0.035,6);}

// ---------------- side details ----------------
const DW=2.8; // door width (flat area)
function sideDecal(k,pts,off){const tr=triangulate(pts);for(const s of[1,-1])for(const t of tr){const P=t.map(i=>[s*(DW+off),pts[i][1],pts[i][0]]);if(s>0)tri(k,P[0],P[2],P[1]);else tri(k,P[0],P[1],P[2]);}}
// toxic drips hanging from the belt line
if(D===0)sideDecal('acc',[[1.55,1.71],[-0.95,1.71],[-0.95,1.5],[1.55,1.5]],0.014);
else (function(){const top=1.71,base=1.56,z0=1.55,z1=-0.95;const drips=[[1.4,0.55],[1.15,0.92],[0.9,0.38],[0.64,0.74],[0.38,0.28],[0.14,0.6],[-0.12,0.22]];
 const P=[[z0,top]];P.push([z1,top]);P.push([z1,base]);
 for(let i=drips.length-1;i>=0;i--){const[zd,len]=drips[i];const w=0.1;const yt=base-len;P.push([zd-w,base]);P.push([zd-w*0.75,yt+0.13]);P.push([zd-w*0.35,yt+0.02]);P.push([zd+w*0.35,yt+0.02]);P.push([zd+w*0.75,yt+0.13]);P.push([zd+w,base]);}
 P.push([z0,base]);
 // P goes z0->z1 along top, then back: needs z increasing along base
 const ordered=[[z0,top],[z1,top],[z1,base]];const rest=[];for(const[zd,len]of drips.slice().reverse()){const w=0.1,yt=base-len;rest.push([zd-w,base],[zd-w*0.75,yt+0.13],[zd-w*0.35,yt+0.02],[zd+w*0.35,yt+0.02],[zd+w*0.75,yt+0.13],[zd+w,base]);}
 sideDecal('acc',[...ordered,...rest,[z0,base]],0.014);
 // thin pin line above
 sideDecal('acc',[[z0,1.745],[z1,1.745],[z1,1.765],[z0,1.765]],0.014);})();
// radiation sign on the door
if(D>=1)(function(){const zc=-0.5,yc=1.04;const disc=ngon(16,0.33,0).map(p=>[zc+p[0],yc+p[1]]);sideDecal('acc',disc,0.016);
 for(const a0 of[Math.PI/2,Math.PI/2+2*Math.PI/3,Math.PI/2+4*Math.PI/3]){const P=[];for(let i=0;i<=4;i++){const g=a0-Math.PI/6+i*Math.PI/12;P.push([zc+Math.cos(g)*0.28,yc+Math.sin(g)*0.28]);}
  for(let i=4;i>=0;i--){const g=a0-Math.PI/6+i*Math.PI/12;P.push([zc+Math.cos(g)*0.085,yc+Math.sin(g)*0.085]);}sideDecal('dark',P,0.022);}
 sideDecal('dark',ngon(8,0.05,0).map(p=>[zc+p[0],yc+p[1]]),0.022);
 const rim=[];const ro=ngon(16,0.33,0),ri=ngon(16,0.3,0);})();
// door seams + handle
if(D>=1)for(const zz of[1.52,-0.92])sideDecal('dark',[[zz+0.018,0.78],[zz+0.018,1.78],[zz-0.018,1.78],[zz-0.018,0.78]],0.008);
for(const s of[1,-1]){if(D>=1)box('chrome',s*2.85,1.47,-0.68,0.06,0.07,0.32);
 // mirror
 cyl('dark',[s*2.62,2.13,1.48],[s*2.98,2.3,1.42],0.04,6);box('dark',s*3.06,2.33,1.4,0.14,0.22,0.36);if(D>=1)box('chrome',s*3.06,2.33,1.21,0.1,0.18,0.03);
 // gas cap on the rear hip
 if(D>=2){const zf=-3.45,tf=interp(FT,zf),wf=interp(WT,zf);cyl('chrome',[s*(wf-0.52),tf-0.01,zf],[s*(wf-0.52),tf+0.04,zf],0.14,8,0.14,0);}
}
// zoomie headers + side pipes with glowing tips
for(const s of[1,-1]){const X=s*3.04,Y=0.74;
 for(let i=0;i<(D===0?0:D===1?2:4);i++){const y0=1.02+i*0.17,z0=1.82;const a=[s*2.86,y0,z0],m=[s*3.04,y0-0.02,z0-0.02],e=[X,Y+0.04,1.48-i*0.02];cyl('chrome',a,m,0.06,6);cyl('chrome',m,e,0.06,6);box('chrome',m[0],m[1],m[2],0.12,0.12,0.12);}
 cyl('chrome',[X,Y,1.5],[X,Y,1.25],0.1,10,0.15);
 cyl('chrome',[X,Y,1.25],[X,Y,-1.15],0.15,10);
 cyl('chrome',[X,Y,-1.15],[X,Y,-1.42],0.15,10,0.19);
 cyl('glow',[X,Y,-1.425],[X,Y,-1.43],0.15,10);
 // heat shield
 if(D>=2){box('chrome2',X+s*0.13,Y+0.02,0.1,0.05,0.24,2.0);for(let i=0;i<8;i++)box('dark',X+s*0.16,Y+0.02,1.0-i*0.26,0.02,0.07,0.1);}
 for(const zb of[0.95,-0.75])box('dark',s*2.92,Y+0.02,zb,0.22,0.06,0.1);}

// ---------------- front ----------------
const ZF=5.12;
box('dark',0,1.3,ZF+0.01,4.5,0.74,0.04);
// grille
box('dark',0,1.3,ZF+0.03,1.9,0.52,0.06);
box('chrome',0,1.58,ZF+0.06,2.04,0.06,0.06);box('chrome',0,1.02,ZF+0.06,2.04,0.06,0.06);
for(const s of[1,-1])box('chrome',s*0.99,1.3,ZF+0.06,0.06,0.62,0.06);
for(let i=-3;i<=3;i+=(D===0?3:1))box('chrome',i*0.24,1.3,ZF+0.06,0.035,0.5,0.04);
box('chrome',0,1.3,ZF+0.07,1.9,0.035,0.04);
if(D>=1)prism('acc',ngon(6,0.13,0),0.06,(u,v,t)=>[u,1.3+v,ZF+0.1+t]);
// quad octagon headlights with chrome bezels
for(const s of[1,-1]){box('trim',s*1.62,1.3,ZF+0.02,1.12,0.56,0.05);
 for(const x of[1.33,1.9]){prism('lamp',ngon(8,0.2),0.05,(u,v,t)=>[s*x+u,1.3+v,ZF+0.06+t]);
  if(D>=1)ringPrism('chrome',8,0.2,0.26,0.08,(u,v,t)=>[s*x+u,1.3+v,ZF+0.07+t]);
  if(D>=2)prism('lamp',ngon(8,0.07),0.02,(u,v,t)=>[s*x+u,1.3+v,ZF+0.1+t]);}}
// hood pins
if(D>=2)for(const s of[1,-1])cyl('chrome',[s*1.15,interp(HT,4.55)-0.01,4.55],[s*1.15,interp(HT,4.55)+0.05,4.55],0.06,8);
// chrome wrap bumper (faceted cross-section)
const BCS=[[-0.17,-0.15],[0.1,-0.15],[0.2,-0.06],[0.2,0.07],[0.1,0.15],[-0.17,0.15]];
function bar(k,x0,x1,place){prism(k,BCS,x1-x0,(u,v,t)=>place([(x0+x1)/2+t,v,u]));}
bar('chrome',-1.95,1.95,p=>[p[0],0.86+p[1],ZF+0.18+p[2]]);
if(D>=1)for(const s of[1,-1]){const piv=[s*1.95,0.86,ZF+0.18];bar('chrome',0,0.7,p=>{const q=rotY(s*0.6)([p[0]*s,p[1],p[2]]);return[piv[0]+q[0],piv[1]+q[1],piv[2]+q[2]];});
 bar('chrome',0,0.6,p=>{const q=rotY(s*Math.PI/2)([p[0]*s,p[1],p[2]]);return[s*2.53+q[0],0.86+q[1],ZF-0.215+q[2]];});
 box('glow',s*1.45,0.86,ZF+0.385,0.42,0.1,0.02);
 if(D>=2)box('chrome',s*0.75,0.98,ZF+0.27,0.12,0.1,0.14);}
box('dark',0,0.62,ZF-0.05,4.4,0.12,0.7);box('dark',0,0.58,ZF+0.3,3.6,0.05,0.2);
// ---------------- blower ----------------
(function(){const zc=FW.z+0.05,y0=interp(HT,zc);box('dark',0,y0+0.05,zc,1.5,0.1,1.75);
 const CSx=[[-0.62,0],[0.62,0],[0.68,0.12],[0.68,0.42],[0.6,0.52],[-0.6,0.52],[-0.68,0.42],[-0.68,0.12]];
 prism('chrome',CSx,1.5,(u,v,t)=>[u,y0+0.1+v,zc+t]);
 if(D>=1)for(let i=0;i<6;i++){const z=zc-0.62+i*0.25;prism('chrome2',CSx.map(p=>[p[0]*1.06,p[1]*1.08-0.02]),0.05,(u,v,t)=>[u,y0+0.1+v,z+t]);}
 // snout + pulley + belt
 if(D>=2){box('chrome2',0,y0+0.34,zc+0.8,0.7,0.36,0.12);
 prism('dark',ngon(10,0.23),0.1,(u,v,t)=>[u,y0+0.36+v,zc+0.9+t]);prism('chrome',ngon(10,0.12),0.12,(u,v,t)=>[u,y0+0.36+v,zc+0.91+t]);
 box('belt',0,y0+0.12,zc+0.9,0.36,0.42,0.06);}
 const yt=y0+0.62;box('dark',0,yt+0.03,zc,1.1,0.06,1.0);
 if(D>=1)for(const s of[1,-1]){box('chrome',s*0.24,yt+0.17,zc,0.38,0.22,0.5);box('chrome2',s*0.24,yt+0.29,zc,0.42,0.04,0.54);}
 // bug-catcher scoop, open mouth glowing
 const yS=yt+0.31;const SP=[[-0.42,0],[0.48,0],[0.62,0.56],[-0.42,0.46]];
 prism('dark',SP,1.0,(u,v,t)=>[t,yS+v,zc+u]);
 const mouth=[[0.5,0.06],[0.6,0.5]];const m0=[0.5,0.07],m1=[0.6,0.5];
 const nx=(m1[0]-m0[0]),ny=(m1[1]-m0[1]);
 prism('glow',[[-0.42,0.08],[0.42,0.08],[0.42,0.42],[-0.42,0.42]],0.02,(u,v,t)=>[u,yS+0.07+(v-0.08)/0.34*0.43,zc+0.505+(v-0.08)/0.34*0.1+t+0.012]);
 if(D>=1){for(let i=0;i<4;i++){const f=0.12+i*0.25;box('chrome',0,yS+0.07+f*0.43,zc+0.52+f*0.1,0.86,0.025,0.03);}
 const lip=(a,b)=>cyl('chrome',a,b,0.035,6);
 lip([-0.5,yS+0.04,zc+0.5],[0.5,yS+0.04,zc+0.5]);lip([-0.5,yS+0.57,zc+0.63],[0.5,yS+0.57,zc+0.63]);
 lip([0.5,yS+0.04,zc+0.5],[0.5,yS+0.57,zc+0.63]);lip([-0.5,yS+0.04,zc+0.5],[-0.5,yS+0.57,zc+0.63]);}
 for(const s of[1,-1])box('acc',s*0.505,yS+0.25,zc,0.02,0.12,0.8);
})();
// ---------------- rear ----------------
const ZR=-5.12;
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
