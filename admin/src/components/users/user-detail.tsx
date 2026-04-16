"use client";

import { useState } from "react";
import { useUser, useUserAnswers } from "@/hooks/use-users";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { ChevronLeft, ChevronRight } from "lucide-react";

interface UserDetailProps {
  id: number;
}

const PAGE_SIZE = 20;

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
  const [answersPage, setAnswersPage] = useState(0);
  const { data, error, isLoading } = useUser(id);
  const {
    data: answersData,
    error: answersError,
    isLoading: answersLoading,
  } = useUserAnswers(id, PAGE_SIZE, answersPage * PAGE_SIZE);

  if (isLoading) return <p className="text-muted-foreground">読み込み中...</p>;
  if (error) return <p className="text-destructive">エラーが発生しました</p>;
  if (!data) return null;

  const totalAnswersPages = answersData
    ? Math.ceil(answersData.total / PAGE_SIZE)
    : 0;

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

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>回答ログ</CardTitle>
          {answersData && (
            <span className="text-sm text-muted-foreground font-normal">
              全 {answersData.total} 件
            </span>
          )}
        </CardHeader>
        <CardContent>
          {answersLoading && (
            <p className="text-sm text-muted-foreground">読み込み中...</p>
          )}
          {answersError && (
            <p className="text-sm text-destructive">エラーが発生しました</p>
          )}
          {answersData && answersData.answers.length === 0 && (
            <p className="text-sm text-muted-foreground">回答ログがありません</p>
          )}
          {answersData && answersData.answers.length > 0 && (
            <>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>結果</TableHead>
                    <TableHead>問題</TableHead>
                    <TableHead>問題集</TableHead>
                    <TableHead>選択肢</TableHead>
                    <TableHead>回答日時</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {answersData.answers.map((answer) => (
                    <TableRow key={answer.id}>
                      <TableCell>
                        <Badge variant={answer.isCorrect ? "default" : "destructive"}>
                          {answer.isCorrect ? "正解" : "不正解"}
                        </Badge>
                      </TableCell>
                      <TableCell className="max-w-xs truncate">
                        {answer.questionText}
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {answer.workbookTitle}
                      </TableCell>
                      <TableCell className="text-sm">
                        {answer.selectedChoice + 1}番
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground whitespace-nowrap">
                        {formatDate(answer.answeredAt)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>

              {totalAnswersPages > 1 && (
                <div className="flex items-center justify-center gap-2 mt-4">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setAnswersPage((p) => Math.max(0, p - 1))}
                    disabled={answersPage === 0}
                  >
                    <ChevronLeft className="h-4 w-4" />
                  </Button>
                  <span className="text-sm text-muted-foreground">
                    {answersPage + 1} / {totalAnswersPages}
                  </span>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() =>
                      setAnswersPage((p) =>
                        Math.min(totalAnswersPages - 1, p + 1),
                      )
                    }
                    disabled={answersPage >= totalAnswersPages - 1}
                  >
                    <ChevronRight className="h-4 w-4" />
                  </Button>
                </div>
              )}
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
