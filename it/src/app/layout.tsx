import type { Metadata } from "next";
import Link from "next/link";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "ITパスポート過去問 | rikako",
    template: "%s | ITパスポート過去問 rikako",
  },
  description:
    "ITパスポート試験の公開問題（過去問）を無料で解ける・見られるWebアプリ。解説付き。令和6年度・令和7年度の全問を収録。",
  metadataBase: new URL("https://it.rikako.org"),
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja" className="h-full antialiased">
      <body className="min-h-full flex flex-col bg-slate-50 text-slate-900">
        <header className="border-b border-slate-200 bg-white">
          <div className="mx-auto flex h-14 max-w-3xl items-center px-4">
            <Link href="/" className="font-bold text-lg tracking-tight">
              ITパスポート過去問
              <span className="ml-1 text-sm font-normal text-slate-400">
                rikako
              </span>
            </Link>
          </div>
        </header>
        <main className="mx-auto w-full max-w-3xl flex-1 px-4 py-6">
          {children}
        </main>
        <footer className="border-t border-slate-200 bg-white">
          <div className="mx-auto max-w-3xl px-4 py-6 text-sm text-slate-500">
            <p>
              ITパスポート試験の公開問題を利用しています。© 2026 Rikako
            </p>
          </div>
        </footer>
      </body>
    </html>
  );
}
