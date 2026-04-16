"use client";

import { useState } from "react";
import { useUsers } from "@/hooks/use-users";
import { UserTable } from "@/components/users/user-table";
import { Button } from "@/components/ui/button";
import { ChevronLeft, ChevronRight } from "lucide-react";

const PAGE_SIZE = 20;

export function UserList() {
  const [page, setPage] = useState(0);
  const { data, error, isLoading } = useUsers(PAGE_SIZE, page * PAGE_SIZE);

  const totalPages = data ? Math.ceil(data.total / PAGE_SIZE) : 0;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">ユーザー一覧</h1>
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
          {data.users.length === 0 ? (
            <p className="text-muted-foreground">ユーザーがいません</p>
          ) : (
            <UserTable users={data.users} />
          )}

          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setPage((p) => Math.max(0, p - 1))}
                disabled={page === 0}
              >
                <ChevronLeft className="h-4 w-4" />
              </Button>
              <span className="text-sm text-muted-foreground">
                {page + 1} / {totalPages}
              </span>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
                disabled={page >= totalPages - 1}
              >
                <ChevronRight className="h-4 w-4" />
              </Button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
