import { apiGet, apiPost, apiPut, apiDelete } from "./client";
import type {
  CategoriesResponse,
  CategoryDetail,
  CreateCategoryRequest,
  UpdateCategoryRequest,
} from "./types";

export function fetchCategories(
  limit: number,
  offset: number,
): Promise<CategoriesResponse> {
  return apiGet<CategoriesResponse>(
    `/categories?limit=${limit}&offset=${offset}`,
  );
}

export function fetchCategory(id: number): Promise<CategoryDetail> {
  return apiGet<CategoryDetail>(`/categories/${id}`);
}

export function createCategory(
  data: CreateCategoryRequest,
): Promise<CategoryDetail> {
  return apiPost<CategoryDetail>("/categories", data);
}

export function updateCategory(
  id: number,
  data: UpdateCategoryRequest,
): Promise<CategoryDetail> {
  return apiPut<CategoryDetail>(`/categories/${id}`, data);
}

export function deleteCategory(id: number): Promise<void> {
  return apiDelete(`/categories/${id}`);
}
