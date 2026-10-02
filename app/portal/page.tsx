import {identity} from '@/lib/store';
import {redirect} from 'next/navigation';
import Workspace from '../workspace';
export const dynamic='force-dynamic';
export default async function Portal(){const {user:u}=await identity();if(!u)redirect('/login');return <Workspace portal name={u.fullName||u.email.split('@')[0]}/>;}
