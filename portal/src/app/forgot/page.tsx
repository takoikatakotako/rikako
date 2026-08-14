"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import {
  forgotPassword,
  confirmForgotPassword,
  cognitoErrorMessage,
} from "@/lib/cognito";

export default function ForgotPasswordPage() {
  const router = useRouter();
  const [step, setStep] = useState<"request" | "reset">("request");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onRequest(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await forgotPassword(email.trim());
      setStep("reset");
    } catch (err) {
      setError(cognitoErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  async function onReset(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await confirmForgotPassword(email.trim(), code.trim(), password);
      router.push("/login");
    } catch (err) {
      setError(cognitoErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-bold">パスワード再設定</h1>
      {step === "request" ? (
        <form onSubmit={onRequest} className="space-y-4">
          <p className="text-sm text-slate-500">
            登録済みのメールアドレスに確認コードを送ります。
          </p>
          <input
            type="email"
            autoComplete="email"
            required
            placeholder="メールアドレス"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-brand"
          />
          {error && <p className="text-sm text-red-600">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="w-full rounded-xl bg-brand py-3 font-semibold text-white hover:bg-brand-strong disabled:opacity-50"
          >
            {loading ? "送信中…" : "確認コードを送る"}
          </button>
        </form>
      ) : (
        <form onSubmit={onReset} className="space-y-4">
          <p className="text-sm text-slate-500">
            届いた確認コードと新しいパスワードを入力してください。
          </p>
          <input
            inputMode="numeric"
            required
            placeholder="確認コード"
            value={code}
            onChange={(e) => setCode(e.target.value)}
            className="w-full rounded-xl border border-slate-300 px-4 py-3 tracking-widest outline-none focus:border-brand"
          />
          <input
            type="password"
            autoComplete="new-password"
            required
            placeholder="新しいパスワード"
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
            {loading ? "設定中…" : "パスワードを再設定"}
          </button>
        </form>
      )}
      <Link href="/login" className="text-sm text-brand-strong hover:underline">
        ログインに戻る
      </Link>
    </div>
  );
}
