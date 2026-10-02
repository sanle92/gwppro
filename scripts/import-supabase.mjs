import {createClient} from '@supabase/supabase-js';
import {readFile,stat} from 'node:fs/promises';
import {resolve,relative,sep} from 'node:path';
const [exportPath,filesDirectory]=process.argv.slice(2);
if(!exportPath)throw new Error('Usage: node --env-file=.env scripts/import-supabase.mjs <d1-export.json> [r2-files-directory]');
const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_SECRET_KEY||process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!url||!key)throw new Error('Set SUPABASE_URL and the server secret in .env.');
const client=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
const exported=JSON.parse(await readFile(exportPath,'utf8'));const tables=exported.tables||exported;
const check=r=>{if(r.error)throw new Error(r.error.message);return r.data;};
const parse=d=>typeof d==='string'?JSON.parse(d):d;
const records=(tables.records||[]).map(r=>({id:r.id,kind:r.kind,email:String(r.email||'').toLowerCase(),data:parse(r.data),created:r.created,updated:r.updated||r.created}));
const files=records.filter(r=>r.kind==='file');
if(files.length&&!filesDirectory)throw new Error('Export the R2 objects and pass their directory before importing file metadata.');
// Preserve object keys and parent links. Never replace an existing target object.
for(const file of files){const key=file.data.key;if(typeof key!=='string'||!key)throw new Error('File record has no object key.');const base=resolve(filesDirectory),path=resolve(base,key);if(relative(base,path).startsWith('..'+sep)||relative(base,path)==='..')throw new Error('Unsafe object key.');const metadata=await stat(path);if(metadata.size>10485760)throw new Error('File exceeds the configured 10 MB limit.');const existing=await client.storage.from('gwppro-files').download(key);if(existing.error){const body=await readFile(path);check(await client.storage.from('gwppro-files').upload(key,body,{contentType:'application/octet-stream',upsert:false}));}else{const a=Buffer.from(await existing.data.arrayBuffer()),b=await readFile(path);if(!a.equals(b))throw new Error('Target storage object differs: '+key);}}
const stable=o=>{if(Array.isArray(o))return o.map(stable);if(o&&typeof o==='object')return Object.fromEntries(Object.keys(o).sort().map(k=>[k,stable(o[k])]));return o;};
for(const record of records){const existing=check(await client.from('gwppro_records').select('id,kind,email,data').eq('id',record.id).maybeSingle());if(existing&&JSON.stringify(stable(existing))!==JSON.stringify(stable({id:record.id,kind:record.kind,email:record.email,data:record.data})))throw new Error('Target record differs; reconcile it before importing: '+record.id);}
const normalized={gwppro_records:records,gwppro_payments:(tables.payments||[]).map(r=>({...r})),gwppro_notifications:(tables.notifications||[]).map(r=>({...r,email:r.email.toLowerCase(),read:r.read===true||r.read===1})),gwppro_subscriptions:(tables.subscriptions||[]).map(r=>({...r,email:r.email.toLowerCase(),data:parse(r.data)}))};
for(const [name,rows] of Object.entries(normalized)){for(let i=0;i<rows.length;i+=100)check(await client.from(name).upsert(rows.slice(i,i+100),{ignoreDuplicates:true,onConflict:name==='gwppro_subscriptions'?'endpoint':'id'}));console.log(`${name}: ${rows.length} source rows imported or already present.`);}
console.log('Import complete. D1 passwords, sessions and invitation tokens are not copied. Set up the studio account and invite clients through Supabase Auth. Keep the old D1/R2 source until you have verified counts, file downloads and client access.');
