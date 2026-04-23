import { apiGet, apiPost, apiPut, apiDelete } from "./client";
import type {
  Announcement,
  AnnouncementsResponse,
  CreateAnnouncementRequest,
  UpdateAnnouncementRequest,
} from "./types";

export function fetchAnnouncements(
  limit: number,
  offset: number,
): Promise<AnnouncementsResponse> {
  return apiGet<AnnouncementsResponse>(
    `/announcements?limit=${limit}&offset=${offset}`,
  );
}

export function fetchAnnouncement(id: number): Promise<Announcement> {
  return apiGet<Announcement>(`/announcements/${id}`);
}

export function createAnnouncement(
  data: CreateAnnouncementRequest,
): Promise<Announcement> {
  return apiPost<Announcement>("/announcements", data);
}

export function updateAnnouncement(
  id: number,
  data: UpdateAnnouncementRequest,
): Promise<Announcement> {
  return apiPut<Announcement>(`/announcements/${id}`, data);
}

export function deleteAnnouncement(id: number): Promise<void> {
  return apiDelete(`/announcements/${id}`);
}
