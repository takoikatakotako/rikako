"use client";

import { useRouter } from "next/navigation";
import { useQuestion } from "@/hooks/use-questions";
import { updateQuestion } from "@/lib/api/questions";
import { QuestionForm } from "@/components/questions/question-form";
import { toast } from "sonner";

export function QuestionEdit({ id }: { id: number }) {
  const questionId = id;
  const { data: question, error, isLoading } = useQuestion(questionId);
  const router = useRouter();

  if (isLoading) return <p className="text-muted-foreground">読み込み中...</p>;
  if (error) return <p className="text-destructive">エラーが発生しました</p>;
  if (!question) return null;

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <h1 className="text-2xl font-bold">問題編集</h1>
      <QuestionForm
        defaultValues={question}
        submitLabel="更新"
        onSubmit={async (data) => {
          try {
            await updateQuestion(questionId, data);
            toast.success("問題を更新しました");
            router.push(`/questions/${questionId}`);
          } catch {
            toast.error("問題の更新に失敗しました");
          }
        }}
      />
    </div>
  );
}
