import { apiGet, apiPost, apiPut, apiDelete } from "@/lib/api/client";
import type { App, AppsResponse, CreateAppRequest } from "@/lib/api/types";

export async function fetchApps(): Promise<AppsResponse> {
  return apiGet<AppsResponse>("/apps");
}

export async function fetchApp(id: number): Promise<App> {
  return apiGet<App>(`/apps/${id}`);
}

export async function createApp(data: CreateAppRequest): Promise<App> {
  return apiPost<App>("/apps", data);
}

export async function updateApp(
  id: number,
  data: CreateAppRequest,
): Promise<App> {
  return apiPut<App>(`/apps/${id}`, data);
}

export async function deleteApp(id: number): Promise<void> {
  return apiDelete(`/apps/${id}`);
}
