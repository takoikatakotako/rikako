"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useQuestion } from "@/hooks/use-questions";
import { deleteQuestion } from "@/lib/api/questions";
import { Button, buttonVariants } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Pencil, Trash2, Check, X } from "lucide-react";
import { toast } from "sonner";

export function QuestionDetail({ id }: { id: number }) {
  const questionId = id;
  const { data: question, error, isLoading } = useQuestion(questionId);
  const router = useRouter();
  const [deleting, setDeleting] = useState(false);

  async function handleDelete() {
    setDeleting(true);
    try {
      await deleteQuestion(questionId);
      toast.success("問題を削除しました");
      router.push("/questions");
    } catch {
      toast.error("問題の削除に失敗しました");
      setDeleting(false);
    }
  }

  if (isLoading) return <p className="text-muted-foreground">読み込み中...</p>;
  if (error) return <p className="text-destructive">エラーが発生しました</p>;
  if (!question) return null;

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">問題詳細</h1>
        <div className="flex gap-2">
          <Link href={`/questions/${questionId}/edit`} className={buttonVariants({ variant: "outline" })}>
            <Pencil className="mr-2 h-4 w-4" />
            編集
          </Link>
          <AlertDialog>
            <AlertDialogTrigger render={<Button variant="destructive" disabled={deleting} />}>
              <Trash2 className="mr-2 h-4 w-4" />
              削除
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>問題を削除しますか？</AlertDialogTitle>
                <AlertDialogDescription>
                  この操作は取り消せません。
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>キャンセル</AlertDialogCancel>
                <AlertDialogAction onClick={handleDelete}>
                  削除
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">ID: {question.id}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <p className="text-sm font-medium text-muted-foreground">問題文</p>
            <p className="mt-1 whitespace-pre-wrap">{question.text}</p>
          </div>

          <div>
            <p className="text-sm font-medium text-muted-foreground">選択肢</p>
            <ul className="mt-1 space-y-1">
              {(question.choices ?? []).map((choice, i) => (
                <li key={i} className="flex items-center gap-2">
                  {choice.isCorrect ? (
                    <Check className="h-4 w-4 text-green-600" />
                  ) : (
                    <X className="h-4 w-4 text-muted-foreground" />
                  )}
                  <span>{choice.text}</span>
                  {choice.isCorrect && (
                    <Badge variant="default" className="ml-1">
                      正解
                    </Badge>
                  )}
                </li>
              ))}
            </ul>
          </div>

          {question.explanation && (
            <div>
              <p className="text-sm font-medium text-muted-foreground">解説</p>
              <p className="mt-1 whitespace-pre-wrap">
                {question.explanation}
              </p>
            </div>
          )}

          {question.images && question.images.length > 0 && (
            <div>
              <p className="text-sm font-medium text-muted-foreground">画像</p>
              <div className="mt-2 grid grid-cols-3 gap-2">
                {question.images.map((url, i) => (
                  <img
                    key={i}
                    src={url}
                    alt=""
                    className="rounded-md border object-cover"
                  />
                ))}
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
