import useSWR from "swr";
import { fetchWorkbooks, fetchWorkbook } from "@/lib/api/workbooks";
import type { WorkbooksResponse, WorkbookDetail } from "@/lib/api/types";

export function useWorkbooks(limit: number, offset: number) {
  return useSWR<WorkbooksResponse>(
    [`/workbooks`, limit, offset],
    () => fetchWorkbooks(limit, offset),
  );
}

export function useWorkbook(id: number | null) {
  return useSWR<WorkbookDetail>(
    id !== null ? [`/workbooks`, id] : null,
    () => fetchWorkbook(id!),
  );
}
