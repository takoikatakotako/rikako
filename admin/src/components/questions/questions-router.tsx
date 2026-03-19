"use client";

import { useParams } from "next/navigation";
import { QuestionList } from "@/components/questions/question-list";
import { QuestionDetail } from "@/components/questions/question-detail";
import { QuestionEdit } from "@/components/questions/question-edit";
import { QuestionNew } from "@/components/questions/question-new";

export function QuestionsRouter() {
  const params = useParams();
  const slug = params.slug as string[] | undefined;

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
