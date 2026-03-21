"use client";

import { useRouter } from "next/navigation";
import { useCategory } from "@/hooks/use-categories";
import { updateCategory } from "@/lib/api/categories";
import { CategoryForm } from "@/components/categories/category-form";
import { toast } from "sonner";

export function CategoryEdit({ id }: { id: number }) {
  const { data: category, error, isLoading } = useCategory(id);
  const router = useRouter();

  if (isLoading) return <p className="text-muted-foreground">読み込み中...</p>;
  if (error) return <p className="text-destructive">エラーが発生しました</p>;
  if (!category) return null;

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <h1 className="text-2xl font-bold">カテゴリ編集</h1>
      <CategoryForm
        defaultValues={category}
        submitLabel="更新"
        onSubmit={async (data) => {
          try {
            await updateCategory(id, data);
            toast.success("カテゴリを更新しました");
            router.push(`/categories/${id}`);
          } catch {
            toast.error("カテゴリの更新に失敗しました");
          }
        }}
      />
    </div>
  );
}
