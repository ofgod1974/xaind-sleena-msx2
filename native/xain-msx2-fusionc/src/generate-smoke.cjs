/* Adapted three-frame death cloud; spare atlas row, no extra VRAM. */
const fs=require('fs'),path=require('path');
const p=path.join(__dirname,'atlas.rle'),r=fs.readFileSync(p),a=Buffer.alloc(256*64);let o=0;
for(let i=0;r[i];i+=2){a.fill(r[i+1],o,o+r[i]);o+=r[i];}
if(a.subarray(56*256).some(v=>v)){
 const old=Buffer.from(a);a.fill(0,56*256);
 for(let y=0;y<7;y++){
  old.copy(a,(48+y)*256+64,(56+y)*256,(56+y)*256+72);
  old.copy(a,(48+y)*256+144,(56+y)*256+128,(56+y)*256+182);
 }
}
for(let f=0;f<3;f++)for(let y=0;y<8;y++)for(let x=0;x<16;x++){
 let v=0;
 for(const [cx,cy,rx,ry] of [[5,4,3+f,2],[9,3,3+f,2+f/2],[12,5,2+f,2]]){
  const d=(x-cx)*(x-cx)/(rx*rx)+(y-cy)*(y-cy)/(ry*ry);
  if(d<1)v=Math.max(v,d<.45?255:(f===2?109:182));
 }
 if(f===2&&(x+y)%3===0)v=0;
 a[(48+y)*256+f*16+x]=v;
}
const out=[];for(let i=0;i<a.length;){let n=1;while(n<255&&i+n<a.length&&a[i+n]===a[i])n++;out.push(n,a[i]);i+=n;}out.push(0);
fs.writeFileSync(p,Buffer.from(out));fs.writeFileSync(path.join(__dirname,'atlas.pixels.bin'),a);
