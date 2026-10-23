"use client";

import { trackEvent } from "@/lib/analytics";
import { siteConfig } from "@/lib/site";

export function AppDownloadLinks({ placement }: { placement: string }) {
  const stores = [
    { name: "App Store", id: "app_store", url: siteConfig.appStoreUrl },
    { name: "Google Play", id: "google_play", url: siteConfig.playStoreUrl },
  ];

  return (
    <aside className="rounded-2xl border border-brand/30 bg-brand-soft p-5">
      <p className="font-bold text-brand-strong">{siteConfig.appName}をアプリでも</p>
      <p className="mt-1 text-sm text-slate-600">
        間違えた問題の復習や、毎日の学習記録に。
      </p>
      <div className="mt-4 flex flex-wrap gap-3">
        {stores.map((store) => (
          <a
            key={store.id}
            href={store.url}
            target="_blank"
            rel="noopener noreferrer"
            onClick={() =>
              trackEvent("app_store_click", {
                store: store.id,
                placement,
              })
            }
            className="inline-flex items-center justify-center rounded-xl bg-brand px-4 py-2.5 text-sm font-bold text-white transition-colors hover:bg-brand-strong"
          >
            {store.name} で入手 ↗
          </a>
        ))}
      </div>
    </aside>
  );
}
