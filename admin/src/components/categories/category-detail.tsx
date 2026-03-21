"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCategory } from "@/hooks/use-categories";
import { deleteCategory } from "@/lib/api/categories";
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

export function CategoryDetail({ id }: { id: number }) {
  const { data: category, error, isLoading } = useCategory(id);
  const router = useRouter();
  const [deleting, setDeleting] = useState(false);

  async function handleDelete() {
    setDeleting(true);
    try {
      await deleteCategory(id);
      toast.success("カテゴリを削除しました");
      router.push("/categories");
    } catch {
      toast.error("カテゴリの削除に失敗しました");
      setDeleting(false);
    }
  }

  if (isLoading) return <p className="text-muted-foreground">読み込み中...</p>;
  if (error) return <p className="text-destructive">エラーが発生しました</p>;
  if (!category) return null;

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">カテゴリ詳細</h1>
        <div className="flex gap-2">
          <Link href={`/categories/${id}/edit`} className={buttonVariants({ variant: "outline" })}>
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
                <AlertDialogTitle>カテゴリを削除しますか？</AlertDialogTitle>
                <AlertDialogDescription>
                  この操作は取り消せません。カテゴリに属する問題集のカテゴリ設定が解除されます。
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
          <CardTitle>{category.title}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {category.description && (
            <div>
              <p className="text-sm font-medium text-muted-foreground">説明</p>
              <p className="mt-1 whitespace-pre-wrap">
                {category.description}
              </p>
            </div>
          )}

          <div>
            <p className="text-sm font-medium text-muted-foreground">
              問題集 ({category.workbooks.length}件)
            </p>
            {category.workbooks.length > 0 ? (
              <Table className="mt-2">
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-16">ID</TableHead>
                    <TableHead>タイトル</TableHead>
                    <TableHead className="w-24">問題数</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {category.workbooks.map((wb) => (
                    <TableRow key={wb.id}>
                      <TableCell>{wb.id}</TableCell>
                      <TableCell>
                        <Link
                          href={`/workbooks/${wb.id}`}
                          className="hover:underline"
                        >
                          {wb.title}
                        </Link>
                      </TableCell>
                      <TableCell>
                        <Badge variant="secondary">
                          {wb.questionCount ?? 0}
                        </Badge>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            ) : (
              <p className="mt-2 text-sm text-muted-foreground">
                問題集が登録されていません
              </p>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
