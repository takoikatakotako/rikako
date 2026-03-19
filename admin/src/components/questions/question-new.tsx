"use client";

import { useRouter } from "next/navigation";
import { QuestionForm } from "@/components/questions/question-form";
import { createQuestion } from "@/lib/api/questions";
import { toast } from "sonner";

export function QuestionNew() {
  const router = useRouter();

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <h1 className="text-2xl font-bold">問題作成</h1>
      <QuestionForm
        submitLabel="作成"
        onSubmit={async (data) => {
          try {
            const q = await createQuestion(data);
            toast.success("問題を作成しました");
            router.push(`/questions/${q.id}`);
          } catch {
            toast.error("問題の作成に失敗しました");
          }
        }}
      />
    </div>
  );
}
