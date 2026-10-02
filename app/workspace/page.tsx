import {identity} from '@/lib/store';
import {redirect} from 'next/navigation';
export const dynamic='force-dynamic';
export default async function Entry(){const {user,admin}=await identity();redirect(!user?'/login':admin?'/holyghost':'/portal');}
