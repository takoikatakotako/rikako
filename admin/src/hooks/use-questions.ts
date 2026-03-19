import useSWR from "swr";
import { fetchQuestions, fetchQuestion } from "@/lib/api/questions";
import type { QuestionsResponse, Question } from "@/lib/api/types";

export function useQuestions(limit: number, offset: number) {
  return useSWR<QuestionsResponse>(
    [`/questions`, limit, offset],
    () => fetchQuestions(limit, offset),
  );
}

export function useQuestion(id: number | null) {
  return useSWR<Question>(
    id !== null ? [`/questions`, id] : null,
    () => fetchQuestion(id!),
  );
}
