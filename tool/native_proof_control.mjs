import {readFile,writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import {resolve} from 'node:path';
const adb='C:/Users/Admin/AppData/Local/Android/Sdk/platform-tools/adb.exe',serial='emulator-5580',pkg='vn.xland.xland_mobile.cproof';
const run=JSON.parse(await readFile('../xland-server/.local/closeout02-run.json','utf8'));
let artifact=null;try{artifact=JSON.parse(await readFile('.local/native-installed-artifact.json','utf8'));}catch{/* earlier proof artifact is mapped by install order in final manifest */}
const call=(args,input)=>execFileSync(adb,['-s',serial,...args],{input,windowsHide:true,timeout:30000,maxBuffer:16*1024*1024});
if(call(['shell','getprop','ro.boot.qemu.avd_name']).toString().trim()!=='Medium_Phone_API_37.0')throw Error('Preserve unrecognized device');
const [mode,reason]=process.argv.slice(2);
if(mode==='capture'){
 await new Promise(r=>setTimeout(r,1800));
 const current=JSON.parse(call(['shell',`run-as ${pkg} cat files/c02-input.json`]).toString());
 const records=call(['logcat','-d','-s','flutter:I']).toString().split('\n').filter(l=>l.includes('XLAND_C02 ')).flatMap(l=>{try{const r=JSON.parse(l.slice(l.indexOf('XLAND_C02 ')+10));return r.runKey===current.runKey?[r]:[];}catch{return [];}});
 const label=(reason??'capture').replace(/[^a-z_-]/g,'');const stamp=Date.now();
 await writeFile(resolve(run.evidence,'native-feed-'+label+'-'+stamp+'.json'),JSON.stringify({timestamp:new Date().toISOString(),mode:'actual_feed_capture',label,device:serial,records},null,2));
 await writeFile(resolve(run.evidence,'native-feed-'+label+'-'+stamp+'.png'),call(['exec-out','screencap','-p']));
 console.log(JSON.stringify({event:'native_feed_capture',label,records:records.slice(-3)}));process.exit(0);
}
if(!['write','restart_read_delete','login','read_valid','logout','read_401','unavailable','feed','player'].includes(mode))throw Error('Unknown C proof mode');
const input=JSON.parse(await readFile('../xland-server/.local/native-auth-input.json','utf8'));
const runKey=randomUUID();const payload={...input,mode,reason:reason??null,runKey};
call(['shell','am','force-stop',pkg]);
call(['shell',`run-as ${pkg} sh -c 'mkdir -p files; cat > files/c02-input.json'`],Buffer.from(JSON.stringify(payload)));
call(['shell','am','start','-W','-n',pkg+'/vn.xland.xland_mobile.MainActivity']);
let records=[];const started=Date.now();
while(Date.now()-started<45000){
 await new Promise(r=>setTimeout(r,500));
 records=call(['logcat','-d','-s','flutter:I']).toString().split('\n').filter(line=>line.includes('XLAND_C02 ')).flatMap(line=>{try{const value=JSON.parse(line.slice(line.indexOf('XLAND_C02 ')+10));return value.runKey===runKey?[value]:[];}catch{return [];}});
 if(mode==='feed'?(['expired','unavailable','offline'].includes(reason)?Date.now()-started>=18000&&records.length>0:records.some(r=>r.players?.some(p=>p.initialized))):mode==='player'?records.filter(r=>r.mode==='player_source_error').length===2:records.length)break;
}
const path=resolve(run.evidence,'native-'+mode+'-'+(reason??'normal')+'-'+Date.now()+'.json');
await writeFile(path,JSON.stringify({timestamp:new Date().toISOString(),device:serial,package:pkg,artifact,mode,reason:reason??null,records,source:'actual Android plugins; isolated local test API; no mocked channels'},null,2));
if(mode==='feed')await writeFile(resolve(run.evidence,'native-feed-'+Date.now()+'.png'),call(['exec-out','screencap','-p']));
console.log(JSON.stringify({event:'native_proof',mode,reason:reason??null,records:mode==='feed'?records.slice(-3):records,seconds:Math.round((Date.now()-started)/1000)}));
if(!records.length||records.some(r=>r.mode==='failed'))process.exitCode=1;
