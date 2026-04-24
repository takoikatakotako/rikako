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
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

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
          <div className="text-sm leading-relaxed">
            <ReactMarkdown
              remarkPlugins={[remarkGfm]}
              components={{
                h1: (props) => <h1 className="mt-4 mb-2 text-xl font-bold" {...props} />,
                h2: (props) => <h2 className="mt-4 mb-2 text-lg font-bold" {...props} />,
                h3: (props) => <h3 className="mt-3 mb-2 text-base font-bold" {...props} />,
                p: (props) => <p className="my-2" {...props} />,
                ul: (props) => <ul className="my-2 ml-5 list-disc" {...props} />,
                ol: (props) => <ol className="my-2 ml-5 list-decimal" {...props} />,
                li: (props) => <li className="my-0.5" {...props} />,
                a: (props) => <a className="text-blue-600 underline" target="_blank" rel="noreferrer" {...props} />,
                code: (props) => <code className="rounded bg-muted px-1 py-0.5 text-xs" {...props} />,
                blockquote: (props) => <blockquote className="my-2 border-l-4 border-muted pl-3 text-muted-foreground" {...props} />,
                hr: () => <hr className="my-4 border-muted" />,
              }}
            >
              {data.body}
            </ReactMarkdown>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
