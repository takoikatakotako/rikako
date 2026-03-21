"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Loader2 } from "lucide-react";
import type { CategoryDetail } from "@/lib/api/types";

const schema = z.object({
  title: z.string().min(1, "タイトルを入力してください"),
  description: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

interface CategoryFormProps {
  defaultValues?: CategoryDetail;
  onSubmit: (data: {
    title: string;
    description?: string;
  }) => Promise<void>;
  submitLabel: string;
}

export function CategoryForm({
  defaultValues,
  onSubmit,
  submitLabel,
}: CategoryFormProps) {
  const [submitting, setSubmitting] = useState(false);

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
          placeholder="カテゴリタイトル"
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
          placeholder="カテゴリの説明"
          rows={3}
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
