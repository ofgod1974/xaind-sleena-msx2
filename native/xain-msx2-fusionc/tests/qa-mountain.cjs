const fs=require('fs'),http=require('http'),path=require('path');
const {chromium}=require('C:/Users/Andrea/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve('outputs/xain-msx2-fusionc');
const server=http.createServer((req,res)=>{const p=path.resolve(root,'.'+(req.url.split('?')[0]==='/'?'/index.html':req.url.split('?')[0]));if(!p.startsWith(root+path.sep)){res.writeHead(403);return res.end();}fs.readFile(p,(e,b)=>{if(e){res.writeHead(404);return res.end();}res.setHeader('Content-Type',p.endsWith('.html')?'text/html':p.endsWith('.js')?'application/javascript':'application/octet-stream');res.end(b);});});
(async()=>{await new Promise(r=>server.listen(8766,'127.0.0.1',r));const browser=await chromium.launch({executablePath:path.resolve('work/browsers/chromium_headless_shell-1234/chrome-headless-shell-win64/chrome-headless-shell.exe'),headless:true,args:['--autoplay-policy=no-user-gesture-required','--allow-file-access-from-files']});
try{const p=await browser.newPage();p.on('pageerror',e=>console.error(e));
const offline=path.resolve('work/qa-fusion-offline.html');fs.writeFileSync(offline,fs.readFileSync(path.join(root,'index.html'),'utf8').replace(/<script[\s\S]*?<\/script>/g,''));await p.goto(require('url').pathToFileURL(offline).href);
await p.addScriptTag({content:fs.readFileSync(path.join(root,'wmsx.js'),'utf8')});
await p.evaluate(rom=>{Object.assign(WMSX,{MACHINE:'MSX2A',CARTRIDGE1_URL:'data:application/octet-stream;base64,'+rom,CARTRIDGE1_FORMAT:'ASCII16',AUTO_START:false,SCREEN_FULLSCREEN_MODE:0,SCREEN_FILTER_MODE:0,SCREEN_CRT_MODE:0});WMSX.start();},fs.readFileSync(path.join(root,'xain-msx2.rom')).toString('base64'));
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
const map=fs.readFileSync(path.join(root,'build/core.map'),'utf8');
const symbols={};for(const name of ['game_weapons','game_update','game_lose_life','game_stance','level_init','level_physics','level_can_move','level_solid','level_floor_at','level_enemy_floor']){const m=map.match(new RegExp('([0-9A-F]{8})  _'+name+'\\s'));if(!m)throw Error('Missing '+name);symbols[name]=parseInt(m[1],16);}
const asm=fs.readFileSync(path.join(root,'symbols.txt'),'utf8');for(const name of ['level_copy_rect','level_incoming_column'])symbols[name]=parseInt(asm.match(new RegExp('^'+name+': EQU 0x([0-9A-F]+)','mi'))[1],16);
const raster=fs.readFileSync(path.join(root,'src/levels/cleemalt.pixels.bin'));
const expected=[];for(let y=24;y<184;y++)for(let x=1000;x<1032;x++)expected.push(raster[y*4096+x]);
const incoming=[];for(let y=24;y<184;y++)for(let x=464;x<480;x++)incoming.push(raster[y*4096+x]);
const checks=await p.evaluate(({symbols,expected,incoming})=>{
 const m=WMSX.room.machine; m.cpuPause(true,false,true);
 const bus=m.eval('bus'),cpu=m.cpu,results=[];cpu.setZ80BUSRQ(false);
 const r=a=>bus.read(a),w=(a,v)=>bus.write(a,v&255);
 function clear(){for(let a=0xc900;a<0xc960;++a)w(a,0);w(0xc902,128);w(0xc903,141);for(let a=0xc000;a<0xc080;++a)w(a,0);for(let a=0xc400;a<0xc740;++a)w(a,0);w(0xc000,32);w(0xc001,128);w(0xc00d,16);w(0xc504,3);w(0xc50a,0xa7);}
 function call(name,args=[]){w(0x7000,3);w(0xc33d,3);args.forEach((v,i)=>w(0xef00+i,v));w(0xc9f0,0xc3);w(0xc9f1,0xf0);w(0xc9f2,0xc9);w(0xeefe,0xf0);w(0xeeff,0xc9);cpu.eval('PC='+symbols[name]+';SP=0xeefe;IFF1=0;INT=255;ackINT=false;prefix=0;T=-1;W=0');for(let i=0;i<10000;i++){cpu.busClockPulses(100);const pc=cpu.eval('PC');if(pc>=0xc9f0&&pc<=0xc9f2)return cpu.eval('HL&255');}throw Error('C routine did not return: '+name);}
 function check(name,ok,actual){results.push({name,pass:!!ok,actual});if(!ok)throw Error(name+': '+JSON.stringify(actual));}
 const shots=()=>Array.from({length:9},(_,i)=>Array.from({length:8},(_,k)=>r(0xc400+i*8+k))).filter(s=>s[0]);
 for(let weapon=0;weapon<5;weapon++){clear();w(0xc500,weapon);w(0xc018,255);call('game_weapons');const s=shots(),expected=[1,2,2,1,3][weapon];check('weapon '+weapon+' salvo',s.length===expected,s);call('game_weapons');check('weapon '+weapon+' held fire',shots().length===expected,shots());}
 clear();w(0xc505,1);w(0xc506,32);w(0xc507,146);w(0xc50a,2);call('game_weapons');check('P pickup',r(0xc505)===0&&r(0xc500)===3,[r(0xc505),r(0xc500)]);
 clear();w(0xc500,4);w(0xc009,1);w(0xc008,32);call('game_update');check('contact keeps weapon',r(0xc00d)===8&&r(0xc500)===4,[r(0xc00d),r(0xc500)]);
 w(0xc00e,0);w(0xc008,32);call('game_update');check('death loses weapon and life',r(0xc504)===2&&r(0xc500)===0&&r(0xc00d)===16,[r(0xc504),r(0xc500),r(0xc00d)]);
 clear();w(0xc504,1);call('game_lose_life');check('last life game over',r(0xc010)===2&&r(0xc504)===0,[r(0xc010),r(0xc504)]);
 clear();w(0xc011,5);call('game_stance');check('kneel',r(0xc501)===1,r(0xc501));w(0xc011,0);call('game_stance');w(0xc011,5);call('game_stance');check('prone',r(0xc501)===2,r(0xc501));
 clear();w(0xc011,1);call('game_update');check('first jump',r(0xc022)===1&&r(0xc003)===1,[r(0xc022),r(0xc003)]);w(0xc011,0);call('game_update');w(0xc011,1);call('game_update');check('double jump',r(0xc022)===2,r(0xc022));w(0xc011,0);call('game_update');w(0xc011,1);call('game_update');check('no third jump',r(0xc022)===2,r(0xc022));
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
 m.vdp.eval('commandProcessor.startCommand(0)');
 clear();w(0xc080,232);w(0xc081,3);w(0xc03c,40);w(0xc03e,32);w(0xc037,24);w(0xc038,160);w(0xc007,0);call('level_copy_rect');
 const vram=m.vdp.eval('vram');let errors=0,i=0;for(let y=24;y<184;y++)for(let x=40;x<72;x++)if(vram[y*256+x]!==expected[i++])errors++;
 check('world raster VRAM copy across 40 ROM banks',errors===0,{pixels:i,errors});
 w(0xc005,238);w(0xc006,0);w(0xc007,0);call('level_incoming_column');errors=0;i=0;for(let y=24;y<184;y++)for(let x=232;x<248;x++)if(vram[65536+y*256+x]!==incoming[i++])errors++;
 check('incoming column on hidden page',errors===0&&r(0xc007)===0,{pixels:i,errors,back:r(0xc007)});
 return results;
},{symbols,expected,incoming});
fs.writeFileSync(path.join(root,'qa-mechanics.json'),JSON.stringify(checks,null,2));console.log(checks.length+' C mechanics checks passed');
}finally{await browser.close();server.close();}})().catch(e=>{console.error(e);process.exitCode=1;server.close();});

