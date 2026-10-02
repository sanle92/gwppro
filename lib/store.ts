import {env} from 'cloudflare:workers';
import {accountIdentity} from './auth';
import {recordNotifications} from './notifications';
import {supabaseAdmin,checked} from './supabase';
export function runtime():Record<string,any>{return env as any;}
export function ownerEmail(){const value=String(runtime().ADMIN_EMAIL||'').trim().toLowerCase();if(!value)throw new Error('ADMIN_EMAIL is not configured.');return value;}
export function db(){return supabaseAdmin();}
export async function identity(){return accountIdentity();}
function unpack(r:any){return r?{...(typeof r.data==='string'?JSON.parse(r.data):r.data),id:r.id,kind:r.kind,email:r.email,created:r.created}:null;}
export async function all(kind?:string,email?:string){const output:any[]=[];for(let offset=0;;offset+=1000){let q=db().from('gwppro_records').select('*').order('created',{ascending:false}).order('id').range(offset,offset+999);if(kind)q=q.eq('kind',kind);if(email)q=q.eq('email',email.toLowerCase());const rows=checked(await q)||[];output.push(...rows.map(unpack));if(rows.length<1000)break;}return output;}
export async function one(id:string){return unpack(checked(await db().from('gwppro_records').select('*').eq('id',id).maybeSingle()));}
export async function save(kind:string,data:any,id=crypto.randomUUID()) {const previous=await one(id);const now=new Date().toISOString();const email=String(data.email||'').toLowerCase();const clean={...data};delete clean.id;delete clean.kind;delete clean.created;const result=unpack(checked(await db().from('gwppro_records').upsert({id,kind,email,data:clean,created:previous?.created||now,updated:now}).select().single()));await recordNotifications(result,previous);return result;}
export function fail(error:unknown,status=400){return Response.json({error:error instanceof Error?error.message:'The request could not be completed.'},{status,headers:{'Cache-Control':'no-store'}});}
export function sameOrigin(req:Request){const origin=req.headers.get('origin');if(!origin||origin!==new URL(req.url).origin)throw new Error('Invalid request origin.');}
