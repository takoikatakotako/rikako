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
import type { Announcement } from "@/lib/api/types";

const schema = z.object({
  title: z.string().min(1, "タイトルを入力してください"),
  body: z.string().min(1, "本文を入力してください"),
  category: z.string().min(1, "種別を選択してください"),
  publishedAt: z.string().min(1, "公開日時を入力してください"),
});

type FormValues = z.infer<typeof schema>;

const CATEGORIES = [
  { value: "info", label: "お知らせ" },
  { value: "release", label: "リリース" },
  { value: "maintenance", label: "メンテナンス" },
];

interface AnnouncementFormProps {
  defaultValues?: Announcement;
  onSubmit: (data: {
    title: string;
    body: string;
    category: string;
    publishedAt: string;
  }) => Promise<void>;
  submitLabel: string;
}

function toLocalDateTimeInput(iso: string | undefined): string {
  const d = iso ? new Date(iso) : new Date();
  const pad = (n: number) => n.toString().padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function AnnouncementForm({
  defaultValues,
  onSubmit,
  submitLabel,
}: AnnouncementFormProps) {
  const [submitting, setSubmitting] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      title: defaultValues?.title ?? "",
      body: defaultValues?.body ?? "",
      category: defaultValues?.category ?? "info",
      publishedAt: toLocalDateTimeInput(defaultValues?.publishedAt),
    },
  });

  async function onFormSubmit(values: FormValues) {
    setSubmitting(true);
    try {
      await onSubmit({
        title: values.title,
        body: values.body,
        category: values.category,
        publishedAt: new Date(values.publishedAt).toISOString(),
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
          placeholder="お知らせのタイトル"
        />
        {errors.title && (
          <p className="text-sm text-destructive">{errors.title.message}</p>
        )}
      </div>

      <div className="space-y-2">
        <Label htmlFor="category">種別</Label>
        <select
          id="category"
          {...register("category")}
          className="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm"
        >
          {CATEGORIES.map((c) => (
            <option key={c.value} value={c.value}>
              {c.label}
            </option>
          ))}
        </select>
        {errors.category && (
          <p className="text-sm text-destructive">{errors.category.message}</p>
        )}
      </div>

      <div className="space-y-2">
        <Label htmlFor="publishedAt">公開日時</Label>
        <Input
          id="publishedAt"
          type="datetime-local"
          {...register("publishedAt")}
        />
        {errors.publishedAt && (
          <p className="text-sm text-destructive">{errors.publishedAt.message}</p>
        )}
      </div>

      <div className="space-y-2">
        <Label htmlFor="body">本文（Markdown）</Label>
        <Textarea
          id="body"
          {...register("body")}
          placeholder="Markdown で記述できます"
          rows={12}
          className="font-mono"
        />
        {errors.body && (
          <p className="text-sm text-destructive">{errors.body.message}</p>
        )}
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
