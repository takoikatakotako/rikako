"use client";

import { useRouter } from "next/navigation";
import { CategoryForm } from "@/components/categories/category-form";
import { createCategory } from "@/lib/api/categories";
import { toast } from "sonner";

export function CategoryNew() {
  const router = useRouter();

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <h1 className="text-2xl font-bold">カテゴリ作成</h1>
      <CategoryForm
        submitLabel="作成"
        onSubmit={async (data) => {
          try {
            const cat = await createCategory(data);
            toast.success("カテゴリを作成しました");
            router.push(`/categories/${cat.id}`);
          } catch {
            toast.error("カテゴリの作成に失敗しました");
          }
        }}
      />
    </div>
  );
}
