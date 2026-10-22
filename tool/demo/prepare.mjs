// Public, read-only snapshot for the separate prepared-demo entry point.
// Never exports sessions, /me, private documents, availability or payment policy.
import {mkdir, readFile, writeFile, rename, stat} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const target=resolve(root,'assets/prepared-demo');
const origin=process.env.XLAND_DEMO_API??'https://p01--xland--y56gnzgzjsqm.code.run/api/v1';
const api=new URL(origin);
if(api.protocol!=='https:'||api.pathname!=='/api/v1'||api.username||api.password||api.search)throw Error('Expected HTTPS API /api/v1');
await mkdir(resolve(target,'media'),{recursive:true});
await mkdir(resolve(target,'tiles'),{recursive:true});
const previous=process.argv.includes('--reuse')?JSON.parse(await readFile(resolve(target,'snapshot.json'),'utf8')):null;
const entries=previous?.entries??{};
async function get(path,query={}){
  const url=new URL(origin+path);url.search=new URLSearchParams(query).toString();
  let error;
  for(let attempt=0;attempt<3;attempt++){
    try{
      const response=await fetch(url,{signal:AbortSignal.timeout(45000),redirect:'error'});
      if(!response.ok)throw Error('GET '+path+': '+response.status);
      const body=await response.json();
      if(!Object.hasOwn(body,'data'))throw Error('Invalid API envelope: '+path);
      return body;
    }catch(e){error=e;}
  }
  throw error;
}
async function list(path,query={}){
  let cursor;const data=[];const seen=new Set();
  do{
    const body=await get(path,{...query,limit:'50',...(cursor?{cursor}:{})});
    if(!Array.isArray(body.data))throw Error('Invalid list: '+path);
    data.push(...body.data);
    cursor=body.meta?.hasMore?body.meta.nextCursor:null;
    if(cursor&&seen.has(cursor))throw Error('Repeated cursor: '+path);
    if(cursor)seen.add(cursor);
  }while(cursor);
  entries[path]={data,meta:{hasMore:false,nextCursor:null,total:data.length}};
  return data;
}
async function pool(items,work,width=3){
  let next=0;
  await Promise.all(Array.from({length:Math.min(width,items.length)},async()=>{
    while(next<items.length){const item=items[next++];await work(item);}
  }));
}
let properties,videos,events,clubs,consultants,authors;
if(!previous){
properties=await list('/properties');
videos=await list('/feed',{feedScope:'recommended'});
events=await list('/events');
clubs=await list('/clubs');
entries['/catalog/locations']=await get('/catalog/locations');
for(const province of entries['/catalog/locations'].data.provinces){
  entries['/catalog/locations?provinceCode='+province.code]=await get('/catalog/locations',{provinceCode:province.code});
}
await pool(properties,async p=>{
  for(const suffix of ['', '/legal','/area','/area-map','/share']){
    const path='/properties/'+p.id+suffix;entries[path]=await get(path);
  }
  console.log('Prepared property '+p.code);
});
consultants=[...new Set(properties.map(p=>p.consultantId).filter(Boolean))];
await pool(consultants,async id=>{
  const path='/consultants/'+id;entries[path]=await get(path);
  for(const suffix of ['/videos','/properties','/reviews'])await list(path+suffix);
});
authors=[...new Set(videos.map(v=>v.author.id))];
await pool(authors,async id=>{
  const path='/authors/'+id;entries[path]=await get(path);await list(path+'/videos');
});
await pool(videos,async v=>{
  const path='/videos/'+v.id;entries[path]=await get(path);
  // Comments stay live: do not bundle other users' conversations.
  entries[path+'/share']=await get(path+'/share');
});
await pool(events,async e=>{
  const path='/events/'+e.id;entries[path]=await get(path);entries[path+'/share']=await get(path+'/share');
});
await pool(clubs,async c=>{const path='/clubs/'+c.id;entries[path]=await get(path);});
}else{
  properties=entries['/properties'].data;videos=entries['/feed'].data;
  events=entries['/events'].data;clubs=entries['/clubs'].data;
  consultants=[...new Set(properties.map(p=>p.consultantId).filter(Boolean))];
  authors=[...new Set(videos.map(v=>v.author.id))];
}

