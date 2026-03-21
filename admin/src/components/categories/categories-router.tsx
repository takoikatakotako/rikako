"use client";

import { useRouteSlug } from "@/hooks/use-route-slug";
import { CategoryList } from "@/components/categories/category-list";
import { CategoryDetail } from "@/components/categories/category-detail";
import { CategoryEdit } from "@/components/categories/category-edit";
import { CategoryNew } from "@/components/categories/category-new";

export function CategoriesRouter() {
  const { slug, mounted } = useRouteSlug("categories");

  if (!mounted) {
    return <p className="text-muted-foreground">読み込み中...</p>;
  }

  if (!slug || slug.length === 0) {
    return <CategoryList />;
  }

  if (slug[0] === "new") {
    return <CategoryNew />;
  }

  const id = Number(slug[0]);

  if (slug[1] === "edit") {
    return <CategoryEdit id={id} />;
  }

  return <CategoryDetail id={id} />;
}
