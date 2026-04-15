import { apiGet } from "@/lib/api/client";
import type { UsersResponse } from "@/lib/api/types";

export async function fetchUsers(
  limit: number,
  offset: number,
): Promise<UsersResponse> {
  return apiGet<UsersResponse>(`/users?limit=${limit}&offset=${offset}`);
}
