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
        <header className="sticky top-0 z-10 border-b border-slate-200 bg-white/90 backdrop-blur">
          <div className="mx-auto flex h-14 max-w-3xl items-center px-4">
            <Link
              href="/"
              className="flex items-center gap-2 font-bold text-lg tracking-tight"
            >
              <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-brand text-sm font-black text-white">
                IT
              </span>
              ITパスポート過去問
            </Link>
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
            <p>ITパスポート試験の公開問題を利用しています。© 2026 Rikako</p>
          </div>
        </footer>
      </body>
    </html>
  );
}
