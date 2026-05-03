"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { QuestionPicker } from "./question-picker";
import { Loader2 } from "lucide-react";
import { useCategories } from "@/hooks/use-categories";
import type { WorkbookDetail, Question } from "@/lib/api/types";

const schema = z.object({
  title: z.string().min(1, "タイトルを入力してください"),
  description: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

interface WorkbookFormProps {
  defaultValues?: WorkbookDetail;
  defaultCategoryId?: number;
  onSubmit: (data: {
    title: string;
    description?: string;
    categoryId?: number;
    isPublished?: boolean;
    questionIds?: number[];
  }) => Promise<void>;
  submitLabel: string;
}

export function WorkbookForm({
  defaultValues,
  defaultCategoryId,
  onSubmit,
  submitLabel,
}: WorkbookFormProps) {
  const [selectedIds, setSelectedIds] = useState<number[]>(
    defaultValues?.questions.map((q) => q.id) ?? [],
  );
  const [selectedQuestions, setSelectedQuestions] = useState<Question[]>(
    defaultValues?.questions ?? [],
  );
  const [categoryId, setCategoryId] = useState<number | undefined>(
    defaultCategoryId,
  );
  const [isPublished, setIsPublished] = useState<boolean>(
    defaultValues?.isPublished ?? true,
  );
  const [submitting, setSubmitting] = useState(false);
  const { data: categoriesData } = useCategories(100, 0);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      title: defaultValues?.title ?? "",
      description: defaultValues?.description ?? "",
    },
  });

  async function onFormSubmit(values: FormValues) {
    setSubmitting(true);
    try {
      await onSubmit({
        title: values.title,
        description: values.description || undefined,
        categoryId: categoryId,
        isPublished: isPublished,
        questionIds: selectedIds.length > 0 ? selectedIds : undefined,
      });
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit(onFormSubmit)} className="space-y-6">
      <div className="space-y-2">
        <Label htmlFor="title">タイトル</Label>
        <Input
          id="title"
          {...register("title")}
          placeholder="問題集タイトル"
        />
        {errors.title && (
          <p className="text-sm text-destructive">{errors.title.message}</p>
        )}
      </div>

      <div className="space-y-2">
        <Label htmlFor="description">説明（任意）</Label>
        <Textarea
          id="description"
          {...register("description")}
          placeholder="問題集の説明"
          rows={3}
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="categoryId">カテゴリ（任意）</Label>
        <select
          id="categoryId"
          className="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm transition-colors placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
          value={categoryId ?? ""}
          onChange={(e) =>
            setCategoryId(e.target.value ? Number(e.target.value) : undefined)
          }
        >
          <option value="">なし</option>
          {categoriesData?.categories.map((cat) => (
            <option key={cat.id} value={cat.id}>
              {cat.title}
            </option>
          ))}
        </select>
      </div>

      <div className="flex items-center gap-3">
        <input
          id="isPublished"
          type="checkbox"
          checked={isPublished}
          onChange={(e) => setIsPublished(e.target.checked)}
          className="h-4 w-4 rounded border-input accent-primary"
        />
        <Label htmlFor="isPublished">公開する</Label>
      </div>

      <div className="space-y-2">
        <Label>問題</Label>
        <QuestionPicker
          selectedIds={selectedIds}
          onChange={setSelectedIds}
          selectedQuestions={selectedQuestions}
          onSelectedQuestionsChange={setSelectedQuestions}
        />
      </div>

      <div className="flex justify-end gap-2">
        <Button type="submit" disabled={submitting}>
          {submitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
          {submitLabel}
        </Button>
      </div>
    </form>
  );
}
