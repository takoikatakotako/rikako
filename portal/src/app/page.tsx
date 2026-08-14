"use client";

import Link from "next/link";
import { useAuthEmail } from "@/lib/hooks";
import { signOut } from "@/lib/cognito";

export default function Home() {
  const email = useAuthEmail();

  if (email) {
    return (
      <div className="space-y-6">
        <div className="rounded-2xl border border-slate-200 bg-white p-6">
          <p className="text-sm text-slate-500">ログイン中</p>
          <p className="mt-1 font-semibold break-all">{email}</p>
        </div>
        <button
          type="button"
          onClick={() => {
            void signOut();
          }}
          className="w-full rounded-xl border border-slate-300 py-3 font-semibold text-slate-700 hover:bg-slate-100"
        >
          ログアウト
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6 text-center">
      <div>
        <h1 className="text-2xl font-bold">Rikako アカウント</h1>
        <p className="mt-2 text-slate-500">
          ログインすると、iOS / Web で同じ学習記録を使えます。
        </p>
      </div>
      <div className="space-y-3">
        <Link
          href="/login"
          className="block w-full rounded-xl bg-brand py-3 font-semibold text-white hover:bg-brand-strong"
        >
          ログイン
        </Link>
        <Link
          href="/signup"
          className="block w-full rounded-xl border border-slate-300 py-3 font-semibold text-slate-700 hover:bg-slate-100"
        >
          新規登録
        </Link>
      </div>
    </div>
  );
}
