// One-time private release signing. Never prints passwords or replaces an existing key.
import {mkdir,readFile,writeFile,access} from 'node:fs/promises';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {randomBytes,X509Certificate} from 'node:crypto';
import {spawnSync} from 'node:child_process';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const directory=resolve(root,'.local/signing');
const store=resolve(directory,'xland-internal-release.jks');
const privateFile=resolve(directory,'credentials.json');
const properties=resolve(root,'android/key.properties');
const keytool=process.env.XLAND_KEYTOOL??'keytool';
const exists=async path=>{try{await access(path);return true;}catch{return false;}};
await mkdir(directory,{recursive:true});
let config;
if(await exists(privateFile)) {
  config=JSON.parse(await readFile(privateFile,'utf8'));
  if(!await exists(store))throw new Error('Signing credentials exist without keystore; restore the private backup.');
} else {
  if(await exists(store)||await exists(properties))throw new Error('Existing signing material found; refusing to replace it.');
  config={keyAlias:'xland-internal',storePassword:randomBytes(32).toString('hex'),keyPassword:randomBytes(32).toString('hex')};
  const result=spawnSync(keytool,['-genkeypair','-keystore',store,'-storetype','JKS','-alias',config.keyAlias,
    '-keyalg','RSA','-keysize','3072','-validity','10000','-dname','CN=XLand Internal Release,OU=Mobile,O=XLand,C=VN',
    '-storepass:env','XLAND_SIGNING_STORE_PASSWORD','-keypass:env','XLAND_SIGNING_KEY_PASSWORD','-noprompt'],{
    windowsHide:true,env:{...process.env,XLAND_SIGNING_STORE_PASSWORD:config.storePassword,XLAND_SIGNING_KEY_PASSWORD:config.keyPassword}});
  if(result.status!==0)throw new Error('Keystore generation failed; private output suppressed.');
  await writeFile(privateFile,JSON.stringify(config,null,2),{flag:'wx',mode:0o600});
}
const exported=spawnSync(keytool,['-exportcert','-keystore',store,'-alias',config.keyAlias,'-storepass:env','XLAND_SIGNING_STORE_PASSWORD'],{
  windowsHide:true,env:{...process.env,XLAND_SIGNING_STORE_PASSWORD:config.storePassword}});
if(exported.status!==0)throw new Error('Certificate export failed; private output suppressed.');
const certificate=new X509Certificate(exported.stdout);
if(!await exists(properties))await writeFile(properties,
  `storeFile=${store.replaceAll('\\','/')}\nstorePassword=${config.storePassword}\nkeyAlias=${config.keyAlias}\nkeyPassword=${config.keyPassword}\n`,{flag:'wx',mode:0o600});
const metadata={applicationId:'vn.xland.xland_mobile',keyAlias:config.keyAlias,sha1:certificate.fingerprint,sha256:certificate.fingerprint256,validTo:certificate.validTo};
await writeFile(resolve(directory,'certificate.json'),JSON.stringify(metadata,null,2));
console.log(JSON.stringify(metadata,null,2));
