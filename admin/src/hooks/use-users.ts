import useSWR from "swr";
import { fetchUsers, fetchUser } from "@/lib/api/users";
import type { UsersResponse, UserDetail } from "@/lib/api/types";

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
