import { apiGet, apiPost, apiPut, apiDelete } from "./client";
import type {
  WorkbooksResponse,
  WorkbookDetail,
  CreateWorkbookRequest,
  UpdateWorkbookRequest,
} from "./types";

export function fetchWorkbooks(
  limit: number,
  offset: number,
): Promise<WorkbooksResponse> {
  return apiGet<WorkbooksResponse>(
    `/workbooks?limit=${limit}&offset=${offset}`,
  );
}

export function fetchWorkbook(id: number): Promise<WorkbookDetail> {
  return apiGet<WorkbookDetail>(`/workbooks/${id}`);
}

export function createWorkbook(
  data: CreateWorkbookRequest,
): Promise<WorkbookDetail> {
  return apiPost<WorkbookDetail>("/workbooks", data);
}

export function updateWorkbook(
  id: number,
  data: UpdateWorkbookRequest,
): Promise<WorkbookDetail> {
  return apiPut<WorkbookDetail>(`/workbooks/${id}`, data);
}

export function deleteWorkbook(id: number): Promise<void> {
  return apiDelete(`/workbooks/${id}`);
}
