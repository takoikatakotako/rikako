"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAnnouncement } from "@/hooks/use-announcements";
import { deleteAnnouncement } from "@/lib/api/announcements";
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
import { Pencil, Trash2 } from "lucide-react";
import { toast } from "sonner";

function formatDateTime(iso: string) {
  const d = new Date(iso);
  const pad = (n: number) => n.toString().padStart(2, "0");
  return `${d.getFullYear()}/${pad(d.getMonth() + 1)}/${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function categoryLabel(value: string): string {
  switch (value) {
    case "release":
      return "リリース";
    case "maintenance":
      return "メンテナンス";
    case "info":
      return "お知らせ";
    default:
      return value;
  }
}

export function AnnouncementDetail({ id }: { id: number }) {
  const { data, error, isLoading } = useAnnouncement(id);
  const router = useRouter();
  const [deleting, setDeleting] = useState(false);

  async function handleDelete() {
    setDeleting(true);
    try {
      await deleteAnnouncement(id);
      toast.success("お知らせを削除しました");
      router.push("/announcements");
    } catch {
      toast.error("お知らせの削除に失敗しました");
      setDeleting(false);
    }
  }

  if (isLoading) return <p className="text-muted-foreground">読み込み中...</p>;
  if (error) return <p className="text-destructive">エラーが発生しました</p>;
  if (!data) return null;

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">お知らせ詳細</h1>
        <div className="flex gap-2">
          <Link
            href={`/announcements/${id}/edit`}
            className={buttonVariants({ variant: "outline" })}
          >
            <Pencil className="mr-2 h-4 w-4" />
            編集
          </Link>
          <AlertDialog>
            <AlertDialogTrigger
              render={<Button variant="destructive" disabled={deleting} />}
            >
              <Trash2 className="mr-2 h-4 w-4" />
              削除
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>お知らせを削除しますか？</AlertDialogTitle>
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
          <div className="flex items-center gap-2">
            <Badge variant="secondary">{categoryLabel(data.category)}</Badge>
            <span className="text-sm text-muted-foreground">
              {formatDateTime(data.publishedAt)}
            </span>
          </div>
          <CardTitle className="mt-2">{data.title}</CardTitle>
        </CardHeader>
        <CardContent>
          <pre className="whitespace-pre-wrap font-sans text-sm leading-relaxed">
            {data.body}
          </pre>
        </CardContent>
      </Card>
    </div>
  );
}
