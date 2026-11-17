/* Cleemalt research -> native SCREEN 8 streaming and original collision records.
 * Original program ROMs are inputs only; they are not copied into the project. */
const fs=require('fs'),path=require('path');
let sharp;try{sharp=require('sharp');}catch{sharp=require('C:/Users/Andrea/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');}
const root=__dirname,dir=path.join(root,'levels');fs.mkdirSync(dir,{recursive:true});
const inputs=process.argv.slice(2);if(inputs.length!==2)throw Error('Usage: node generate-level.cjs <main-program-ROM> <sub-program-ROM>');
const main=fs.readFileSync(inputs[0]),sub=fs.readFileSync(inputs[1]).subarray(0x4000);
const tiles=fs.readFileSync(path.join(root,'../research/maps/planet-0.tiles.bin'));
const meta=JSON.parse(fs.readFileSync(path.join(root,'../research/maps/planet-0.json')));
const width=meta.widthTiles;
const word=a=>main.readUInt16BE(a-0x8000),byte=a=>main[a-0x8000];
function geometry(t){
 const id=(t&255)|((t>>8&7)<<8),empty=Array(17).fill(0);
 if(!(id&255))return empty;
 let p=sub.readUInt16BE((id&0x7f0)>>3)-0x4000;
 for(let n=0;n<256&&p>=0&&p+18<=sub.length;n++,p+=18){
  if(sub[p]===255)return empty;
  if(sub[p+1]>(id&255))return empty;
  if(sub[p+1]!==(id&255))continue;
  const g=[sub[p]&127];for(let y=0;y<4;y++)for(let x=0;x<4;x++){
   let v=sub[p+2+y*4+((t&0x8000)?3-x:x)];
   if(t&0x8000)v=((-(v&240))&240)|(v&15);
   g.push(v);
  }return g;
 }return empty;
}
const shapes=[Array(17).fill(0)],ids=new Map([[shapes[0].join(','),0]]),map=[];
for(let x=0;x<width;x++)for(let y=0;y<16;y++){
 const g=geometry(tiles.readUInt16LE((y*width+x)*2)),key=g.join(',');
 if(!ids.has(key)){ids.set(key,shapes.length);shapes.push(g);}
 map.push(ids.get(key));
}
if(shapes.length>255)throw Error('Collision shape index overflow');
const mp=word(word(0xb51b)),mw=byte(mp),mh=byte(mp+1),fp=word(0xbc13);
const floors=Array.from({length:mw},(_,x)=>word(fp+byte(mp+2+(mh-1)*mw+x)*2));
const array=(name,a)=>'static const unsigned char '+name+'[] = {\n'+Array.from({length:Math.ceil(a.length/24)},(_,i)=>' '+a.slice(i*24,i*24+24).join(',')).join(',\n')+'\n};\n';
const header='/* Generated from original collision tables FD00..FDDC and floor tables ADC7..ADE8. */\n#define LEVEL_COLUMNS '+width+'\n#define LEVEL_PIXELS '+width*16+'\n'+array('level_cells',map)+array('level_shapes',shapes.flat())+array('level_floor',floors.map(y=>y?24+Math.floor((248-y)*2/3):192));
fs.writeFileSync(path.join(root,'c/level-data.h'),header);
(async()=>{
 const image=await sharp(path.join(root,'../research/maps/planet-0.png')).removeAlpha().raw().toBuffer({resolveWithObject:true});
 const pixels=Buffer.alloc(4096*192);
 for(let y=24;y<184;y++)for(let x=0;x<width*16;x++){
  const sy=8+Math.floor((y-24)*3/2),p=(sy*image.info.width+x)*3,r=image.data[p],g=image.data[p+1],b=image.data[p+2];
  pixels[y*4096+x]=Math.round(g*7/255)*32+Math.round(r*7/255)*4+Math.round(b*3/255);
 }
 fs.writeFileSync(path.join(dir,'cleemalt.pixels.bin'),pixels);
 const initial=Buffer.alloc(256*192);for(let y=24;y<184;y++)pixels.copy(initial,y*256+8,y*4096,y*4096+240);
 function rle(b){const a=[];for(let i=0;i<b.length;){let n=1;while(n<255&&i+n<b.length&&b[i+n]===b[i])n++;a.push(n,b[i]);i+=n;}a.push(0);return Buffer.from(a);}
 fs.writeFileSync(path.join(root,'background.rle'),rle(initial));fs.writeFileSync(path.join(root,'background.raw'),initial);
 fs.writeFileSync(path.join(dir,'manifest.json'),JSON.stringify({planet:'Cleemalt',arcadeStageId:0,observedWidth:width*16,originalMacroWidth:mw*256,collisionShapes:shapes.length,collisionBytes:map.length+shapes.length*17+floors.length,floorPhysicalY:floors,videoWidth:4096,videoRows:192,banks:[64,111],note:'Foreground and collision records from arcade. Vertical geometry adapted 3:2 to the MSX viewport; background presentation is still an adaptation.'},null,2));
 console.log({pixels:pixels.length,initialRle:rle(initial).length,shapes:shapes.length,floors});
})();
