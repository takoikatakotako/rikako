"use client";

import { useApps } from "@/hooks/use-apps";
import { AppTable } from "@/components/apps/app-table";

export function AppList() {
  const { data, error, isLoading } = useApps();

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">アプリ一覧</h1>
        {data && (
          <span className="text-sm text-muted-foreground">
            全 {data.total} 件
          </span>
        )}
      </div>

      {isLoading && <p className="text-muted-foreground">読み込み中...</p>}
      {error && <p className="text-destructive">エラーが発生しました</p>}

      {data && (
        <>
          {data.apps.length === 0 ? (
            <p className="text-muted-foreground">アプリがありません</p>
          ) : (
            <AppTable apps={data.apps} />
          )}
        </>
      )}
    </div>
  );
}
