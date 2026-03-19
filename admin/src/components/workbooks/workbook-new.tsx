"use client";

import { useRouter } from "next/navigation";
import { WorkbookForm } from "@/components/workbooks/workbook-form";
import { createWorkbook } from "@/lib/api/workbooks";
import { toast } from "sonner";

export function WorkbookNew() {
  const router = useRouter();

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <h1 className="text-2xl font-bold">問題集作成</h1>
      <WorkbookForm
        submitLabel="作成"
        onSubmit={async (data) => {
          try {
            const wb = await createWorkbook(data);
            toast.success("問題集を作成しました");
            router.push(`/workbooks/${wb.id}`);
          } catch {
            toast.error("問題集の作成に失敗しました");
          }
        }}
      />
    </div>
  );
}
