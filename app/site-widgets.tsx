'use client';
import {usePathname} from 'next/navigation';
import {MessageCircle} from 'lucide-react';
import {ThemeToggle} from './theme';
export default function SiteWidgets({whatsapp}:{whatsapp:string}){const path=usePathname();const privatePage=['/holyghost','/portal','/account','/workspace','/login'].some(p=>path.startsWith(p));return <>{(path==='/login'||path==='/account')&&<div className="auth-theme"><ThemeToggle/></div>}{!privatePage&&<a className="whatsapp-float" href={whatsapp?'https://wa.me/'+whatsapp+'?text='+encodeURIComponent('Hello gwppro, I would like to discuss a project.'):'/contact#contact-form'} target={whatsapp?'_blank':undefined} rel={whatsapp?'noopener noreferrer':undefined} aria-label={whatsapp?'Chat with gwppro on WhatsApp':'Contact gwppro'} title={whatsapp?'Chat on WhatsApp':'Let’s talk about your project'}><MessageCircle size={25}/><span>{whatsapp?'WhatsApp':'Let’s talk'}</span></a>}</>;}
