import useSWR from "swr";
import { fetchCategories, fetchCategory } from "@/lib/api/categories";
import type { CategoriesResponse, CategoryDetail } from "@/lib/api/types";

export function useCategories(limit: number, offset: number) {
  return useSWR<CategoriesResponse>(
    [`/categories`, limit, offset],
    () => fetchCategories(limit, offset),
  );
}

export function useCategory(id: number | null) {
  return useSWR<CategoryDetail>(
    id !== null ? [`/categories`, id] : null,
    () => fetchCategory(id!),
  );
}
