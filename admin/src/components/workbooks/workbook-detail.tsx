"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useWorkbook } from "@/hooks/use-workbooks";
import { deleteWorkbook } from "@/lib/api/workbooks";
import { Button, buttonVariants } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
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
import { Pencil, Trash2 } from "lucide-react";
import { toast } from "sonner";

export function WorkbookDetail({ id }: { id: number }) {
  const workbookId = id;
  const { data: workbook, error, isLoading } = useWorkbook(workbookId);
  const router = useRouter();
  const [deleting, setDeleting] = useState(false);

  async function handleDelete() {
    setDeleting(true);
    try {
      await deleteWorkbook(workbookId);
      toast.success("問題集を削除しました");
      router.push("/workbooks");
    } catch {
      toast.error("問題集の削除に失敗しました");
      setDeleting(false);
    }
  }

  if (isLoading) return <p className="text-muted-foreground">読み込み中...</p>;
  if (error) return <p className="text-destructive">エラーが発生しました</p>;
  if (!workbook) return null;

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">問題集詳細</h1>
        <div className="flex gap-2">
          <Link href={`/workbooks/${workbookId}/edit`} className={buttonVariants({ variant: "outline" })}>
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
                <AlertDialogTitle>問題集を削除しますか？</AlertDialogTitle>
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
          <CardTitle>{workbook.title}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {workbook.description && (
            <div>
              <p className="text-sm font-medium text-muted-foreground">説明</p>
              <p className="mt-1 whitespace-pre-wrap">
                {workbook.description}
              </p>
            </div>
          )}

          <div>
            <p className="text-sm font-medium text-muted-foreground">
              問題 ({workbook.questions.length}件)
            </p>
            {workbook.questions.length > 0 ? (
              <Table className="mt-2">
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-16">ID</TableHead>
                    <TableHead>問題文</TableHead>
                    <TableHead className="w-24">選択肢数</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {workbook.questions.map((q) => (
                    <TableRow key={q.id}>
                      <TableCell>{q.id}</TableCell>
                      <TableCell>
                        <Link
                          href={`/questions/${q.id}`}
                          className="hover:underline"
                        >
                          {q.text.length > 60
                            ? `${q.text.slice(0, 60)}...`
                            : q.text}
                        </Link>
                      </TableCell>
                      <TableCell>
                        <Badge variant="secondary">
                          {q.choices?.length ?? 0}
                        </Badge>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            ) : (
              <p className="mt-2 text-sm text-muted-foreground">
                問題が登録されていません
              </p>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
