import {createClient} from '@supabase/supabase-js';
const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_SECRET_KEY||process.env.SUPABASE_SERVICE_ROLE_KEY,publicKey=process.env.SUPABASE_PUBLISHABLE_KEY||process.env.SUPABASE_ANON_KEY;
if(!url||!key||!publicKey)throw new Error('Set the Supabase project URL, publishable key and server secret.');
const client=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
for(const table of ['gwppro_records','gwppro_profiles','gwppro_payments','gwppro_notifications','gwppro_subscriptions','gwppro_auth_limits','gwppro_analytics_sessions','gwppro_analytics_events']){const {error,count}=await client.from(table).select('*',{count:'exact',head:true});if(error)throw new Error(table+': '+error.message);console.log(`${table}: accessible (${count} rows).`);}
const {data:bucket,error}=await client.storage.getBucket('gwppro-files');if(error)throw error;if(bucket.public)throw new Error('The gwppro-files bucket must be private.');
const publicClient=createClient(url,publicKey,{auth:{persistSession:false,autoRefreshToken:false}});const privateQuery=await publicClient.from('gwppro_records').select('id,kind').not('kind','in','(service,portfolio)');if(privateQuery.error)throw privateQuery.error;if(privateQuery.data.length)throw new Error('Anonymous access exposes private records.');
console.log('PASS: target tables, private file bucket and anonymous record isolation. Complete owner/client sign-in checks before switching the live app.');
