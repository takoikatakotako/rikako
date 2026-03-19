"use client";

import { useRouter } from "next/navigation";
import { useWorkbook } from "@/hooks/use-workbooks";
import { updateWorkbook } from "@/lib/api/workbooks";
import { WorkbookForm } from "@/components/workbooks/workbook-form";
import { toast } from "sonner";

export function WorkbookEdit({ id }: { id: number }) {
  const workbookId = id;
  const { data: workbook, error, isLoading } = useWorkbook(workbookId);
  const router = useRouter();

  if (isLoading) return <p className="text-muted-foreground">読み込み中...</p>;
  if (error) return <p className="text-destructive">エラーが発生しました</p>;
  if (!workbook) return null;

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <h1 className="text-2xl font-bold">問題集編集</h1>
      <WorkbookForm
        defaultValues={workbook}
        submitLabel="更新"
        onSubmit={async (data) => {
          try {
            await updateWorkbook(workbookId, data);
            toast.success("問題集を更新しました");
            router.push(`/workbooks/${workbookId}`);
          } catch {
            toast.error("問題集の更新に失敗しました");
          }
        }}
      />
    </div>
  );
}
