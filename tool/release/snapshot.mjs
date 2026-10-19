import {readdir,readFile,writeFile,mkdir,copyFile,lstat} from 'node:fs/promises';
import {resolve,join,dirname} from 'node:path';
import {createHash} from 'node:crypto';
const target=resolve('../.release-staging/xland-mobile-0.2.0+2');
const files=['pubspec.yaml','pubspec.lock','analysis_options.yaml'];
const exclude=new Set(['build','.gradle','.cxx','.kotlin','local.properties','key.properties']);
async function walk(directory){for(const entry of await readdir(directory,{withFileTypes:true})){
 if(exclude.has(entry.name)||/\.(jks|keystore)$/.test(entry.name))continue;
 if(entry.isSymbolicLink())throw new Error('Symlink in snapshot input');
 const path=join(directory,entry.name);if(entry.isDirectory())await walk(path);else if(entry.isFile())files.push(path);
}}
for(const directory of ['lib','assets','android','tool/release'])await walk(directory);
await mkdir(target);const manifest=[];
for(const path of files.sort()){
 if(!(await lstat(path)).isFile())throw new Error('Unexpected snapshot input');
 const bytes=await readFile(path),dest=join(target,path);await mkdir(dirname(dest),{recursive:true});await copyFile(path,dest);
 manifest.push({path:path.replaceAll('\\','/'),bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')});
}
const report={time:new Date().toISOString(),target,files:manifest};
await writeFile('../brain/logs/agent-a/A21_PHASE4_2026-10-19/mobile-source-manifest.json',JSON.stringify(report,null,2));
console.log(JSON.stringify({target,files:manifest.length,bytes:manifest.reduce((total,file)=>total+file.bytes,0)}));
