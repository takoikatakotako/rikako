import { apiGet, apiPut } from "@/lib/api/client";
import type { AppStatus, UpdateAppStatusRequest } from "@/lib/api/types";

export async function fetchAppStatus(): Promise<AppStatus> {
  return apiGet<AppStatus>("/app-status");
}

export async function updateAppStatus(
  data: UpdateAppStatusRequest,
): Promise<AppStatus> {
  return apiPut<AppStatus>("/app-status", data);
}
