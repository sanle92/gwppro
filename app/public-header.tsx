'use client';
import {useState} from 'react';
import {usePathname} from 'next/navigation';
import {Menu,X} from 'lucide-react';
import {ThemeToggle} from './theme';
export default function PublicHeader(){const [open,setOpen]=useState(false);const path=usePathname();return <header className="public-nav professional-header"><a className="brand" href="/"><img src="/gwppro.png" alt="gwppro logo" width="120" height="40" /></a><nav className={open?'open':''} aria-label="Main navigation"><a href="/#services" onClick={()=>setOpen(false)}>Services</a><a href="/#work" onClick={()=>setOpen(false)}>Selected work</a><a href="/contact" aria-current={path==='/contact'?'page':undefined}>Contact</a><a href="/portal">Client portal</a></nav><div className="public-nav-actions"><ThemeToggle/><a className="primary" href="/start-project">Start a project</a><button className="iconbutton public-menu" aria-label={open?'Close menu':'Open menu'} aria-expanded={open} onClick={()=>setOpen(!open)}>{open?<X size={21}/>:<Menu size={21}/>}</button></div></header>;}
