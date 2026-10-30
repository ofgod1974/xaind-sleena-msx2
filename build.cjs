/* Reproducible mixed C/assembly ROM build. No HTML is needed to compile. */
const fs=require('fs'),path=require('path'),cp=require('child_process');
const root=__dirname,src=path.join(root,'src'),out=path.join(root,'build');
const sdcc=process.env.SDCC||process.argv[2];
const sjasm=process.env.SJASMPLUS||process.argv[3];
if(!sdcc||!sjasm)throw Error('Usage: node build.cjs <sdcc.exe> <sjasmplus.exe>');
process.env.PATH=path.dirname(sdcc)+path.delimiter+process.env.PATH;
fs.mkdirSync(out,{recursive:true});
function run(exe,args,cwd=out){const r=cp.spawnSync(exe,args,{cwd,encoding:'utf8'});if(r.stdout)process.stdout.write(r.stdout);if(r.stderr)process.stderr.write(r.stderr);if(r.status!==0)throw Error(exe+' failed: '+r.status);}
function assemble(){run(sjasm,['--raw=../xain-msx2.rom','--sym=../symbols.txt','game.asm'],src);}
assemble();
const sym=fs.readFileSync(path.join(root,'symbols.txt'),'utf8');
const address=name=>{const m=sym.match(new RegExp('^'+name+': EQU 0x([0-9A-Fa-f]+)','m'));if(!m)throw Error(name);return '0x'+m[1];};
const bridge=Object.entries({engine_sfx:'c_sfx'}).map(([c,a])=>'.globl _'+c+'\n_'+c+' = '+address(a)).join('\n');
fs.writeFileSync(path.join(out,'bridge.s'),'.module bridge\n'+bridge+'\n');
const bin=path.dirname(sdcc),as=path.join(bin,'sdasz80.exe');
run(as,['-plosgff','entry.rel',path.join(src,'c/entry.s')]);
run(as,['-plosgff','bridge.rel','bridge.s']);
for(const [name,file] of [['game','src/c/game.c'],['weapons','src/c/weapons.c'],['joystickread','third_party/fusion-c/joystickread.c'],['triggerread','third_party/fusion-c/triggerread.c']]){
 run(sdcc,['-mz80','--sdcccall','0','--no-std-crt0','--nostdlib','--no-peep','--opt-code-speed','-c',path.join(root,file),'-o',name+'.rel']);
}
run(sdcc,['-mz80','--sdcccall','0','--no-std-crt0','--nostdlib','--code-loc','0x8000','--data-loc','0xc920','entry.rel','game.rel','weapons.rel','joystickread.rel','triggerread.rel','bridge.rel','-o','core.ihx']);
const mapText=fs.readFileSync(path.join(out,'core.map'),'utf8');
for(const section of ['DATA','INITIALIZED','INITIALIZER','GSINIT']) {
 const m=mapText.match(new RegExp('([0-9A-F]{8})\\s+l__'+section+'\\s'));
 if(m && parseInt(m[1],16)!==0)throw Error('C runtime initialization required for '+section);
}
const image=Buffer.alloc(0x4000,0xff);let max=0;
for(const line of fs.readFileSync(path.join(out,'core.ihx'),'utf8').trim().split(/\r?\n/)){
 const b=Buffer.from(line.slice(1),'hex');if((b.reduce((a,v)=>a+v,0)&255)!==0)throw Error('HEX checksum');
 if(b[3]!==0)continue;
 const a=b.readUInt16BE(1)-0x8000;if(a<0||a+b[0]>0x4000)throw Error('C code outside bank 3');
 b.copy(image,a,4,4+b[0]);max=Math.max(max,a+b[0]);
}
fs.writeFileSync(path.join(src,'c/core.bin'),image.subarray(0,max));
assemble();
fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({compiler:cp.spawnSync(sdcc,['-v'],{encoding:'utf8'}).stdout.trim(),codeBank:3,codeAddress:32768,codeBytes:max,romBytes:fs.statSync(path.join(root,'xain-msx2.rom')).size},null,2));
console.log('Fusion-C ROM built; C code:',max,'bytes');
