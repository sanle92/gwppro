'use client';
import {ThemeProvider,useTheme} from 'next-themes';
import {useEffect,useState} from 'react';
import {Moon,Sun} from 'lucide-react';
export function Theme({children}:{children:React.ReactNode}){return <ThemeProvider attribute="data-theme" defaultTheme="system" enableSystem storageKey="gwppro-theme" disableTransitionOnChange>{children}</ThemeProvider>;}
export function ThemeToggle(){const {resolvedTheme,setTheme}=useTheme();const [ready,setReady]=useState(false);useEffect(()=>setReady(true),[]);const dark=ready&&resolvedTheme==='dark';return <button className="iconbutton theme-toggle" disabled={!ready} aria-label={dark?'Switch to light mode':'Switch to dark mode'} title={dark?'Light mode':'Dark mode'} onClick={()=>setTheme(dark?'light':'dark')}>{dark?<Sun size={19}/>:<Moon size={19}/>}</button>;}
