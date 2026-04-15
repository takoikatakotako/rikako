import useSWR from "swr";
import { fetchUsers } from "@/lib/api/users";
import type { UsersResponse } from "@/lib/api/types";

export function useUsers(limit: number, offset: number) {
  return useSWR<UsersResponse>(
    [`/users`, limit, offset],
    () => fetchUsers(limit, offset),
  );
}
