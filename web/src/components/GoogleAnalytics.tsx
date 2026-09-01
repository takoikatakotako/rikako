import Script from "next/script";

// GA4。rikako.org 配下は 1 プロパティ 1 ウェブストリームで測定し、サイト別の
// 数字はレポートの「ホスト名」ディメンションで分ける。ストリームを分けると
// it → account のログイン導線などでセッションと参照元が切れてしまうため。
//
// 測定ID はビルド時に埋め込まれる。未設定ならタグを出さない（dev 環境や
// ローカルの操作で本番の計測値を汚さないようにするため、dev のデプロイでは
// 意図的に渡していない）。
const measurementId = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID;

export function GoogleAnalytics() {
  if (!measurementId) return null;

  return (
    <>
      <Script
        src={`https://www.googletagmanager.com/gtag/js?id=${measurementId}`}
        strategy="afterInteractive"
      />
      <Script id="ga-init" strategy="afterInteractive">
        {`
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          gtag('js', new Date());
          gtag('config', '${measurementId}');
        `}
      </Script>
    </>
  );
}
