import { apiGet } from "@/lib/api/client";
import type { UsersResponse, UserDetail } from "@/lib/api/types";

export async function fetchUsers(
  limit: number,
  offset: number,
): Promise<UsersResponse> {
  return apiGet<UsersResponse>(`/users?limit=${limit}&offset=${offset}`);
}

export async function fetchUser(id: number): Promise<UserDetail> {
  return apiGet<UserDetail>(`/users/${id}`);
}
