import type { Metadata } from "next";
import Link from "next/link";
import { GoogleAnalytics } from "@/components/GoogleAnalytics";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Rikako アカウント",
    template: "%s | Rikako アカウント",
  },
  description: "Rikako のアカウント（ログイン・新規登録）。iOS / Web で学習記録を共有できます。",
  // 配信ドメインは環境で変わる（dev=account.dev.rikako.org / prod=account.rikako.org）。
  metadataBase: new URL(
    process.env.NEXT_PUBLIC_PORTAL_URL ?? "https://account.rikako.org",
  ),
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ja" className="h-full antialiased">
      <body className="min-h-full flex flex-col bg-slate-50 text-slate-900">
        <header className="sticky top-0 z-10 border-b border-slate-200 bg-white/90 backdrop-blur">
          <div className="mx-auto flex h-14 max-w-md items-center px-4">
            <Link
              href="/"
              className="flex items-center gap-2 font-bold text-lg tracking-tight"
            >
              <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-brand text-sm font-black text-white">
                R
              </span>
              Rikako
            </Link>
          </div>
        </header>
        <main className="mx-auto w-full max-w-md flex-1 px-4 py-8">{children}</main>
        <footer className="border-t border-slate-200 bg-white">
          <div className="mx-auto flex max-w-md flex-col gap-2 px-4 py-6 text-sm text-slate-500">
            <nav className="flex flex-wrap gap-x-4 gap-y-2">
              <a href="https://rikako.org/terms" className="hover:text-brand-strong hover:underline">
                利用規約
              </a>
              <a href="https://rikako.org/privacy" className="hover:text-brand-strong hover:underline">
                プライバシーポリシー
              </a>
            </nav>
            <p>© 2026 Rikako</p>
          </div>
        </footer>
        <GoogleAnalytics />
      </body>
    </html>
  );
}
