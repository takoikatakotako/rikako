import { apiGet } from "@/lib/api/client";
import type { UsersResponse, UserDetail, UserAnswersResponse } from "@/lib/api/types";

export async function fetchUsers(
  limit: number,
  offset: number,
): Promise<UsersResponse> {
  return apiGet<UsersResponse>(`/users?limit=${limit}&offset=${offset}`);
}

export async function fetchUser(id: number): Promise<UserDetail> {
  return apiGet<UserDetail>(`/users/${id}`);
}

export async function fetchUserAnswers(
  id: number,
  limit: number,
  offset: number,
): Promise<UserAnswersResponse> {
  return apiGet<UserAnswersResponse>(
    `/users/${id}/answers?limit=${limit}&offset=${offset}`,
  );
}
