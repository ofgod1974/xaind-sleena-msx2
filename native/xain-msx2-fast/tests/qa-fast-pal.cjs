const fs=require('fs'),http=require('http'),path=require('path');
const {chromium}=require('C:/Users/Andrea/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve('outputs/xain-msx2-fast');
const server=http.createServer((req,res)=>{const p=path.resolve(root,'.'+(req.url.split('?')[0]==='/'?'/index.html':req.url.split('?')[0]));if(!p.startsWith(root+path.sep)){res.writeHead(403);return res.end();}fs.readFile(p,(e,b)=>{if(e){res.writeHead(404);return res.end();}res.setHeader('Content-Type',p.endsWith('.html')?'text/html':p.endsWith('.js')?'application/javascript':'application/octet-stream');res.end(b);});});
(async()=>{await new Promise(r=>server.listen(8766,'127.0.0.1',r));const browser=await chromium.launch({executablePath:path.resolve('work/browsers/chromium_headless_shell-1234/chrome-headless-shell-win64/chrome-headless-shell.exe'),headless:true,args:['--autoplay-policy=no-user-gesture-required','--allow-file-access-from-files']});
try{const p=await browser.newPage();p.on('pageerror',e=>console.error(e));
const offline=path.resolve('work/qa-fusion-offline.html');fs.writeFileSync(offline,fs.readFileSync(path.join(root,'index.html'),'utf8').replace(/<script[\s\S]*?<\/script>/g,''));await p.goto(require('url').pathToFileURL(offline).href);
await p.addScriptTag({content:fs.readFileSync(path.join(root,'wmsx.js'),'utf8')});
await p.evaluate(rom=>{Object.assign(WMSX,{MACHINE:'MSX2E',CARTRIDGE1_URL:'data:application/octet-stream;base64,'+rom,CARTRIDGE1_FORMAT:'ASCII16',AUTO_START:false,SCREEN_FULLSCREEN_MODE:0,SCREEN_FILTER_MODE:0,SCREEN_CRT_MODE:0});WMSX.start();},fs.readFileSync(path.join(root,'xain-msx2.rom')).toString('base64'));
await p.waitForFunction(()=>typeof WMSX!=='undefined'&&WMSX.room?.machine?.bus,null,{timeout:30000});
await p.waitForFunction(()=>WMSX.room.machine.eval('bus.read(0xc810)')===5,null,{timeout:60000});
const read=()=>p.evaluate(()=>({phase:WMSX.room.machine.eval('bus.read(0xc810)'),pc:WMSX.room.machine.cpu.eval('PC'),px:WMSX.room.machine.eval('bus.read(0xc000)'),py:WMSX.room.machine.eval('bus.read(0xc001)'),tick:WMSX.room.machine.eval('bus.read(0xc004)'),hp:WMSX.room.machine.eval('bus.read(0xc00d)'),irq:WMSX.room.machine.eval('bus.read(0xc334)'),bank:WMSX.room.machine.eval('bus.read(0xc33d)')}));
console.log('title',await read());
for(let i=0;i<20;i++){if((await read()).phase===0)break;await p.keyboard.down('Space');await p.waitForTimeout(140);await p.keyboard.up('Space');await p.waitForTimeout(1700);console.log('intro',(await read()).phase);}
if((await read()).phase!==0)throw Error('Did not reach gameplay');
console.log('game',await read());
await p.keyboard.down('ArrowRight');await p.waitForTimeout(1800);await p.keyboard.up('ArrowRight');console.log('right',await read());
await p.keyboard.press('Space');await p.waitForTimeout(100);console.log('shot',await read());
await p.keyboard.down('ArrowUp');await p.waitForTimeout(150);await p.keyboard.up('ArrowUp');console.log('jump',await read());
await p.screenshot({path:path.join(root,'fusion-c-webmsx.png')});
fs.writeFileSync(path.join(root,'qa-smoke.json'),JSON.stringify(await read(),null,2));
const keyChecks=[];
for(const expected of [1,0]){await p.keyboard.down('t');await p.waitForTimeout(350);const held=await p.evaluate(()=>WMSX.room.machine.eval('bus.read(0xc942)'));await p.keyboard.up('t');await p.waitForTimeout(100);if(held!==expected)throw Error('Trainer key toggle failed '+held);keyChecks.push({expected,actual:held,pass:true});}
fs.writeFileSync(path.join(root,'qa-trainer-keyboard.json'),JSON.stringify(keyChecks,null,2));
const irq0=await p.evaluate(()=>{let b=WMSX.room.machine.eval('bus');return [b.read(0xc334),b.read(0xc3a9)];});await p.waitForTimeout(500);const irq1=await p.evaluate(()=>{let b=WMSX.room.machine.eval('bus');return [b.read(0xc334),b.read(0xc3a9)];});const frameIrqs=(irq1[0]-irq0[0])&255,lineIrqs=(irq1[1]-irq0[1])&255;if(!frameIrqs||Math.abs(lineIrqs-frameIrqs*2)>4)throw Error('Raster IRQ clock mismatch');fs.writeFileSync(path.join(root,'qa-raster-clock.json'),JSON.stringify({frameIrqs,lineIrqs,pass:true},null,2));
const map=fs.readFileSync(path.join(root,'build/core.map'),'utf8');
const symbols={};for(const name of ['game_weapons','game_update','game_lose_life','game_stance','level_init','level_physics','level_can_move','level_solid','level_floor_at','level_enemy_floor']){const m=map.match(new RegExp('([0-9A-F]{8})  _'+name+'\\s'));if(!m)throw Error('Missing '+name);symbols[name]=parseInt(m[1],16);}
const asm=fs.readFileSync(path.join(root,'symbols.txt'),'utf8');for(const name of ['level_copy_rect','level_incoming_column','vertical_update','scroll_pipeline','render','main','restore_actors','scroll_init','docmd','waitvdp','player_sprite_update','player_sprite_upload'])symbols[name]=parseInt(asm.match(new RegExp('^'+name+': EQU 0x([0-9A-F]+)','mi'))[1],16);
const raster=fs.readFileSync(path.join(root,'src/levels/cleemalt.pixels.bin'));
const expected=[];for(let y=24;y<184;y++)for(let x=1000;x<1032;x++)expected.push(raster[y*4096+x]);
const incoming=[];for(let y=24;y<184;y++)for(let x=464;x<480;x++)incoming.push(raster[y*4096+x]);
const checks=await p.evaluate(({symbols,expected,incoming,raster})=>{
 const m=WMSX.room.machine; m.cpuPause(true,false,true);
 const bus=m.eval('bus'),cpu=m.cpu,results=[];cpu.setZ80BUSRQ(false);
 const r=a=>bus.read(a),w=(a,v)=>bus.write(a,v&255);
 function clear(){for(let a=0xc900;a<0xc960;++a)w(a,0);w(0xc902,128);w(0xc903,141);for(let a=0xc000;a<0xc0b0;++a)w(a,0);for(let a=0xc400;a<0xc740;++a)w(a,0);w(0xc000,32);w(0xc001,128);w(0xc00d,16);w(0xc504,3);w(0xc50a,0xa7);}
 function call(name,args=[]){w(0x7000,3);w(0xc33d,3);args.forEach((v,i)=>w(0xef00+i,v));w(0xc9f0,0xc3);w(0xc9f1,0xf0);w(0xc9f2,0xc9);w(0xeefe,0xf0);w(0xeeff,0xc9);cpu.eval('PC='+symbols[name]+';SP=0xeefe;IFF1=0;INT=255;ackINT=false;prefix=0;T=-1;W=0');for(let i=0;i<100000;i++){if(name==='render'&&i%1000===0)m.vdp.eval('VR=1-VR');cpu.busClockPulses(100);const pc=cpu.eval('PC');if(pc>=0xc9f0&&pc<=0xc9f2)return cpu.eval('HL&255');}throw Error('C routine did not return: '+name+' PC='+cpu.eval('PC')+' row='+r(0xc037)+' count='+r(0xc038)+' CE='+m.vdp.eval('commandProcessor.updateStatus();status[2]')); }
 function check(name,ok,actual){results.push({name,pass:!!ok,actual});if(!ok)throw Error(name+': '+JSON.stringify(actual));}
 const shapes=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,1,0,0,225,1,0,0,225,1,0,225,225,1,1,0,225,225,225,0,225,225,225,0,225,225,225,0,225,225,225,1,0,0,225,193,0,0,193,193,0,0,193,193,0,193,193,193,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,33,0,0,1,33,0,0,1,33,0,0,1,33,33,0,0,33,33,64,0,33,33,65,0,33,33,65,0,1,1,65,65,0,1,65,65,0,1,65,65,0,1,65,65,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,1,0,0,193,1,0,209,193,1,0,209,193,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,1,1,1,0,0,1,1,65,0,1,1,65,0,1,1,65,0,7,0,0,0,0,0,225,1,33,0,193,1,65,225,193,1,65,7,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,7,0,0,0,0,225,1,33,0,193,1,65,0,193,1,65,33,6,0,113,113,113,0,113,113,113,0,113,113,113,0,113,113,113,6,193,193,65,65,193,193,65,65,193,193,65,65,193,193,65,65,6,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,8,1,1,1,1,1,1,1,1,193,193,193,193,193,193,193,193,8,193,193,193,193,193,193,193,193,193,193,193,193,193,193,193,193,8,1,1,225,225,1,1,225,225,225,225,225,225,225,225,225,225,8,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,8,0,0,193,193,0,0,193,193,0,0,193,193,0,0,193,193,8,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,8,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,18,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,18,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,9,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,9,0,0,0,0,0,1,1,1,0,1,1,1,0,0,0,0,8,33,33,33,33,33,33,33,33,33,33,33,33,33,33,33,33,8,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,8,65,65,0,0,65,65,0,0,65,65,0,0,65,65,0,0,4,0,0,0,0,0,0,0,0,0,225,1,1,225,193,1,1,4,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,4,0,0,0,0,0,0,0,0,1,1,1,0,1,1,1,0,4,0,0,0,0,0,1,1,1,0,1,1,1,0,0,0,0,4,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,4,0,0,0,0,1,1,1,0,1,1,1,0,0,0,0,0,8,33,33,1,1,33,33,1,1,33,33,33,33,33,33,33,33,8,1,1,1,1,1,1,1,1,65,65,65,65,65,65,65,65,8,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65];
 const cells=[0,0,0,0,0,0,0,0,0,0,0,1,2,3,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,11,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,12,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,13,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,13,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,14,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,11,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,15,0,0,0,0,0,0,0,0,0,0,0,0,0,0,16,16,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,17,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,18,19,0,0,0,0,0,0,0,0,0,0,0,0,0,18,20,21,0,0,0,0,0,0,0,0,0,0,0,0,18,21,21,21,21,0,0,0,0,0,0,0,0,0,0,18,20,21,21,21,21,0,0,0,0,0,0,0,0,0,18,20,21,21,21,21,0,0,0,0,0,0,0,0,0,18,20,21,21,21,21,21,21,0,0,0,0,0,0,22,23,20,21,21,21,21,21,21,21,0,0,0,0,0,0,24,25,21,21,21,21,21,21,21,21,0,0,0,0,0,0,24,25,0,0,0,0,0,0,0,0,0,0,0,0,0,0,24,25,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,27,0,0,0,0,0,0,0,0,0,0,0,0,0,28,26,27,0,0,0,0,0,0,0,0,0,0,0,29,0,0,26,27,0,0,0,0,0,0,0,0,0,0,0,28,0,0,26,27,0,0,0,0,0,0,0,0,0,0,0,29,0,0,26,27,0,0,0,0,0,0,0,0,0,0,0,28,0,0,26,27,0,0,0,0,0,0,0,0,0,29,0,0,0,0,26,27,0,0,0,0,0,0,0,0,0,28,0,0,0,0,26,27,0,0,0,0,0,0,0,0,0,0,0,0,0,0,24,25,30,30,30,30,30,30,30,30,30,0,0,0,0,0,31,32,32,32,32,32,32,32,32,32,32,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,33,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,34,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,34,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,34,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,35,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,36,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,37,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,37,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,38,0,0,0,0,0,0,0,0,0,0,0,36,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,37,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,37,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,38,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,22,23,23,23,23,23,23,23,23,23,23,0,0,0,0,0,24,25,21,21,21,21,21,21,21,21,21,0,0,0,0,0,26,27,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,27,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,27,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,27,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,27,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,27,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,27,0,0,0,0,0,0,0,0,0,0,0,0,0,0,26,27,0,0,0,0,0,0,0,0,0,0,0,0,0,0,24,25,0,0,0,0,0,0,0,0,0,0,0,0,0,0,24,25,0,0,0,0,0,0,0,0,0,0,0,0,0,0,24,25,30,30,30,30,30,30,30,30,0,0,0,0,0,0,31,32,32,39,30,30,30,30,30,30,0,0,0,0,0,0,0,0,0,40,30,30,30,30,30,30,0,0,0,0,0,0,0,0,0,40,41,41,39,30,30,0,0,0,0,0,0,0,0,0,0,0,0,0,40,30,30,0,0,0,0,0,0,0,0,0,0,0,0,0,40,41,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,15,0,0,0,0,0,0,0,0,0,0,0,0,0,0,16,16,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,17,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,3,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
 let collisionErrors=0;for(let i=0;i<600;i++){const x=(i*47)%3200,y=(i*13)%256,sy=8+y-24+Math.floor((y-24)/2);const expected=x>=2768||y<24||y>=184?0:shapes[cells[(x&65520)+(sy>>4)]*17+1+(sy&12)+((x&12)>>2)]&1;if(call('level_solid',[x&255,x>>8,y])!==expected)collisionErrors++;}check('optimized collisions match original records',collisionErrors===0,collisionErrors);
 const shots=()=>Array.from({length:9},(_,i)=>Array.from({length:8},(_,k)=>r(0xc400+i*8+k))).filter(s=>s[0]);
 for(let weapon=0;weapon<5;weapon++){clear();w(0xc500,weapon);w(0xc018,255);call('game_weapons');const s=shots(),expected=[1,2,2,1,3][weapon];check('weapon '+weapon+' salvo',s.length===expected,s);call('game_weapons');check('weapon '+weapon+' held fire',shots().length===expected,shots());}
 clear();w(0xc505,1);w(0xc506,32);w(0xc507,146);w(0xc50a,2);call('game_weapons');check('P pickup',r(0xc505)===0&&r(0xc500)===3,[r(0xc505),r(0xc500)]);
 clear();w(0xc500,4);w(0xc009,1);w(0xc008,32);call('game_update');check('contact keeps weapon',r(0xc00d)===8&&r(0xc500)===4,[r(0xc00d),r(0xc500)]);
 w(0xc00e,0);w(0xc008,32);call('game_update');check('death loses weapon and life',r(0xc504)===2&&r(0xc500)===0&&r(0xc00d)===16,[r(0xc504),r(0xc500),r(0xc00d)]);
 clear();w(0xc504,1);call('game_lose_life');check('last life game over',r(0xc010)===2&&r(0xc504)===0,[r(0xc010),r(0xc504)]);
 clear();w(0xc011,5);call('game_stance');check('kneel',r(0xc501)===1,r(0xc501));w(0xc011,0);call('game_stance');w(0xc011,5);call('game_stance');check('prone',r(0xc501)===2,r(0xc501));
 clear();w(0xc011,1);call('game_update');check('first jump',r(0xc022)===1&&r(0xc003)===1,[r(0xc022),r(0xc003)]);w(0xc011,0);call('game_update');w(0xc011,1);call('game_update');check('double jump',r(0xc022)===2,r(0xc022));w(0xc011,0);call('game_update');w(0xc011,1);call('game_update');check('no third jump',r(0xc022)===2,r(0xc022));

 clear();w(0xc942,1);w(0xc500,4);w(0xc00d,1);w(0xc009,1);w(0xc008,32);call('game_update');check('trainer prevents contact energy and life loss',r(0xc00d)===16&&r(0xc504)===3&&r(0xc500)===4,[r(0xc00d),r(0xc504),r(0xc500)]);
 clear();w(0xc942,1);w(0xc00d,1);w(0xc013,1);w(0xc012,36);call('game_update');check('trainer prevents bullet energy loss',r(0xc00d)===16&&r(0xc504)===3,[r(0xc00d),r(0xc504)]);
 clear();call('level_init');w(0xc942,1);w(0xc500,4);w(0xc944,64);w(0xc945,0);w(0xc946,112);w(0xc947,125);w(0xc948,0);w(0xc949,1);w(0xc006,5);w(0xc001,154);w(0xc003,1);w(0xc002,4);call('level_physics');check('trainer pit returns to safe position with weapon and lives',r(0xc005)===64&&r(0xc006)===0&&r(0xc001)===125&&r(0xc500)===4&&r(0xc504)===3,[r(0xc005),r(0xc006),r(0xc001),r(0xc500),r(0xc504)]);
 clear();check('original floor at start',call('level_floor_at',[64,0])===157,call('level_floor_at',[64,0]));
 check('original pit at x1280',call('level_floor_at',[0,5])===192,call('level_floor_at',[0,5]));
 check('original rock collision',call('level_solid',[32,0,136])===1,call('level_solid',[32,0,136]));
 check('clear sky collision',call('level_solid',[32,0,80])===0,call('level_solid',[32,0,80]));
 call('level_init');w(0xc000,34);check('wall stops horizontal movement',call('level_can_move',[1])===0,call('level_can_move',[1]));
 clear();call('level_init');w(0xc005,0);w(0xc006,5);w(0xc011,0);for(let i=0;i<40&&r(0xc504)===3;i++)call('level_physics');
 check('pit costs life and rebuilds start',r(0xc504)===2&&r(0xc005)===0&&r(0xc006)===0&&r(0xc035)===0,[r(0xc504),r(0xc005),r(0xc006),r(0xc035)]);
 clear();w(0xc005,255);w(0xc006,3);w(0xc000,112);w(0xc011,3);call('game_update');check('camera passes old demo boundary',r(0xc006)===4&&r(0xc010)===0,[r(0xc005),r(0xc006),r(0xc010)]);

 clear();call('level_init');w(0xc001,24);w(0xc003,1);w(0xc002,249);w(0xc022,1);call('level_physics');check('jump can reach above old top limit',r(0xc001)===17,r(0xc001));
 clear();call('level_init');w(0xc005,192);w(0xc006,4);w(0xc000,112);w(0xc001,8);w(0xc003,1);w(0xc002,3);call('level_physics');check('land on round rock x1320',r(0xc001)===11&&r(0xc003)===0,[r(0xc001),r(0xc003)]);
 check('enemy stands above mountain, outside terrain',call('level_enemy_floor',[192,4,0])===94,call('level_enemy_floor',[192,4,0]));
 clear();call('level_init');w(0xc009,1);w(0xc008,80);w(0xc902,125);w(0xc400,1);w(0xc402,70);w(0xc403,135);w(0xc404,5);call('game_weapons');check('enemy hit enters smoke state',r(0xc009)===2&&r(0xc904)===12,[r(0xc009),r(0xc904)]);w(0xc00e,100);for(let i=0;i<13;i++)call('game_update');check('smoke expires',r(0xc009)===0,r(0xc009));

 clear();call('level_init');w(0xc005,2);w(0xc006,4);w(0xc000,112);w(0xc001,115);w(0xc011,3);w(0xc00e,255);let climb=[];for(let i=0;i<220;i++){w(0xc004,i);w(0xc009,0);call('game_update');if(i%20===0)climb.push([r(0xc005)+256*r(0xc006)+104,r(0xc001),r(0xc003)]);}check('walk up first slope to plateau',r(0xc005)+256*r(0xc006)+104>=1280,climb);


 clear();call('level_init');w(0xc005,46);w(0xc006,5);w(0xc000,112);w(0xc001,48);w(0xc00e,255);let journey=[],phase=0,jumpat=-1;
 const targets=[1580,1700,1778,1906];
 for(let i=0;i<1200&&phase<targets.length;i++){
  let x=r(0xc005)+256*r(0xc006)+104,air=r(0xc003),dir=x<targets[phase]?3:0;
  if(!air&&jumpat<0){dir=x<targets[phase]?2:1;jumpat=i;}
  else if(air&&i-jumpat===32)dir=x<targets[phase]?2:1;
  else if(!air&&jumpat>=0&&i-jumpat>2&&x>=targets[phase]){phase++;jumpat=-1;continue;}
  w(0xc011,dir);w(0xc004,i);w(0xc009,0);w(0xc00e,255);call('game_update');
  if(i%40===0)journey.push([x,r(0xc001),r(0xc003),r(0xc504)]);
  if(r(0xc504)<3)break;
 }
 check('cross rocks and first chasm without losing a life',phase===targets.length&&r(0xc504)===3,journey);

 clear();m.vdp.eval('commandProcessor.startCommand(0)');const vram=m.vdp.eval('vram');
 const pixel=(addr,x)=>x&1?vram[addr+(x>>1)]&15:vram[addr+(x>>1)]>>4;
 const expectedPixel=(x,y)=>x&1?raster[y*2048+(x>>1)]&15:raster[y*2048+(x>>1)]>>4;
 w(0xc080,232);w(0xc081,3);w(0xc03c,40);w(0xc03e,32);w(0xc037,24);w(0xc038,160);w(0xc007,0);call('level_copy_rect');let errors=0;
 for(let y=24;y<184;y++)for(let x=40;x<72;x++)if(pixel(y*128,x)!==expectedPixel(1000+x-40,y))errors++;
 check('SCREEN5 packed world copy across ROM banks',errors===0,errors);
 w(0xc080,233);w(0xc081,3);w(0xc03c,41);w(0xc03e,31);w(0xc037,24);w(0xc038,160);call('level_copy_rect');errors=0;
 for(let y=24;y<184;y++)for(let x=40;x<72;x++)if(pixel(y*128,x)!==expectedPixel(1000+x-40,y))errors++;
 check('odd dirty rectangles restore both nibble edges',errors===0,errors);
 clear();w(0xc03c,8);w(0xc03e,240);w(0xc037,24);w(0xc038,160);call('level_copy_rect');vram.fill(51,32768,65536);w(0xc0d4,8);w(0xc0d5,248);for(let x=2;x<=16;x+=2){w(0xc005,x);call('scroll_pipeline');}
 errors=0;for(let y=24;y<184;y++)for(let x=8;x<248;x++)if(pixel(32768+y*128,x)!==expectedPixel(16+x-8,y))errors++;
 check('eight bounded jobs produce exact horizontal page',errors===0&&r(0xc007)===1&&r(0xc088)===16,{errors,page:r(0xc007),origin:r(0xc088)});
 errors=0;for(let y=0;y<256;y++)if(y<24||y>=184)for(let x=8;x<248;x++)if(pixel(32768+y*128,x))errors++;
 check('circular sky rows are cleared without copying actor ghosts',errors===0,errors);
 const before=Array.from(vram.slice(0,65536));let steps=[],last=0;
 for(let y=2;y<=88;y+=2){w(0xc941,y);call('scroll_pipeline');steps.push(r(0xc0a5)-last);last=r(0xc0a5);}
 for(let y=86;y>=0;y-=2){w(0xc941,y);call('scroll_pipeline');steps.push(r(0xc0a5)-last);last=r(0xc0a5);}
 check('vertical hardware tracking advances at bipixel',steps.every(v=>Math.abs(v)===2),[...new Set(steps)]);
 check('vertical scroll performs no background writes',before.every((v,i)=>v===vram[i]),true);

 clear();w(0xc035,1);w(0xc000,112);w(0xc001,128);w(0xc011,3);let cadence=[];
 for(let frame=0;frame<16;frame++){w(0xc004,1);w(0xc009,0);call('game_update');call('scroll_pipeline');cadence.push(r(0xc005)+256*r(0xc006));}
 check('horizontal motion never stalls at page boundaries',cadence.every((v,i)=>v===i+1),cadence);
 // Test the bitmap actor crossing physical VRAM row 255 on the same page.
 for(let y=0;y<32;y++){vram.fill(51,((250+y)&255)*128+52,((250+y)&255)*128+60);vram.fill(119,32768+y*128+52,32768+y*128+60);}
 const command=[0,0,8,2,104,0,250,0,16,0,32,0,0,0,152];command.forEach((v,i)=>w(0xc100+i,v));call('docmd');call('waitvdp');errors=0;
 for(let y=0;y<32;y++)for(let x=0;x<16;x++){const source=pixel((520+y)*128,x),actual=pixel(((250+y)&255)*128,104+x);if(actual!==(source||3))errors++;}
 check('bitmap actor wraps vertically within its display page',errors===0,errors);
 check('wrapped actor never overwrites the next page',Array.from({length:32},(_,y)=>vram[32768+y*128+52]).every(v=>v===119),true);

 let hudInk=0;for(let y=0;y<24;y++)for(let x=0;x<128;x++)hudInk+=!!vram[0x18000+y*128+x];for(let y=184;y<192;y++)for(let x=0;x<128;x++)hudInk+=!!vram[0x18000+y*128+x];check('raster HUD page stays black behind the hardware text',hudInk===0,hudInk);
 // Compare all hardware sprite planes against the packed atlas pixels.
 clear();w(0xc000,112);w(0xc001,125);let poseErrors=0;
 const specs=Array.from({length:8},(_,i)=>[i*16,8,false]).concat([[192,8,false],[208,8,false],[224,8,false],[240,8,false],[128,40,true],[160,40,true]]);
 for(let pose=0;pose<14;pose++){
  w(0xc014,pose>=4&&pose<8||pose===9||pose===11||pose===13?128:0);w(0xc501,pose>=12?2:pose>=10?1:0);w(0xc538,pose===8||pose===9?1:0);w(0xc016,pose<8?1:0);w(0xc004,(pose&3)*4);call('player_sprite_update');call('player_sprite_upload');
  const [sx,sy,wide]=specs[pose];for(let cell=0;cell<2;cell++)for(let y=0;y<16;y++)for(let x=0;x<16;x++){
   let color=0;for(let plane=0;plane<4;plane++)if(vram[0x1b160+(cell*4+plane)*32+(x<8?0:16)+y]&(1<<(7-(x&7))))color|=1<<plane;
   let expected=pixel((512+sy+y+(wide?0:cell*16))*128,sx+x+(wide?cell*16:0));if(color!==expected)poseErrors++;
  }
 }
 check('all fourteen hardware player poses reproduce every palette index',poseErrors===0,{pixels:7168,errors:poseErrors});
 w(0xc014,0);w(0xc501,0);w(0xc538,0);w(0xc016,0);let endMarkers=0;for(let y=-64;y<=155;y++){w(0xc001,y);call('player_sprite_update');for(let i=0;i<8;i++)if(r(0xcb00+i*4)===216)endMarkers++;}
 check('hardware player never emits the reserved sprite end marker',endMarkers===0,endMarkers);
 // Rebuild a nonzero trainer checkpoint into both pages.
 clear();w(0xc005,64);w(0xc035,0);call('scroll_init');errors=0;
 for(let page=0;page<2;page++)for(let y=24;y<184;y++)for(let x=8;x<248;x++)if(pixel(page*32768+y*128,x)!==expectedPixel(64+x-8,y))errors++;
 check('trainer checkpoint rebuilds the actual world position',errors===0&&r(0xc088)===64,{errors,origin:r(0xc088)});
 clear();w(0xc940,165);w(0xc942,1);w(0xc005,192);w(0xc006,4);w(0xc000,112);w(0xc001,11);w(0xc941,64);call('scroll_init');call('render');
 cpu.eval('PC='+symbols.main+';SP=0xf380;IFF1=1;INT=255;ackINT=false;prefix=0;T=-1;W=0');m.cpuPause(false,false,true);
 return results;
},{symbols,expected,incoming,raster:Array.from(raster)});
await p.waitForTimeout(300);await p.screenshot({path:path.join(root,'qa-fast-mountain.png')});
fs.writeFileSync(path.join(root,'qa-mechanics.json'),JSON.stringify(checks,null,2));console.log(checks.length+' C mechanics checks passed');
}finally{await browser.close();server.close();}})().catch(e=>{console.error(e);process.exitCode=1;server.close();});

