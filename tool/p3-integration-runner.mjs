import {readFile,writeFile,mkdir,copyFile} from 'node:fs/promises';
import {spawn,execFileSync} from 'node:child_process';
import {resolve,dirname,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
process.chdir(resolve(dirname(fileURLToPath(import.meta.url)),'..'));
const hash=b=>createHash('sha256').update(b).digest('hex');
try{
 const c=JSON.parse(await readFile('../xland-server/.local/p3-context.json','utf8'));
 const mode=process.argv[2]??'public',isOwner=mode!=='public';
 if(!['public','owner','owner-a','owner-b','ui-booking','report-journey'].includes(mode))throw Error('MODE');
 const reportJourney=mode==='report-journey';
 const adb='C:/Users/Admin/AppData/Local/Android/Sdk/platform-tools/adb.exe',serial='emulator-5580',pkg='vn.xland.xland_mobile.cproof';
 const call=(args,input)=>execFileSync(adb,['-s',serial,...args],{input,windowsHide:true,stdio:['pipe','pipe','pipe'],timeout:10000,maxBuffer:16*1024*1024});
 if(call(['shell','getprop','ro.boot.qemu.avd_name']).toString().trim()!=='Medium_Phone_API_37.0')throw Error('TARGET');
 const testFile=reportJourney?'p3_report_journey_test.dart':mode==='ui-booking'?'p3_ui_booking_test.dart':isOwner?'p3_owner_test.dart':'p3_public_test.dart';
 const flags=[`--dart-define=XLAND_API_BASE_URL=http://10.0.2.2:${c.apiPort}/api/v1`,`--dart-define=XLAND_DEMO_MEDIA_BASE_URL=http://10.0.2.2:${c.mediaPort}`];
 let reviewHash=null,input=null,redactions=[];
 if(isOwner){
  const auth=JSON.parse(await readFile(reportJourney?'../xland-server/.local/p3-report-authorization.json':'../xland-server/.local/p3-t0-authorization.json','utf8'));
  const review=resolve(auth.reviewPath),runtime=JSON.parse(await readFile('../xland-server/.local/p3-preview.json','utf8'));
  if(auth.authorized!==true||!review.startsWith(resolve('../brain/logs/agent-a')+sep))throw Error('T0');
  if(auth.sourceHash!==c.sourceHash||auth.bundleHash!==c.bundleHash||runtime.sourceHash!==c.sourceHash||runtime.bundleHash!==c.bundleHash||auth.backendSourceHash!==runtime.backendSourceHash)throw Error('SNAPSHOT');
  reviewHash=hash(await readFile(review));if(reviewHash!==auth.reviewSha256)throw Error('REVIEW');
  input=JSON.parse(await readFile(reportJourney?'../xland-server/.local/p3-report-input.json':'../xland-server/.local/p3-w1-input.json','utf8'));
  if(input.t0Authorized!==true||input.t0ReviewSha256!==reviewHash||!input.runLabel?.startsWith('c-p3-'))throw Error('INPUT');
  for(const key of ['usernameA','passwordA','usernameB','passwordB','slotId','eventId','propertyId','videoId','financePropertyId','contactPhone'])if(typeof input[key]!=='string'||!input[key])throw Error('FIXTURE');
  if(input.usernameA===input.usernameB)throw Error('OWNERS');
  redactions=[input.usernameA,input.passwordA,input.usernameB,input.passwordB,input.contactPhone,input.contactPhone.startsWith('0')?'+84'+input.contactPhone.slice(1):input.contactPhone];
  input.stage=mode;input.apiBaseUrl=`http://10.0.2.2:${c.apiPort}/api/v1`;
  flags.push('--dart-define=XLAND_P3_AFTER_T0=true');
 }
 const args=[resolve(c.sdk,'bin/cache/flutter_tools.snapshot'),'test',`integration_test/${testFile}`,'--no-pub','-d',serial,...flags];
 const selectedCase=process.argv[3];
 if(selectedCase!==undefined&&!(mode==='owner-b'&&selectedCase==='--case=profile'))throw Error('CASE');
 if(mode==='owner-a')args.push('--name=(E03|E04)/C');if(mode==='owner-b')args.push(selectedCase==='--case=profile'?'--name=E06/C':'--name=(E05|E06|E07|E08)/C');
 const env={...process.env,FLUTTER_ROOT:c.sdk,ORG_GRADLE_PROJECT_xlandNativeProof:'true'};
 for(const key of Object.keys(env))if(/DATABASE|PASSWORD|TOKEN|CURSOR_SECRET|SEPAY/i.test(key))delete env[key];
 // flutter test does not expose build-apk's -P option. Environment project
 // properties were not applied by this Flutter/Gradle runner. Set the same
 // explicit package flag in this copied project's properties, then restore.
 const gradlePath=resolve(c.sandbox,'android/gradle.properties');
 if(!gradlePath.startsWith(resolve('.local/p3')+sep))throw Error('SANDBOX');
 const originalGradle=await readFile(gradlePath);
 const nativeGradle=Buffer.concat([originalGradle,Buffer.from('\nxlandNativeProof=true\n')]);
 await writeFile(gradlePath,nativeGradle);
 const child=spawn(resolve(c.sdk,'bin/cache/dart-sdk/bin/dart.exe'),args,{cwd:c.sandbox,env,windowsHide:true,stdio:['ignore','pipe','pipe']});
 let output='',injected=false,reportCopied=false,reportCopyPromise=null,copiedScreens=0;
 child.stdout.on('data',b=>{output+=b;});child.stderr.on('data',b=>{output+=b;});
 const handoff=setInterval(()=>{
  if(!isOwner||child.exitCode!==null)return;
  if(output.includes('Installing build')&&!output.includes('P3_INPUT_READY')){
   try{call(['shell',`run-as ${pkg} sh -c 'mkdir -p files; cat > files/p3-w1-input.pending; mv files/p3-w1-input.pending files/p3-w1-input.json'`],Buffer.from(JSON.stringify(input)));injected=true;}catch{/* installing; retry atomically in this sandbox only */}
  }
  if(output.includes('P3_REPORT_READY')&&!reportCopyPromise){
   reportCopyPromise=(async()=>{
    const report=call(['shell',`run-as ${pkg} cat files/p3-owner-report.json`]);const parsed=JSON.parse(report);
    if(parsed.stage!==mode)throw Error('REPORT_STAGE');
    await writeFile(resolve(c.evidence,`native-${mode}-report.json`),report);
    const images=[];
    if(reportJourney){
     await mkdir(resolve(c.evidence,'screenshots'),{recursive:true});
     for(const screenshot of parsed.screenshots??[]){
      if(!/^[A-Z0-9_-]+\.png$/.test(screenshot.file))throw Error('IMAGE_PATH');
      const bytes=call(['exec-out','run-as',pkg,'cat','files/p3-report-images/'+screenshot.file]);
      if(bytes.readUInt32BE(0)!==0x89504e47)throw Error('IMAGE_TYPE');
      await writeFile(resolve(c.evidence,'screenshots',screenshot.file),bytes);
      images.push({...screenshot,sha256:hash(bytes),bytes:bytes.length,width:bytes.readUInt32BE(16),height:bytes.readUInt32BE(20)});copiedScreens++;
     }
     await writeFile(resolve(c.evidence,'native-report-images.json'),JSON.stringify({sourceHash:c.sourceHash,images},null,2));
    }
    reportCopied=true;
   })();
   reportCopyPromise.catch(()=>{});
  }
 },250);
 const watchdog=setTimeout(()=>child.kill(),(reportJourney?20:10)*60*1000);
 const exit=await new Promise((ok,fail)=>{child.once('error',fail);child.once('exit',v=>ok(v??1));});clearInterval(handoff);clearTimeout(watchdog);
 if(reportCopyPromise)await reportCopyPromise.catch(()=>{});
 await writeFile(gradlePath,originalGradle);if(hash(await readFile(gradlePath))!==hash(originalGradle))throw Error('CONFIG_RESTORE');
 for(const secret of redactions)output=output.split(secret).join('REDACTED');
 const logPath=resolve(c.evidence,`integration-${mode}.log`);await writeFile(logPath,output);
 const apk=resolve(c.sandbox,'build/app/outputs/flutter-apk/app-debug.apk'),bytes=await readFile(apk),sha256=hash(bytes);
 const artifactPath=resolve(c.sandbox,`../artifacts/integration-${mode}-${sha256.slice(0,12)}.apk`);await mkdir(dirname(artifactPath),{recursive:true});await copyFile(apk,artifactPath);
 const finalExit=exit||(isOwner&&(!injected||!reportCopied)?1:0);
 await writeFile(resolve(c.evidence,`integration-${mode}-exit.json`),JSON.stringify({mode,selectedCase:selectedCase??null,exit:finalExit,testExit:exit,injected,reportCopied,copiedScreens,sourceHash:c.sourceHash,bundleHash:c.bundleHash,runnerHash:hash(await readFile(fileURLToPath(import.meta.url))),testConfig:{path:'android/gradle.properties',override:'xlandNativeProof=true',beforeHash:hash(originalGradle),duringHash:hash(nativeGradle),restored:true,scope:'copied sandbox only; identical cproof flag to feed APK build'},testArtifact:{path:artifactPath,sha256,bytes:bytes.length,target:testFile},target:serial,reviewHash,scope:reportJourney?'actual XLandApp navigation, Android plugins and real repositories/API; screenshots captured from the app':mode==='ui-booking'?'actual B booking/login UI + real repositories/API; not full app navigation':'real repository/transport; not full UI E2E'},null,2));
 console.log(JSON.stringify({event:'p3_integration_complete',mode,exit:finalExit,reportCopied,evidence:logPath}));process.exitCode=finalExit;
}catch{console.error(JSON.stringify({event:'p3_integration_refused_or_failed',reason:'Target/T0/snapshot/private handoff check failed; values redacted'}));process.exitCode=1;}
