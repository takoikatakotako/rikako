"use client";

import { useState } from "react";
import Link from "next/link";
import { useWorkbooks } from "@/hooks/use-workbooks";
import { WorkbookTable } from "@/components/workbooks/workbook-table";
import { Button, buttonVariants } from "@/components/ui/button";
import { Plus, ChevronLeft, ChevronRight } from "lucide-react";

const PAGE_SIZE = 20;

export function WorkbookList() {
  const [page, setPage] = useState(0);
  const { data, error, isLoading } = useWorkbooks(PAGE_SIZE, page * PAGE_SIZE);

  const totalPages = data ? Math.ceil(data.total / PAGE_SIZE) : 0;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">問題集一覧</h1>
        <Link href="/workbooks/new" className={buttonVariants()}>
          <Plus className="mr-2 h-4 w-4" />
          新規作成
        </Link>
      </div>

      {isLoading && <p className="text-muted-foreground">読み込み中...</p>}
      {error && <p className="text-destructive">エラーが発生しました</p>}

      {data && (
        <>
          {data.workbooks.length === 0 ? (
            <p className="text-muted-foreground">問題集がありません</p>
          ) : (
            <WorkbookTable workbooks={data.workbooks} />
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
