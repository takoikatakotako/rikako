"use client";

import { useUser } from "@/hooks/use-users";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

interface UserDetailProps {
  id: number;
}

function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleDateString("ja-JP", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function UserDetail({ id }: UserDetailProps) {
  const { data, error, isLoading } = useUser(id);

  if (isLoading) return <p className="text-muted-foreground">読み込み中...</p>;
  if (error) return <p className="text-destructive">エラーが発生しました</p>;
  if (!data) return null;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">ユーザー詳細</h1>

      <Card>
        <CardHeader>
          <CardTitle>基本情報</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="grid grid-cols-[120px_1fr] gap-2 text-sm">
            <span className="text-muted-foreground">ID</span>
            <span>{data.id}</span>
            <span className="text-muted-foreground">Identity ID</span>
            <span className="font-mono">{data.identityId}</span>
            <span className="text-muted-foreground">表示名</span>
            <span>{data.displayName || "-"}</span>
            <span className="text-muted-foreground">登録日</span>
            <span>{formatDate(data.createdAt)}</span>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>アプリ設定</CardTitle>
        </CardHeader>
        <CardContent>
          {data.appSettings.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              アプリ設定がありません
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>アプリ</TableHead>
                  <TableHead>Slug</TableHead>
                  <TableHead>選択中の問題集ID</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.appSettings.map((setting) => (
                  <TableRow key={setting.appSlug}>
                    <TableCell>{setting.appTitle}</TableCell>
                    <TableCell className="font-mono text-sm">
                      {setting.appSlug}
                    </TableCell>
                    <TableCell>
                      {setting.selectedWorkbookId ?? "-"}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
