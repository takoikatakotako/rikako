"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { ChoiceEditor } from "./choice-editor";
import { ImageUploader } from "@/components/images/image-uploader";
import type { Question, Choice } from "@/lib/api/types";
import { useState } from "react";
import { Loader2 } from "lucide-react";

const schema = z.object({
  text: z.string().min(1, "問題文を入力してください"),
  explanation: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

interface UploadedImage {
  imageId: number;
  cdnUrl: string;
}

interface QuestionFormProps {
  defaultValues?: Question;
  onSubmit: (data: {
    type: "single_choice";
    text: string;
    choices: Choice[];
    explanation?: string;
    imageIds?: number[];
  }) => Promise<void>;
  submitLabel: string;
}

export function QuestionForm({
  defaultValues,
  onSubmit,
  submitLabel,
}: QuestionFormProps) {
  const [choices, setChoices] = useState<Choice[]>(
    (defaultValues?.choices?.length ? defaultValues.choices : null) ?? [
      { text: "", isCorrect: true },
      { text: "", isCorrect: false },
    ],
  );
  const [images, setImages] = useState<UploadedImage[]>(
    defaultValues?.images?.map((url, i) => ({
      imageId: i,
      cdnUrl: url,
    })) ?? [],
  );
  const [submitting, setSubmitting] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      text: defaultValues?.text ?? "",
      explanation: defaultValues?.explanation ?? "",
    },
  });

  async function onFormSubmit(values: FormValues) {
    if (!choices.some((c) => c.isCorrect)) return;
    if (choices.some((c) => c.text.trim() === "")) return;

    setSubmitting(true);
    try {
      await onSubmit({
        type: "single_choice",
        text: values.text,
        choices,
        explanation: values.explanation || undefined,
        imageIds:
          images.length > 0 ? images.map((img) => img.imageId) : undefined,
      });
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit(onFormSubmit)} className="space-y-6">
      <div className="space-y-2">
        <Label htmlFor="text">問題文</Label>
        <Textarea
          id="text"
          {...register("text")}
          placeholder="問題文を入力"
          rows={4}
        />
        {errors.text && (
          <p className="text-sm text-destructive">{errors.text.message}</p>
        )}
      </div>

      <ChoiceEditor choices={choices} onChange={setChoices} />

      <div className="space-y-2">
        <Label htmlFor="explanation">解説（任意）</Label>
        <Textarea
          id="explanation"
          {...register("explanation")}
          placeholder="解説を入力"
          rows={3}
        />
      </div>

      <div className="space-y-2">
        <Label>画像（任意）</Label>
        <ImageUploader images={images} onChange={setImages} />
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
