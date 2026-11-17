/* Extract only observed foreground cells. Unknown cells remain explicitly unknown.
 * The forced-position MAME runs are graphic/layout references, not AI/timing data. */
const fs=require('fs'),path=require('path');
const sharp=require('sharp');
const captures=path.resolve(process.argv[2]||'work/map-reference');
const graphics=path.resolve(process.argv[3]||'outputs/arcade-grafica');
const dest=path.resolve(process.argv[4]||'outputs/xain-msx2-fusionc/research/maps');fs.mkdirSync(dest,{recursive:true});
const foreground=fs.readFileSync(path.join(graphics,'fondale-a.indices.bin'));
const background=fs.readFileSync(path.join(graphics,'fondale-b.indices.bin'));
const index=(x,y)=>(x&15)+((y&15)<<4)+((x&16)<<4)+((y&16)<<5);
function tileAt(s,base,x,y){const i=index(x&31,y&31);return s[base+i]|(s[base+i+1024]<<8);}
function pixel(raw,t,x,y){const attr=t>>8,id=(t&255)|((attr&7)<<8);return {v:raw[id*256+y*16+((attr&128)?15-x:x)],bank:(attr>>4)&7};}
(async()=>{const report=[];for(const id of [0,1,2,4,5]){
 const dir=path.join(captures,'planet-'+id),frames=fs.readdirSync(dir).filter(n=>/^state-\d+\.bin$/.test(n)).map(n=>+n.match(/\d+/)[0]).sort((a,b)=>a-b);
 const cells=new Map();let maxX=0,maxY=0,minX=Infinity,minY=Infinity,palette,firstState,firstScroll;let snapshots=0;
 for(const f of frames){const s=fs.readFileSync(path.join(dir,'state-'+f+'.bin')),r=fs.readFileSync(path.join(dir,'scroll-'+f+'.bin'));
  if(s[0x48]!==id||s[0x53]!==0||s[0x52]!==2)continue;
  const sx=r.readUInt16LE(0),sy=r.readUInt16LE(2),wy=sy-256;
  if(wy<0||wy>2048)continue;
  if(!palette){palette=fs.readFileSync(path.join(dir,'palette-'+f+'.bin'));firstState=s;firstScroll=r;}
  snapshots++;
  for(let row=Math.floor((wy+8)/16);row<=Math.floor((wy+247)/16);row++)for(let col=Math.floor(sx/16);col<=Math.floor((sx+255)/16);col++){
   const t=tileAt(s,0x2800,col,row+16),key=col+','+row;
   if(!cells.has(key))cells.set(key,new Map());const counts=cells.get(key);counts.set(t,(counts.get(t)||0)+1);
   maxX=Math.max(maxX,col);maxY=Math.max(maxY,row);minX=Math.min(minX,col);minY=Math.min(minY,row);
  }
 }
 const w=maxX+1,h=maxY+1,tiles=Buffer.alloc(w*h*2,255),known=Buffer.alloc(w*h),rgb=Buffer.alloc(w*h*256*3);
 let animated=0;
 for(const [key,values] of cells){const [x,y]=key.split(',').map(Number),choice=[...values].sort((a,b)=>b[1]-a[1])[0][0];tiles.writeUInt16LE(choice,(y*w+x)*2);known[y*w+x]=1;if(values.size>1)animated++;}
 const bw=firstScroll.readUInt16LE(4),bh=firstScroll.readUInt16LE(6);
 for(let y=0;y<h*16;y++)for(let x=0;x<w*16;x++){
  const cell=(y>>4)*w+(x>>4),p=(y*w*16+x)*3;
  if(!known[cell]){rgb[p]=((x>>3)^(y>>3))&1?80:30;rgb[p+2]=rgb[p];continue;}
  const fg=pixel(foreground,tiles.readUInt16LE(cell*2),x&15,y&15);
  let color=256+fg.bank*16+fg.v;
  if(!fg.v){const bx=(x%256+bw)&511,by=(y+bh)&511,bg=pixel(background,tileAt(firstState,0x3000,bx>>4,by>>4),bx&15,by&15);color=384+bg.bank*16+bg.v;}
  palette.copy(rgb,p,color*3,color*3+3);
 }
 fs.writeFileSync(path.join(dest,'planet-'+id+'.tiles.bin'),tiles);fs.writeFileSync(path.join(dest,'planet-'+id+'.known.bin'),known);fs.writeFileSync(path.join(dest,'planet-'+id+'.palette.bin'),palette);
 await sharp(rgb,{raw:{width:w*16,height:h*16,channels:3}}).png().toFile(path.join(dest,'planet-'+id+'.png'));
 const entry={arcadeStageId:id,widthTiles:w,heightTiles:h,observedCells:cells.size,totalCells:w*h,coverage:cells.size/(w*h),cellsWithMultipleObservedValues:animated,snapshots,complete:false,tileFormat:'little-endian uint16: original tile byte | attribute byte << 8; known.bin determines validity',preview:'planet-'+id+'.png',note:'Observed cells only. Preview background repeats its first 256-pixel window; no claim of original parallax. Capture forces player position and health.'};
 fs.writeFileSync(path.join(dest,'planet-'+id+'.json'),JSON.stringify(entry,null,2));report.push(entry);
 }
 fs.writeFileSync(path.join(dest,'manifest.json'),JSON.stringify({source:'MAME 0.289 xsleenaba; original graphics/layout via xain.cpp/xain_v.cpp',status:'Research data, not playable converted levels',stages:report},null,2));console.log(report.map(e=>({id:e.arcadeStageId,size:[e.widthTiles*16,e.heightTiles*16],coverage:e.coverage})));})();
