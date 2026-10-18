// C runner: prepare in W0; public only by default. Owner requires explicit A/T0 record.
import {readFile,writeFile} from 'node:fs/promises';
import {spawn,execFileSync} from 'node:child_process';
import {resolve,dirname,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const mobile=resolve(dirname(fileURLToPath(import.meta.url)),'..');process.chdir(mobile);
try {
const c=JSON.parse(await readFile('../xland-server/.local/p3-context.json','utf8'));
const mode=process.argv[2]??'public';
if(!['public','owner'].includes(mode))throw Error('Usage: node tool/p3-integration-runner.mjs public | owner');
const adb='C:/Users/Admin/AppData/Local/Android/Sdk/platform-tools/adb.exe',serial='emulator-5580',pkg='vn.xland.xland_mobile.cproof';
const call=(args,input)=>execFileSync(adb,['-s',serial,...args],{input,windowsHide:true,timeout:30000,maxBuffer:1024*1024});
if(call(['shell','getprop','ro.boot.qemu.avd_name']).toString().trim()!=='Medium_Phone_API_37.0')throw Error('Unexpected native target');
const flags=[`--dart-define=XLAND_API_BASE_URL=http://10.0.2.2:${c.apiPort}/api/v1`,`--dart-define=XLAND_DEMO_MEDIA_BASE_URL=http://10.0.2.2:${c.mediaPort}`];
let reviewHash=null;
if(mode==='owner'){
 // This record is only created after A actually grants T0. Presence of the word
 // "Pass" in an old review is never interpreted as permission.
 const auth=JSON.parse(await readFile('../xland-server/.local/p3-t0-authorization.json','utf8'));
 const review=resolve(auth.reviewPath),allowed=resolve('../brain/logs/agent-a')+sep;
 if(auth.authorized!==true||!review.startsWith(allowed))throw Error('W1 blocked: A/T0 authorization required');
 const runtime=JSON.parse(await readFile('../xland-server/.local/p3-preview.json','utf8'));
 if(auth.sourceHash!==c.sourceHash||auth.bundleHash!==c.bundleHash||runtime.sourceHash!==c.sourceHash||runtime.bundleHash!==c.bundleHash||auth.backendSourceHash!==runtime.backendSourceHash)throw Error('T0 snapshot/runtime mismatch: do not run W1 against an old bundle');
 reviewHash=createHash('sha256').update(await readFile(review)).digest('hex');
 if(reviewHash!==auth.reviewSha256)throw Error('T0 review changed: revalidate authorization');
 const input=JSON.parse(await readFile('../xland-server/.local/p3-w1-input.json','utf8'));
 if(input.t0Authorized!==true||input.t0ReviewSha256!==reviewHash||!input.runLabel?.startsWith('c-p3-'))throw Error('Private account/fixture context is not authorized for this review');
 for(const key of ['usernameA','passwordA','usernameB','passwordB','slotId','eventId','propertyId','videoId','financePropertyId','contactPhone'])if(typeof input[key]!=='string'||!input[key])throw Error('Incomplete private W1 fixture');
 if(input.usernameA===input.usernameB)throw Error('Distinct own A/B accounts required');
 input.apiBaseUrl=`http://10.0.2.2:${c.apiPort}/api/v1`;
 call(['shell',`run-as ${pkg} sh -c 'mkdir -p files; cat > files/p3-w1-input.json'`],Buffer.from(JSON.stringify(input)));
 flags.push('--dart-define=XLAND_P3_AFTER_T0=true');
}
const logPath=resolve(c.evidence,`integration-${mode}.log`);
const args=[resolve(c.sdk,'bin/cache/flutter_tools.snapshot'),'test',`integration_test/p3_${mode==='owner'?'owner':'public'}_test.dart`,'--no-pub','-d',serial,...flags];
const env={...process.env,FLUTTER_ROOT:c.sdk,ORG_GRADLE_PROJECT_xlandNativeProof:'true'};
for(const key of Object.keys(env))if(/DATABASE|PASSWORD|TOKEN|CURSOR_SECRET|SEPAY/i.test(key))delete env[key];
const child=spawn(resolve(c.sdk,'bin/cache/dart-sdk/bin/dart.exe'),args,{cwd:c.sandbox,env,windowsHide:true,stdio:['ignore','pipe','pipe']});
let output='';child.stdout.on('data',b=>{output+=b;});child.stderr.on('data',b=>{output+=b;});
const timer=setTimeout(()=>child.kill(),10*60*1000);
const exit=await new Promise((ok,fail)=>{child.once('error',fail);child.once('exit',code=>ok(code??1));});clearTimeout(timer);
// Credentials/tokens are never printed by the harness; no request headers/body logging.
await writeFile(logPath,output);
const apkBytes=await readFile(resolve(c.sandbox,'build/app/outputs/flutter-apk/app-debug.apk'));
const testArtifact={sha256:createHash('sha256').update(apkBytes).digest('hex'),bytes:apkBytes.length,target:`integration_test/p3_${mode==='owner'?'owner':'public'}_test.dart`};
await writeFile(resolve(c.evidence,`integration-${mode}-exit.json`),JSON.stringify({mode,exit,sourceHash:c.sourceHash,bundleHash:c.bundleHash,testArtifact,target:serial,reviewHash,privateContext:mode==='owner',scope:'C real repositories/transport on native; not complete B UI E01..E10 acceptance'},null,2));
if(mode==='owner')call(['shell',`run-as ${pkg} rm -f files/p3-w1-input.json`]);
console.log(JSON.stringify({event:'p3_integration_complete',mode,exit,evidence:logPath}));process.exitCode=exit;
}catch{console.error(JSON.stringify({event:'p3_integration_refused_or_failed',reason:'Check target, A/T0 authorization and private context; values redacted; no implicit permission'}));process.exitCode=1;}
