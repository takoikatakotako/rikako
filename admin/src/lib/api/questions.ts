import { apiGet, apiPost, apiPut, apiDelete } from "./client";
import type {
  Question,
  QuestionsResponse,
  CreateQuestionRequest,
  UpdateQuestionRequest,
} from "./types";

export function fetchQuestions(
  limit: number,
  offset: number,
): Promise<QuestionsResponse> {
  return apiGet<QuestionsResponse>(
    `/questions?limit=${limit}&offset=${offset}`,
  );
}

export function fetchQuestion(id: number): Promise<Question> {
  return apiGet<Question>(`/questions/${id}`);
}

export function createQuestion(
  data: CreateQuestionRequest,
): Promise<Question> {
  return apiPost<Question>("/questions", data);
}

export function updateQuestion(
  id: number,
  data: UpdateQuestionRequest,
): Promise<Question> {
  return apiPut<Question>(`/questions/${id}`, data);
}

export function deleteQuestion(id: number): Promise<void> {
  return apiDelete(`/questions/${id}`);
}
