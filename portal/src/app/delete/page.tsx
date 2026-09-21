"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useAuthEmail } from "@/lib/hooks";
import { deleteAccount, ApiError } from "@/lib/api";

// アカウント削除ページ（#408）。
// Google Play のアカウント削除ポリシーが求める「Web 上の削除導線」で、Play Console の
// データセーフティにこの URL（https://account.rikako.org/delete）を登録している。
// ログインしていれば確認 → DELETE /account。ログインできない人向けにメールでの依頼先も示す。
export default function DeleteAccountPage() {
  const router = useRouter();
  const email = useAuthEmail();
  const [confirmed, setConfirmed] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  async function onDelete() {
    setError(null);
    setLoading(true);
    try {
      await deleteAccount();
      setDone(true);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        // セッション切れ。authedFetch が token を消しているので、ログイン後にここへ戻す。
        router.push("/login?next=/delete");
        return;
      }
      setError(
        "削除処理が完了しませんでした。時間をおいてもう一度お試しください。繰り返し失敗する場合はお問い合わせください。",
      );
    } finally {
      setLoading(false);
    }
  }

  if (done) {
    return (
      <div className="space-y-6">
        <h1 className="text-xl font-bold">アカウントを削除しました</h1>
        <p className="text-slate-600">
          ご利用ありがとうございました。アカウントと学習データは削除されました。
          アプリはそのまま匿名でご利用いただけます（学習記録は新しく始まります）。
        </p>
        <Link href="/" className="block text-center text-brand-strong hover:underline">
          トップへ戻る
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-bold">アカウントの削除</h1>

      <section className="space-y-3 rounded-2xl border border-slate-200 bg-white p-6 text-sm text-slate-700">
        <p>アカウントを削除すると、次のデータがただちに削除されます。</p>
        <ul className="list-disc space-y-1 pl-5">
          <li>アカウント（登録したメールアドレス）</li>
          <li>このアカウントに紐付いたすべての端末の学習データ（回答履歴・正誤・学習記録）</li>
          <li>問題集の選択などの設定</li>
          <li>機種変更用の引き継ぎトークン</li>
        </ul>
        <p>
          削除は取り消せません。削除後もアプリは匿名のまま利用できますが、学習記録は新しく始まります。
        </p>
        <p className="text-slate-500">
          削除処理の整合性のため、アカウントの内部識別子（メールアドレスや氏名を含まない ID）のみを最長 8 日間保持したのち自動的に削除します。バックアップでの保持については
          <a
            href="https://rikako.org/privacy.html"
            target="_blank"
            rel="noopener noreferrer"
            className="text-brand-strong hover:underline"
          >
            プライバシーポリシー
          </a>
          をご覧ください。
        </p>
      </section>

      {email ? (
        <div className="space-y-4">
          <p className="text-sm text-slate-500">
            削除するアカウント: <span className="font-semibold break-all text-slate-700">{email}</span>
          </p>
          <label className="flex items-start gap-3 text-sm">
            <input
              type="checkbox"
              checked={confirmed}
              onChange={(e) => setConfirmed(e.target.checked)}
              className="mt-1"
            />
            <span>上記の内容を理解し、このアカウントとデータを削除することに同意します。</span>
          </label>
          {error && <p className="text-sm text-red-600">{error}</p>}
          <button
            type="button"
            disabled={!confirmed || loading}
            onClick={() => {
              void onDelete();
            }}
            className="w-full rounded-xl bg-red-600 py-3 font-semibold text-white hover:bg-red-700 disabled:opacity-50"
          >
            {loading ? "削除中…" : "アカウントを削除する"}
          </button>
          <Link href="/" className="block text-center text-sm text-slate-500 hover:underline">
            キャンセルして戻る
          </Link>
        </div>
      ) : (
        <div className="space-y-4">
          <p className="text-sm text-slate-600">
            削除するには、削除したいアカウントでログインしてください。
          </p>
          <Link
            href="/login?next=/delete"
            className="block w-full rounded-xl bg-brand py-3 text-center font-semibold text-white hover:bg-brand-strong"
          >
            ログインして削除する
          </Link>
          <p className="text-sm text-slate-500">
            ログインできない場合は、登録したメールアドレスからアプリ内のお問い合わせ、または
            <a href="mailto:snorlax.chemist.and.jazz@gmail.com" className="text-brand-strong hover:underline">
              snorlax.chemist.and.jazz@gmail.com
            </a>
            宛に「アカウント削除希望」とご連絡ください。本人確認のうえ削除します。
          </p>
        </div>
      )}
    </div>
  );
}
