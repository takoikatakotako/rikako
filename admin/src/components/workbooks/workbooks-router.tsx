"use client";

import { useRouteSlug } from "@/hooks/use-route-slug";
import { WorkbookList } from "@/components/workbooks/workbook-list";
import { WorkbookDetail } from "@/components/workbooks/workbook-detail";
import { WorkbookEdit } from "@/components/workbooks/workbook-edit";
import { WorkbookNew } from "@/components/workbooks/workbook-new";

export function WorkbooksRouter() {
  const { slug, mounted } = useRouteSlug("workbooks");

  if (!mounted) {
    return <p className="text-muted-foreground">読み込み中...</p>;
  }

  if (!slug || slug.length === 0) {
    return <WorkbookList />;
  }

  if (slug[0] === "new") {
    return <WorkbookNew />;
  }

  const id = Number(slug[0]);

  if (slug[1] === "edit") {
    return <WorkbookEdit id={id} />;
  }

  return <WorkbookDetail id={id} />;
}
