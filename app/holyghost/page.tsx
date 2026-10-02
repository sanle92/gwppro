import {redirect} from 'next/navigation';
import {identity} from '@/lib/store';
import Workspace from '../workspace';
export const dynamic='force-dynamic';
export default async function Admin(){let account;try{account=await identity();}catch{return <main className="access"><h1>Connect your Supabase project</h1><p>Configure SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and the server-only SUPABASE_SECRET_KEY, then apply all SQL migrations. Sign in with the verified owner email configured in ADMIN_EMAIL.</p><a className="primary" href="/login">Open login</a><a className="secondary" href="/contact">Contact gwppro</a></main>;}const {user:u,admin}=account;if(!u)redirect('/login');if(!admin)return <main className="access"><h1>This workspace is private.</h1><p>Your account does not have administrator access.</p><a href="/portal">Open your client portal</a></main>;return <Workspace name={u.fullName||'Sanle'}/>;}