const urls=new Map();
function collect(value){
  if(Array.isArray(value)){value.forEach(collect);return;}
  if(!value||typeof value!=='object')return;
  for(const [key,item] of Object.entries(value)){
    if(typeof item==='string'&&/^https:\/\//.test(item)&&
      (['thumbnailUrl','avatarUrl','coverUrl','imageUrl','photoUrl','previewUrl'].includes(key)||
        (key==='url'&&(['image','video'].includes(value.kind)||/\.(png|jpe?g|webp|gif|mp4|webm)(\?|$)/i.test(item))))){
      // A document URL is never a public media asset to bundle.
      if(!/\.(pdf|docx?)(\?|$)/i.test(item)&&!item.includes('/object/sign/'))urls.set(item,null);
    }else collect(item);
  }
}
Object.values(entries).forEach(collect);
const media={};const mediaFailures=[];
async function download(url,folder){
  const old=folder==='media'?previous?.media[url]:null;
  if(old){
    try{if((await stat(resolve(root,old.asset))).size===old.bytes)return old;}catch{}
  }
  if(folder==='tiles'&&previous?.tiles[url]){
    const asset=previous.tiles[url];
    try{const size=(await stat(resolve(root,asset))).size;if(size>8)return {asset,bytes:size,mime:'image/png'};}catch{}
  }
  const response=await fetch(url,{signal:AbortSignal.timeout(120000),redirect:'follow'});
  if(!response.ok)throw Error('HTTP '+response.status);
  const mime=(response.headers.get('content-type')??'').split(';')[0];
  const ext={'image/png':'png','image/jpeg':'jpg','image/webp':'webp','image/gif':'gif','video/mp4':'mp4','video/webm':'webm'}[mime];
  if(!ext)throw Error('Unsupported media MIME '+mime);
  const bytes=Buffer.from(await response.arrayBuffer());
  if(!bytes.length||bytes.length>120*1024*1024)throw Error('Unexpected media size');
  const name=createHash('sha256').update(url).digest('hex').slice(0,24)+'.'+ext;
  const path=resolve(target,folder,name);
  try{if((await stat(path)).size===bytes.length)return {asset:'assets/prepared-demo/'+folder+'/'+name,bytes:bytes.length,mime};}catch{}
  await writeFile(path,bytes);
  return {asset:'assets/prepared-demo/'+folder+'/'+name,bytes:bytes.length,mime};
}
await pool([...urls.keys()],async url=>{
  try{media[url]=await download(url,'media');}
  catch(error){mediaFailures.push({url,reason:String(error)});}
},5);
// Cache only the initial map viewport and adjacent zoom levels, with a hard cap.
// Attribution remains in the real area-map payload and in the UI.
const tiles={};const tileUrls=new Set();const tileFailures=[];
for(const response of Object.values(entries)){
  const a=response.data?.publicArea;
  if(response.data?.availability!=='ready'||!a)continue;
  for(const z of [a.initialZoom-1,a.initialZoom,a.initialZoom+1]){
    const n=2**z,lat=a.centerLatitude*Math.PI/180;
    const x=Math.floor((a.centerLongitude+180)/360*n);
    const y=Math.floor((1-Math.asinh(Math.tan(lat))/Math.PI)/2*n);
    for(let dx=-1;dx<=1;dx++)for(let dy=-1;dy<=1;dy++){
      tileUrls.add(api.origin+'/maps/tiles/'+z+'/'+(x+dx)+'/'+(y+dy)+'.png');
    }
  }
}
if(tileUrls.size>300)throw Error('Map preparation exceeds 300-tile cap');
await pool([...tileUrls],async url=>{
  try{tiles[url]=(await download(url,'tiles')).asset;}
  catch(error){tileFailures.push({url,reason:String(error)});}
},4);
const snapshot={version:1,preparedAt:previous?.preparedAt??new Date().toISOString(),apiOrigin:origin,entries,media,tiles};
await writeFile(resolve(target,'snapshot.json.tmp'),JSON.stringify(snapshot));
await rename(resolve(target,'snapshot.json.tmp'),resolve(target,'snapshot.json'));
const report={preparedAt:snapshot.preparedAt,apiOrigin:origin,properties:properties.length,videos:videos.length,consultants:consultants.length,authors:authors.length,events:events.length,clubs:clubs.length,endpoints:Object.keys(entries).length,media:Object.keys(media).length,mediaBytes:Object.values(media).reduce((s,m)=>s+m.bytes,0),tiles:Object.keys(tiles).length,mediaFailures,tileFailures};
await writeFile(resolve(target,'report.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
if(mediaFailures.length||tileFailures.length)process.exitCode=1;
