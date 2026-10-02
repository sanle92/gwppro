import {identity} from '@/lib/store';
import {redirect} from 'next/navigation';
import Account from './settings';
export const dynamic='force-dynamic';
export default async function Page(){const {user,admin}=await identity();if(!user)redirect('/login');return <Account admin={admin} email={user.email}/>;}
