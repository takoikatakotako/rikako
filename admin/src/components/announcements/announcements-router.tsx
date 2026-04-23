"use client";

import { useRouteSlug } from "@/hooks/use-route-slug";
import { AnnouncementList } from "@/components/announcements/announcement-list";
import { AnnouncementNew } from "@/components/announcements/announcement-new";
import { AnnouncementDetail } from "@/components/announcements/announcement-detail";
import { AnnouncementEdit } from "@/components/announcements/announcement-edit";

export function AnnouncementsRouter() {
  const { slug, mounted } = useRouteSlug("announcements");

  if (!mounted) {
    return <p className="text-muted-foreground">読み込み中...</p>;
  }

  if (!slug || slug.length === 0) {
    return <AnnouncementList />;
  }

  if (slug[0] === "new") {
    return <AnnouncementNew />;
  }

  const id = Number(slug[0]);

  if (slug[1] === "edit") {
    return <AnnouncementEdit id={id} />;
  }

  return <AnnouncementDetail id={id} />;
}
