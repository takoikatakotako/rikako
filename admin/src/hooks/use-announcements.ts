import useSWR from "swr";
import { fetchAnnouncements, fetchAnnouncement } from "@/lib/api/announcements";
import type { Announcement, AnnouncementsResponse } from "@/lib/api/types";

export function useAnnouncements(limit: number, offset: number) {
  return useSWR<AnnouncementsResponse>(
    [`/announcements`, limit, offset],
    () => fetchAnnouncements(limit, offset),
  );
}

export function useAnnouncement(id: number | null) {
  return useSWR<Announcement>(
    id !== null ? [`/announcements`, id] : null,
    () => fetchAnnouncement(id!),
  );
}
