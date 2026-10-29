const fs=require('fs'),path=require('path');
const out=path.resolve(__dirname,'..'),ref=path.join(__dirname,'reference');
const scene=fs.readFileSync(path.join(ref,'arcade-scene.rgb'));
const palette=fs.readFileSync(path.join(ref,'arcade-palette.bin'));
const sprites=fs.readFileSync(path.join(ref,'sprites.indices.bin'));
const bg=Buffer.alloc(256*192),atlas=Buffer.alloc(256*64);
// SCREEN 8: GGG RRR BB. Actual arcade RGB is quantised to the V9938 fixed palette.
function color(r,g,b){return Math.round(g*7/255)*32+Math.round(r*7/255)*4+Math.round(b*3/255);}
for(let y=24;y<184;y++)for(let x=8;x<248;x++){let sy=Math.floor((y-24)*192/160),p=(sy*512+x-8)*3;bg[y*256+x]=color(scene[p],scene[p+1],scene[p+2]);}
const font={V:['10001','10001','10001','10001','01010','01010','00100'],A:['01110','10001','10001','11111','10001','10001','10001'],E:['11111','10000','10000','11110','10000','10000','11111'],I:['111','010','010','010','010','010','111'],N:['10001','11001','10101','10011','10001','10001','10001'],X:['10001','10001','01010','00100','01010','10001','10001'],M:['10001','11011','10101','10101','10001','10001','10001'],S:['01111','10000','10000','01110','00001','00001','11110'],R:['11110','10001','10001','11110','10100','10010','10001'],G:['01111','10000','10000','10111','10001','10001','01110'],Y:['10001','10001','01010','00100','00100','00100','00100'],D:['11110','10001','10001','10001','10001','10001','11110'],O:['01110','10001','10001','10001','10001','10001','01110'],T:['11111','00100','00100','00100','00100','00100','00100'],U:['10001','10001','10001','10001','10001','10001','01110'],C:['01111','10000','10000','10000','10000','10000','01111'],L:['10000','10000','10000','10000','10000','10000','11111'],P:['11110','10001','10001','11110','10000','10000','10000'],B:['11110','10001','10001','11110','10001','10001','11110'],'2':['01110','10001','00001','00010','00100','01000','11111'],'0':['01110','10001','10011','10101','11001','10001','01110'],'1':['00100','01100','00100','00100','00100','00100','01110'],'3':['11110','00001','00001','01110','00001','00001','11110'],'4':['00010','00110','01010','10010','11111','00010','00010'],'5':['11111','10000','10000','11110','00001','00001','11110'],'6':['01110','10000','10000','11110','10001','10001','01110'],'7':['11111','00001','00010','00100','01000','01000','01000'],'8':['01110','10001','10001','01110','10001','10001','01110'],'9':['01110','10001','10001','01111','00001','00001','01110']};
function text(dst,w,x,y,s,c=15){for(const ch of s){const g=font[ch];if(g)for(let j=0;j<7;j++)for(let i=0;i<g[j].length;i++)if(g[j][i]==='1')dst[(y+j)*w+x+i]=c;x+=6;}}

const hud=Buffer.alloc(256*192);
text(hud,256,16,8,'XAIN',1);text(hud,256,104,8,'ENERGY',1);text(hud,256,174,184,'SCORE',1);
for(let y=6;y<12;y++)for(let x=148;x<172;x++)hud[y*256+x]=1;
function pattern(x,y,w=16){let p=Buffer.alloc(32);for(let j=0;j<16;j++)for(let i=0;i<w;i++)if(hud[(y+j)*256+x+i])p[(i<8?0:16)+j]|=1<<(7-i%8);return p;}
const pats=[pattern(16,8),pattern(32,8),pattern(104,8),pattern(120,8),pattern(136,8,4),pattern(148,6),pattern(164,6,8),pattern(174,184),pattern(190,184),Buffer.alloc(32),pattern(148,6,8)];
for(let d=0;d<10;d++){hud.fill(0);text(hud,256,0,0,''+d,1);pats.push(pattern(0,0,8));}
pats.push(Buffer.alloc(32,255));
// Nine energy levels, ten life labels, five weapon labels, three dynamic score patterns.
for(let n=0;n<=8;n++){hud.fill(0);for(let y=0;y<6;y++)for(let x=0;x<n*3;x++)hud[y*256+x]=1;pats.push(pattern(0,0),pattern(16,0,8));}
for(let n=0;n<=9;n++){hud.fill(0);text(hud,256,0,0,'X'+n,1);pats.push(pattern(0,0));}
for(let n=0;n<=4;n++){hud.fill(0);text(hud,256,0,0,'P'+n,1);pats.push(pattern(0,0));}
for(let n=0;n<3;n++)pats.push(Buffer.alloc(32));
fs.writeFileSync(path.join(__dirname,'hud-patterns.bin'),Buffer.concat(pats));
const hudColors=Buffer.alloc(512,15);hudColors.fill(14,5*16,7*16);hudColors.fill(0,11*16,31*16);for(let s=11;s<31;s+=2)hudColors.fill(128,s*16,(s+1)*16);fs.writeFileSync(path.join(__dirname,'hud-colors.bin'),hudColors);
const frames=[6,12,18,24,6,12,18,24,54,56];
for(let f=0;f<10;f++)for(let y=0;y<32;y++)for(let x=0;x<16;x++){
 const flip=f>=4&&f<8||f>=8,v=sprites[(frames[f]+(y>>4))*256+(y&15)*16+(flip?15-x:x)];
 if(v){let p=(128+(f>=8?16:0)+v)*3;atlas[y*256+f*16+x]=color(palette[p],palette[p+1],palette[p+2])||1;}
}

