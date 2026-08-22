"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useAuthEmail } from "@/lib/hooks";
import { signOut } from "@/lib/cognito";
import { ensureAccountLinked, waitForPendingSubmissions } from "@/lib/api";

/// ヘッダーのログイン状態表示。未ログインならログインへの導線、
/// ログイン中はメールアドレスとログアウトを出す。
export function AuthMenu() {
  const email = useAuthEmail();
  // どのアカウントについての結果かを持つ。ログアウトやアカウント切り替えで
  // 前回の失敗表示が残らないようにするため、email とセットで覚える。
  const [linkResult, setLinkResult] = useState<{
    email: string;
    failed: boolean;
  } | null>(null);

  useEffect(() => {
    if (!email) return;

    // ログイン後にこの端末の匿名データをアカウントへ紐付ける（冪等）。
    // ログイン直後だけでなく再訪時にも通るので、一時的な失敗はここで自己修復する。
    let cancelled = false;
    // 送信中の匿名解答がある状態で link すると、link 後に確定した回答が
    // 旧 device user に入り、マージ対象から漏れる。先に決着させる。
    waitForPendingSubmissions()
      .then(() => ensureAccountLinked())
      .then(() => {
        if (!cancelled) setLinkResult({ email, failed: false });
      })
      .catch(() => {
        if (!cancelled) setLinkResult({ email, failed: true });
      });
    return () => {
      cancelled = true;
    };
  }, [email]);

  const linkFailed = linkResult?.email === email && linkResult.failed;

  if (!email) {
    return (
      <Link
        href="/login/"
        className="text-sm font-semibold text-brand-strong hover:underline"
      >
        ログイン
      </Link>
    );
  }

  return (
    <div className="flex items-center gap-3 text-sm">
      {linkFailed && (
        <span
          className="text-amber-600"
          title="この端末の学習記録がアカウントに取り込めていません。時間をおいて再読み込みしてください。"
        >
          同期未完了
        </span>
      )}
      <span className="max-w-[10rem] truncate text-slate-500" title={email}>
        {email}
      </span>
      <button
        type="button"
        onClick={() => void signOut()}
        className="font-semibold text-slate-500 hover:text-brand-strong hover:underline"
      >
        ログアウト
      </button>
    </div>
  );
}
