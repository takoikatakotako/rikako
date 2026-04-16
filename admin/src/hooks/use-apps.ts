import useSWR from "swr";
import { fetchApps, fetchApp } from "@/lib/api/apps";
import type { AppsResponse, App } from "@/lib/api/types";

export function useApps() {
  return useSWR<AppsResponse>("/apps", () => fetchApps());
}

export function useApp(id: number | null) {
  return useSWR<App>(id !== null ? `/apps/${id}` : null, () =>
    fetchApp(id!),
  );
}
