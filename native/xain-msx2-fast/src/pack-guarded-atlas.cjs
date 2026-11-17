/* Run after generate-assets/generate-smoke, before assembling the ROM. */
const fs=require('fs'),path=require('path'),b=__dirname+'/',r=fs.readFileSync(b+'atlas.rle'),old=Buffer.alloc(16384);let o=0;
for(let i=0;r[i];i+=2){old.fill(r[i+1],o,o+r[i]);o+=r[i];}
if(!old.subarray(0,2048).some(v=>v))throw Error('Atlas already guarded; regenerate base assets first.');
for(const [name,x,width] of [['clear',64,72],['gameover',144,54]]){
 const out=Buffer.alloc(104*8);for(let y=0;y<8;y++)old.copy(out,y*104,(48+y)*256+x,(48+y)*256+x+width);fs.writeFileSync(b+'status-'+name+'.bin',out);
}
const a=Buffer.alloc(16384);for(let y=0;y<48;y++)old.copy(a,(y+8)*256,y*256,(y+1)*256);
for(let y=0;y<8;y++)old.copy(a,(48+y)*256,(48+y)*256,(48+y)*256+48);
const out=[];for(let i=0;i<a.length;){let n=1;while(n<255&&i+n<a.length&&a[i+n]===a[i])n++;out.push(n,a[i]);i+=n;}out.push(0);
fs.writeFileSync(b+'atlas.rle',Buffer.from(out));fs.writeFileSync(b+'atlas.pixels.bin',a);
