"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useAuthEmail } from "@/lib/hooks";
import { signOut } from "@/lib/cognito";
import { ensureAccountLinked, getServices, ApiError, Service } from "@/lib/api";

type Status = "loading" | "ready" | "error";

export default function Home() {
  const email = useAuthEmail();
  const [services, setServices] = useState<Service[]>([]);
  const [status, setStatus] = useState<Status>("loading");
  const [reload, setReload] = useState(0);

  useEffect(() => {
    if (!email) return;
    let active = true;
    // 毎回アカウントの紐付けを保証してから利用サービスを取得する（初回 link の
    // 失敗を自己修復する）。確定 401 は authedFetch が token を消し、useAuthEmail が
    // null になってログイン画面に戻るため、ここでは error 扱いにしない。
    ensureAccountLinked()
      .then(() => getServices())
      .then((s) => {
        if (active) {
          setServices(s);
          setStatus("ready");
        }
      })
      .catch((e) => {
        if (active && !(e instanceof ApiError && e.status === 401)) {
          setStatus("error");
        }
      });
    return () => {
      active = false;
    };
  }, [email, reload]);

  if (email) {
    return (
      <div className="space-y-6">
        <div className="rounded-2xl border border-slate-200 bg-white p-6">
          <p className="text-sm text-slate-500">ログイン中</p>
          <p className="mt-1 font-semibold break-all">{email}</p>
        </div>

        <section className="rounded-2xl border border-slate-200 bg-white p-6">
          <h2 className="text-sm font-semibold text-slate-500">利用中のサービス</h2>
          {status === "loading" ? (
            <p className="mt-3 text-sm text-slate-400">読み込み中…</p>
          ) : status === "error" ? (
            <div className="mt-3 space-y-3">
              <p className="text-sm text-red-600">
                アカウント情報の取得に失敗しました。
              </p>
              <button
                type="button"
                onClick={() => {
                  setStatus("loading");
                  setReload((r) => r + 1);
                }}
                className="rounded-lg border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100"
              >
                再試行
              </button>
            </div>
          ) : services.length === 0 ? (
            <p className="mt-3 text-sm text-slate-500">
              まだ利用中のサービスはありません。iOS / Web アプリで学習すると、ここに表示されます。
            </p>
          ) : (
            <ul className="mt-3 space-y-2">
              {services.map((s) => (
                <li
                  key={s.slug}
                  className="rounded-xl border border-slate-200 px-4 py-3 font-medium"
                >
                  {s.title}
                </li>
              ))}
            </ul>
          )}
        </section>

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
