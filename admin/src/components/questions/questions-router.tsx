"use client";

import { useRouteSlug } from "@/hooks/use-route-slug";
import { QuestionList } from "@/components/questions/question-list";
import { QuestionDetail } from "@/components/questions/question-detail";
import { QuestionEdit } from "@/components/questions/question-edit";
import { QuestionNew } from "@/components/questions/question-new";

export function QuestionsRouter() {
  const { slug, mounted } = useRouteSlug("questions");

  if (!mounted) {
    return <p className="text-muted-foreground">読み込み中...</p>;
  }

  if (!slug || slug.length === 0) {
    return <QuestionList />;
  }

  if (slug[0] === "new") {
    return <QuestionNew />;
  }

  const id = Number(slug[0]);

  if (slug[1] === "edit") {
    return <QuestionEdit id={id} />;
  }

  return <QuestionDetail id={id} />;
}
