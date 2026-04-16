import useSWR from "swr";
import { fetchUsers, fetchUser, fetchUserAnswers } from "@/lib/api/users";
import type { UsersResponse, UserDetail, UserAnswersResponse } from "@/lib/api/types";

export function useUsers(limit: number, offset: number) {
  return useSWR<UsersResponse>(
    [`/users`, limit, offset],
    () => fetchUsers(limit, offset),
  );
}

export function useUser(id: number | null) {
  return useSWR<UserDetail>(id !== null ? `/users/${id}` : null, () =>
    fetchUser(id!),
  );
}

export function useUserAnswers(id: number | null, limit: number, offset: number) {
  return useSWR<UserAnswersResponse>(
    id !== null ? [`/users/${id}/answers`, limit, offset] : null,
    () => fetchUserAnswers(id!, limit, offset),
  );
}
