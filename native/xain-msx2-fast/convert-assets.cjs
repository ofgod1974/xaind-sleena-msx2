/* Convert the sibling SCREEN 8 assets to packed SCREEN 5 without changing code. */
const fs=require('fs'),path=require('path');
const from=path.resolve(process.argv[2]||path.join(__dirname,'../xain-msx2-fusionc')),b=path.join(__dirname,'src');
const {palette,lut}=JSON.parse(fs.readFileSync(path.join(b,'screen5-palette.json')));
function pack(a){const o=Buffer.alloc(a.length/2);for(let i=0;i<a.length;i+=2)o[i>>1]=(lut[a[i]]<<4)|lut[a[i+1]];return o;}
function unpack(r){const out=[];for(let i=0;r[i];i+=2)for(let j=0;j<r[i];j++)out.push(r[i+1]);return Buffer.from(out);}
function rle(a){let r=[];for(let i=0;i<a.length;){let n=1;while(n<255&&i+n<a.length&&a[i+n]===a[i])n++;r.push(n,a[i]);i+=n;}r.push(0);return Buffer.from(r);}
for(const name of ['background','atlas']){let raw=unpack(fs.readFileSync(path.join(from,'src',name+'.rle')));if(raw.length!==(name==='background'?49152:16384))throw Error('Expected SCREEN8 source');const packed=pack(raw);fs.writeFileSync(path.join(b,name+'.rle'),rle(packed));if(name==='background')fs.writeFileSync(path.join(b,'background.raw'),packed);}
for(const name of ['clear','gameover'])fs.writeFileSync(path.join(b,'status-'+name+'.bin'),pack(fs.readFileSync(path.join(from,'src/status-'+name+'.bin'))));
fs.writeFileSync(path.join(b,'levels/cleemalt.pixels.bin'),pack(fs.readFileSync(path.join(from,'src/levels/cleemalt.pixels.bin'))));
const front=fs.readFileSync(path.join(from,'src/frontend/pages.bin')),out=Buffer.alloc(131072,255);for(let i=0;i<4;i++){let raw=unpack(front.subarray(i*32768,(i+1)*32768));if(raw.length!==49152)throw Error('Front-end source');rle(pack(raw)).copy(out,i*32768);}fs.writeFileSync(path.join(b,'frontend/pages.bin'),out);
const pal=[];for(const [r,g,blue]of palette)pal.push((r<<4)|blue,g);fs.writeFileSync(path.join(b,'palette.bin'),Buffer.from(pal));
console.log('SCREEN5 assets converted');

require('./src/generate-player.cjs');
