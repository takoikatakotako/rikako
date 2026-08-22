"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import {
  confirmSignUp,
  resendConfirmationCode,
  cognitoErrorMessage,
} from "@/lib/cognito";
import { useQueryParam } from "@/lib/hooks";

export default function ConfirmPage() {
  const router = useRouter();
  // email はURLクエリ由来。ユーザーが編集したら override が優先される（effv+setState 回避）。
  const emailParam = useQueryParam("email");
  const [emailOverride, setEmailOverride] = useState<string | null>(null);
  const email = emailOverride ?? emailParam;
  const setEmail = setEmailOverride;
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setNotice(null);
    setLoading(true);
    try {
      await confirmSignUp(email.trim(), code.trim());
      router.push("/login");
    } catch (err) {
      setError(cognitoErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  async function onResend() {
    setError(null);
    setNotice(null);
    try {
      await resendConfirmationCode(email.trim());
      setNotice("確認コードを再送しました。");
    } catch (err) {
      setError(cognitoErrorMessage(err));
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-bold">メール確認</h1>
        <p className="mt-2 text-sm text-slate-500">
          {email || "登録したメールアドレス"} 宛に送られた確認コードを入力してください。
        </p>
      </div>
      <form onSubmit={onSubmit} className="space-y-4">
        <input
          type="email"
          required
          placeholder="メールアドレス"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="w-full rounded-xl border border-slate-300 px-4 py-3 outline-none focus:border-brand"
        />
        <input
          inputMode="numeric"
          required
          placeholder="確認コード"
          value={code}
          onChange={(e) => setCode(e.target.value)}
          className="w-full rounded-xl border border-slate-300 px-4 py-3 tracking-widest outline-none focus:border-brand"
        />
        {error && <p className="text-sm text-red-600">{error}</p>}
        {notice && <p className="text-sm text-brand-strong">{notice}</p>}
        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-xl bg-brand py-3 font-semibold text-white hover:bg-brand-strong disabled:opacity-50"
        >
          {loading ? "確認中…" : "確認する"}
        </button>
      </form>
      <button
        type="button"
        onClick={onResend}
        className="text-sm text-brand-strong hover:underline"
      >
        確認コードを再送する
      </button>
    </div>
  );
}
