const fs=require('fs'),http=require('http'),path=require('path');
const {chromium}=require('playwright');
const root=path.resolve(__dirname,'..');
const server=http.createServer((req,res)=>{const p=path.resolve(root,'.'+(req.url.split('?')[0]==='/'?'/index.html':req.url.split('?')[0]));if(!p.startsWith(root+path.sep)){res.writeHead(403);return res.end();}fs.readFile(p,(e,b)=>{if(e){res.writeHead(404);return res.end();}res.setHeader('Content-Type',p.endsWith('.html')?'text/html':p.endsWith('.js')?'application/javascript':'application/octet-stream');res.end(b);});});
(async()=>{await new Promise(r=>server.listen(8766,'127.0.0.1',r));const browser=await chromium.launch({executablePath:process.env.BROWSER_EXECUTABLE || undefined,headless:true,args:['--autoplay-policy=no-user-gesture-required']});
try{const p=await browser.newPage();p.on('pageerror',e=>console.error(e));await p.goto('http://127.0.0.1:8766');await p.waitForFunction(()=>typeof WMSX!=='undefined'&&WMSX.room?.machine?.bus,null,{timeout:30000});
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
const symbols={};for(const name of ['game_weapons','game_update','game_lose_life','game_stance']){const m=map.match(new RegExp('([0-9A-F]{8})  _'+name+'\\s'));if(!m)throw Error('Missing '+name);symbols[name]=parseInt(m[1],16);}
const checks=await p.evaluate(symbols=>{
 const m=WMSX.room.machine; m.cpuPause(true,false,true);
 const bus=m.eval('bus'),cpu=m.cpu,results=[];cpu.setZ80BUSRQ(false);
 const r=a=>bus.read(a),w=(a,v)=>bus.write(a,v&255);
 function clear(){for(let a=0xc000;a<0xc080;++a)w(a,0);for(let a=0xc400;a<0xc740;++a)w(a,0);w(0xc000,32);w(0xc001,128);w(0xc00d,16);w(0xc504,3);w(0xc50a,0xa7);}
 function call(name){w(0x7000,3);w(0xc33d,3);w(0xc9f0,0xc3);w(0xc9f1,0xf0);w(0xc9f2,0xc9);w(0xeefe,0xf0);w(0xeeff,0xc9);cpu.eval('PC='+symbols[name]+';SP=0xeefe;IFF1=0;ackINT=false;prefix=0;T=-1;W=0');for(let i=0;i<3000;i++){cpu.busClockPulses(100);const pc=cpu.eval('PC');if(pc>=0xc9f0&&pc<=0xc9f2)return;}throw Error('C routine did not return: '+name);}
 function check(name,ok,actual){results.push({name,pass:!!ok,actual});if(!ok)throw Error(name+': '+JSON.stringify(actual));}
 const shots=()=>Array.from({length:9},(_,i)=>Array.from({length:8},(_,k)=>r(0xc400+i*8+k))).filter(s=>s[0]);
 for(let weapon=0;weapon<5;weapon++){clear();w(0xc500,weapon);w(0xc018,255);call('game_weapons');const s=shots(),expected=[1,2,2,1,3][weapon];check('weapon '+weapon+' salvo',s.length===expected,s);call('game_weapons');check('weapon '+weapon+' held fire',shots().length===expected,shots());}
 clear();w(0xc505,1);w(0xc506,32);w(0xc507,146);w(0xc50a,2);call('game_weapons');check('P pickup',r(0xc505)===0&&r(0xc500)===3,[r(0xc505),r(0xc500)]);
 clear();w(0xc500,4);w(0xc009,1);w(0xc008,32);call('game_update');check('contact keeps weapon',r(0xc00d)===8&&r(0xc500)===4,[r(0xc00d),r(0xc500)]);
 w(0xc00e,0);w(0xc008,32);call('game_update');check('death loses weapon and life',r(0xc504)===2&&r(0xc500)===0&&r(0xc00d)===16,[r(0xc504),r(0xc500),r(0xc00d)]);
 clear();w(0xc504,1);call('game_lose_life');check('last life game over',r(0xc010)===2&&r(0xc504)===0,[r(0xc010),r(0xc504)]);
 clear();w(0xc011,5);call('game_stance');check('kneel',r(0xc501)===1,r(0xc501));w(0xc011,0);call('game_stance');w(0xc011,5);call('game_stance');check('prone',r(0xc501)===2,r(0xc501));
 clear();w(0xc011,1);call('game_update');check('first jump',r(0xc022)===1&&r(0xc003)===1,[r(0xc022),r(0xc003)]);w(0xc011,0);call('game_update');w(0xc011,1);call('game_update');check('double jump',r(0xc022)===2,r(0xc022));w(0xc011,0);call('game_update');w(0xc011,1);call('game_update');check('no third jump',r(0xc022)===2,r(0xc022));
 return results;
},symbols);
fs.writeFileSync(path.join(root,'qa-mechanics.json'),JSON.stringify(checks,null,2));console.log(checks.length+' C mechanics checks passed');
}finally{await browser.close();server.close();}})().catch(e=>{console.error(e);process.exitCode=1;server.close();});
