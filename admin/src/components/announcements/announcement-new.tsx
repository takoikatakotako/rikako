"use client";

import { useRouter } from "next/navigation";
import { AnnouncementForm } from "@/components/announcements/announcement-form";
import { createAnnouncement } from "@/lib/api/announcements";
import { toast } from "sonner";

export function AnnouncementNew() {
  const router = useRouter();

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <h1 className="text-2xl font-bold">お知らせ作成</h1>
      <AnnouncementForm
        submitLabel="作成"
        onSubmit={async (data) => {
          try {
            const a = await createAnnouncement(data);
            toast.success("お知らせを作成しました");
            router.push(`/announcements/${a.id}`);
          } catch {
            toast.error("お知らせの作成に失敗しました");
          }
        }}
      />
    </div>
  );
}