// Native sprite graphics and per-weapon palettes captured from the arcade.
const specs=[['normal',774,3060,5],['grenade',1044,3360,4],['photon',1775,3660,5],['heavyR',776,3960,5],['heavyL',776,3960,5,true],['wideR',778,4260,5],['wideL',778,4260,5,true],['power',766,3060,5]];
const rectangles=[];
function tile(t,p,frame,x0,y0,flip=false,crop=true){const pal=fs.readFileSync(path.join(ref,'weapons','palette-'+frame+'.bin'));let minx=16,miny=16,maxx=0,maxy=0;for(let y=0;y<16;y++)for(let x=0;x<16;x++)if(sprites[t*256+y*16+x]){minx=Math.min(minx,x);miny=Math.min(miny,y);maxx=Math.max(maxx,x);maxy=Math.max(maxy,y);}if(!crop){minx=miny=0;maxx=maxy=15;}let w=maxx-minx+1,h=maxy-miny+1;for(let y=0;y<h;y++)for(let x=0;x<w;x++){let v=sprites[t*256+(y+miny)*16+(flip?maxx-x:minx+x)];if(v){let q=(128+p*16+v)*3;atlas[(y0+y)*256+x0+x]=color(pal[q],pal[q+1],pal[q+2])||1;}}return [x0,y0,w,h];}
for(let i=0;i<specs.length;i++){const [name,t,f,p,flip]=specs[i];rectangles.push({name,rect:tile(t,p,f,i*16,32,flip)});}
// Firing standing pose (250+1), kneeling (26+27), and prone (23,28,29).
for(let flip=0;flip<2;flip++){
 for(let y=0;y<32;y++)for(let x=0;x<16;x++){let t=y<16?250:1,v=sprites[t*256+(y%16)*16+(flip?15-x:x)];if(v){let q=(128+v)*3;atlas[y*256+192+flip*16+x]=color(palette[q],palette[q+1],palette[q+2])||1;}}
 for(let y=0;y<32;y++)for(let x=0;x<16;x++){let t=26+(y>>4),v=sprites[t*256+(y%16)*16+(flip?15-x:x)];if(v){let q=(128+v)*3;atlas[y*256+224+flip*16+x]=color(palette[q],palette[q+1],palette[q+2])||1;}}
 const body=Buffer.alloc(32*32);for(let y=0;y<16;y++)for(let x=0;x<32;x++)body[(y+16)*32+x]=sprites[(x<16?34:33)*256+y*16+(x%16)];
 for(let y=16;y<32;y++)for(let x=0;x<32;x++){let v=body[y*32+(flip?31-x:x)];if(v){let q=(128+v)*3;atlas[(y+16)*256+128+flip*32+x]=color(palette[q],palette[q+1],palette[q+2])||1;}}
}
for(let i=0;i<3;i++)tile(1024+i*2,4,3360,192+i*16,32,false,false);
rectangles.push({name:'wideOuterR',rect:tile(776,5,4260,160,0)});
rectangles.push({name:'wideOuterL',rect:tile(776,5,4260,176,0,true)});
fs.writeFileSync(path.join(__dirname,'weapon-rects.asm'),rectangles.map(o=>'    DB '+o.rect.join(',')+' ; '+o.name).join('\n')+'\n');
fs.writeFileSync(path.join(__dirname,'weapon-assets.json'),JSON.stringify({source:'Original arcade sprite indices and per-weapon YM palette snapshots',sprites:rectangles},null,2));
text(atlas,256,0,56,'SECTOR CLEAR',255);text(atlas,256,128,56,'GAME OVER',255);
function rle(b){let a=[];for(let i=0;i<b.length;){let n=1;while(n<255&&i+n<b.length&&b[i+n]===b[i])n++;a.push(n,b[i]);i+=n;}a.push(0);return Buffer.from(a);}
for(const [name,p] of [['background',bg],['atlas',atlas]]){let r=rle(p);fs.writeFileSync(path.join(__dirname,name+'.rle'),r);fs.writeFileSync(path.join(__dirname,name+'.pixels.bin'),p);console.log(name,p.length,'=>',r.length);}
fs.writeFileSync(path.join(__dirname,'background.raw'),bg);
