"use client";

import { useEffect, useState } from "react";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { fetchAppStatus, updateAppStatus } from "@/lib/api/app-status";
import type { AppStatus } from "@/lib/api/types";

function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleString("ja-JP", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function AppStatusForm() {
  const [status, setStatus] = useState<AppStatus | null>(null);
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchAppStatus()
      .then((data) => {
        setStatus(data);
        setMessage(data.maintenanceMessage);
      })
      .catch(() => toast.error("ステータスの取得に失敗しました"))
      .finally(() => setLoading(false));
  }, []);

  const handleToggle = async () => {
    if (!status) return;
    setSaving(true);
    try {
      const updated = await updateAppStatus({
        isMaintenance: !status.isMaintenance,
        maintenanceMessage: message,
      });
      setStatus(updated);
      setMessage(updated.maintenanceMessage);
      toast.success(
        updated.isMaintenance
          ? "メンテナンスモードを有効にしました"
          : "メンテナンスモードを解除しました",
      );
    } catch {
      toast.error("更新に失敗しました");
    } finally {
      setSaving(false);
    }
  };

  const handleSaveMessage = async () => {
    if (!status) return;
    setSaving(true);
    try {
      const updated = await updateAppStatus({
        isMaintenance: status.isMaintenance,
        maintenanceMessage: message,
      });
      setStatus(updated);
      toast.success("メッセージを保存しました");
    } catch {
      toast.error("更新に失敗しました");
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center gap-2 text-muted-foreground">
        <Loader2 className="h-4 w-4 animate-spin" />
        読み込み中...
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">アプリステータス</h1>

      <Card>
        <CardHeader>
          <CardTitle>メンテナンスモード</CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="flex items-center justify-between">
            <div className="space-y-1">
              <p className="text-sm font-medium">現在の状態</p>
              <div className="flex items-center gap-2">
                <span
                  className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                    status?.isMaintenance
                      ? "bg-destructive/10 text-destructive"
                      : "bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400"
                  }`}
                >
                  {status?.isMaintenance ? "メンテナンス中" : "通常運転"}
                </span>
                {status?.updatedAt && (
                  <span className="text-xs text-muted-foreground">
                    最終更新: {formatDate(status.updatedAt)}
                  </span>
                )}
              </div>
            </div>
            <Button
              variant={status?.isMaintenance ? "outline" : "destructive"}
              onClick={handleToggle}
              disabled={saving}
            >
              {saving && <Loader2 className="animate-spin" />}
              {status?.isMaintenance ? "メンテナンス解除" : "メンテナンス開始"}
            </Button>
          </div>

          <div className="space-y-2">
            <Label htmlFor="maintenance-message">メンテナンスメッセージ</Label>
            <Textarea
              id="maintenance-message"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder="メンテナンス中に表示するメッセージ"
              rows={3}
            />
            <Button
              variant="outline"
              size="sm"
              onClick={handleSaveMessage}
              disabled={saving}
            >
              {saving && <Loader2 className="animate-spin" />}
              メッセージを保存
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
