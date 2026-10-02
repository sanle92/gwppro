import {Theme} from './theme';
import SiteWidgets from './site-widgets';
import {contactInfo} from '@/lib/contact';
import VisitorTracker from './visitor-tracker';
import PWA from "./pwa";
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  manifest: "/manifest.webmanifest",
  appleWebApp: {capable:true,statusBarStyle:"default",title:"gwppro"},
  title: "gwppro — Full-Stack Development",
  description: "Websites, online stores and business systems. Your project, from first conversation to launch.",
  other: {
    "codex-preview": "development",
  },
  icons: {
    icon: "/favicon.svg",
    apple: "/icons/icon-192.png",
    shortcut: "/favicon.svg",
  },
};

export const viewport={width:"device-width",initialScale:1,themeColor:"#155d49"};

export const dynamic="force-dynamic";

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const contact=await contactInfo();
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="antialiased"><Theme><PWA/>{children}<SiteWidgets whatsapp={contact.whatsapp}/><VisitorTracker/></Theme></body>
    </html>
  );
}
