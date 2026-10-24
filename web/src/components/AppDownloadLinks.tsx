"use client";

import { trackEvent } from "@/lib/analytics";
import { siteConfig } from "@/lib/site";

export function AppDownloadLinks({ placement }: { placement: string }) {
  const stores = [
    {
      name: "App Store",
      id: "app_store",
      url: siteConfig.appStoreUrl,
      badge: "/images/app-store-badge-ja.svg",
      width: 109,
      height: 40,
    },
    {
      name: "Google Play",
      id: "google_play",
      url: siteConfig.playStoreUrl,
      badge: "/images/google-play-badge-ja.png",
      width: 134,
      height: 52,
    },
  ];

  return (
    <aside className="rounded-2xl border border-brand/30 bg-brand-soft p-5">
      <p className="font-bold text-brand-strong">{siteConfig.appName}をアプリでも</p>
      <p className="mt-1 text-sm text-slate-600">
        間違えた問題の復習や、毎日の学習記録に。
      </p>
      <div className="mt-4 flex flex-wrap items-center gap-x-3 gap-y-1">
        {stores.map((store) => (
          <a
            key={store.id}
            href={store.url}
            target="_blank"
            rel="noopener noreferrer"
            aria-label={`${siteConfig.appName}を${store.name}で入手`}
            onClick={() =>
              trackEvent("app_store_click", {
                store: store.id,
                placement,
              })
            }
            className="inline-flex items-center focus-visible:rounded-md focus-visible:outline-3 focus-visible:outline-offset-3 focus-visible:outline-brand-strong"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={store.badge}
              alt=""
              width={store.width}
              height={store.height}
              className="w-auto max-w-none"
              style={{ height: store.height }}
            />
          </a>
        ))}
      </div>
    </aside>
  );
}
