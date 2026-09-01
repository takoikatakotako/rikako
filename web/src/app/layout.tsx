import type { Metadata } from "next";
import Link from "next/link";
import { siteConfig } from "@/lib/site";
import { AuthMenu } from "@/components/AuthMenu";
import { GoogleAnalytics } from "@/components/GoogleAnalytics";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: `${siteConfig.siteName} | rikako`,
    template: `%s | ${siteConfig.siteName} rikako`,
  },
  description: siteConfig.description,
  metadataBase: new URL(siteConfig.domain),
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja" className="h-full antialiased">
      <body className="min-h-full flex flex-col bg-slate-50 text-slate-900">
        <header className="sticky top-0 z-10 border-b border-slate-200 bg-white/90 backdrop-blur">
          <div className="mx-auto flex h-14 max-w-3xl items-center justify-between gap-4 px-4">
            <Link
              href="/"
              className="flex items-center gap-2 font-bold text-lg tracking-tight"
            >
              <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-brand text-sm font-black text-white">
                {siteConfig.badge}
              </span>
              {siteConfig.siteName}
            </Link>
            <AuthMenu />
          </div>
        </header>
        <main className="mx-auto w-full max-w-3xl flex-1 px-4 py-6">
          {children}
        </main>
        <footer className="border-t border-slate-200 bg-white">
          <div className="mx-auto flex max-w-3xl flex-col gap-3 px-4 py-6 text-sm text-slate-500">
            <nav className="flex flex-wrap gap-x-4 gap-y-2">
              <a
                href="https://rikako.org/terms"
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-brand-strong hover:underline"
              >
                利用規約
              </a>
              <a
                href="https://rikako.org/privacy"
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-brand-strong hover:underline"
              >
                プライバシーポリシー
              </a>
            </nav>
            <p>
              {siteConfig.sourceNote && `${siteConfig.sourceNote} `}© 2026 Rikako
            </p>
          </div>
        </footer>
        <GoogleAnalytics />
      </body>
    </html>
  );
}
