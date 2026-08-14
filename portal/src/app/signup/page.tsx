"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { signUp, cognitoErrorMessage } from "@/lib/cognito";

export default function SignUpPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (password !== confirm) {
      setError("パスワードが一致しません。");
      return;
    }
    setLoading(true);
    try {
      await signUp(email.trim(), password);
      router.push(`/confirm?email=${encodeURIComponent(email.trim())}`);
    } catch (err) {
      setError(cognitoErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-bold">新規登録</h1>
      <form onSubmit={onSubmit} className="space-y-4">
        <input
          type="email"
          autoComplete="email"
          required
          placeholder="メールアドレス"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-brand"
        />
        <input
          type="password"
          autoComplete="new-password"
          required
          placeholder="パスワード（8文字以上・大小英字・数字・記号）"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-brand"
        />
        <input
          type="password"
          autoComplete="new-password"
          required
          placeholder="パスワード（確認）"
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
          className="w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-brand"
        />
        {error && <p className="text-sm text-red-600">{error}</p>}
        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-xl bg-brand py-3 font-semibold text-white hover:bg-brand-strong disabled:opacity-50"
        >
          {loading ? "登録中…" : "確認コードを送る"}
        </button>
      </form>
      <p className="text-sm text-slate-500">
        アカウントをお持ちの方は{" "}
        <Link href="/login" className="text-brand-strong hover:underline">
          ログイン
        </Link>
      </p>
    </div>
  );
}
