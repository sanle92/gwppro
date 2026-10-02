import {createClient} from '@supabase/supabase-js';
import {createServerClient} from '@supabase/ssr';
import {cookies} from 'next/headers';
import {env} from 'cloudflare:workers';

export function configuration(){
 const e=env as Record<string,any>;
 const url=e.SUPABASE_URL;
 const publicKey=e.SUPABASE_PUBLISHABLE_KEY||e.SUPABASE_ANON_KEY;
 const secret=e.SUPABASE_SECRET_KEY||e.SUPABASE_SERVICE_ROLE_KEY;
 if(!url||!publicKey||!secret)throw new Error('Supabase is not connected. Configure the project URL, publishable key and server secret.');
 if(String(secret).startsWith('sb_publishable_'))throw new Error('Use a Supabase server secret, not a publishable key, for server access.');
 return {url,publicKey,secret};
}
export function supabaseAdmin(){const {url,secret}=configuration();return createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});}
export async function supabaseUser(){const {url,publicKey}=configuration();const jar=await cookies();return createServerClient(url,publicKey,{cookieOptions:{httpOnly:true,secure:String((env as any).APP_URL||'').startsWith('https:'),sameSite:'lax',path:'/'},cookies:{getAll:()=>jar.getAll(),setAll:values=>{try{for(const {name,value,options} of values)jar.set(name,value,options);}catch{/* Server Components rely on middleware to refresh cookies. */}}}});}
export function checked<T>(result:{data:T;error:any}):T {if(result.error)throw new Error(result.error.message||'Supabase could not complete the request.');return result.data;}
