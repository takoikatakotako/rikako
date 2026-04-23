"use client";

import { useRouter } from "next/navigation";
import { useAnnouncement } from "@/hooks/use-announcements";
import { updateAnnouncement } from "@/lib/api/announcements";
import { AnnouncementForm } from "@/components/announcements/announcement-form";
import { toast } from "sonner";

export function AnnouncementEdit({ id }: { id: number }) {
  const { data, error, isLoading } = useAnnouncement(id);
  const router = useRouter();

  if (isLoading) return <p className="text-muted-foreground">読み込み中...</p>;
  if (error) return <p className="text-destructive">エラーが発生しました</p>;
  if (!data) return null;

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <h1 className="text-2xl font-bold">お知らせ編集</h1>
      <AnnouncementForm
        defaultValues={data}
        submitLabel="更新"
        onSubmit={async (values) => {
          try {
            await updateAnnouncement(id, values);
            toast.success("お知らせを更新しました");
            router.push(`/announcements/${id}`);
          } catch {
            toast.error("お知らせの更新に失敗しました");
          }
        }}
      />
    </div>
  );
}
