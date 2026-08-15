"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { signIn, cognitoErrorMessage, CognitoError } from "@/lib/cognito";
import { linkAccount } from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await signIn(email.trim(), password);
      // アカウント作成/紐付け（冪等）。失敗してもログイン自体は成立させ、ホームで再取得。
      await linkAccount().catch(() => {});
      router.push("/");
    } catch (err) {
      // メール未確認なら確認画面へ誘導。
      if (err instanceof CognitoError && err.code === "UserNotConfirmedException") {
        router.push(`/confirm?email=${encodeURIComponent(email.trim())}`);
        return;
      }
      setError(cognitoErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-bold">ログイン</h1>
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
          autoComplete="current-password"
          required
          placeholder="パスワード"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-brand"
        />
        {error && <p className="text-sm text-red-600">{error}</p>}
        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-xl bg-brand py-3 font-semibold text-white hover:bg-brand-strong disabled:opacity-50"
        >
          {loading ? "ログイン中…" : "ログイン"}
        </button>
      </form>
      <div className="flex justify-between text-sm">
        <Link href="/forgot" className="text-brand-strong hover:underline">
          パスワードを忘れた
        </Link>
        <Link href="/signup" className="text-brand-strong hover:underline">
          新規登録
        </Link>
      </div>
    </div>
  );
}
