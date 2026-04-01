export interface Choice {
  text: string;
  isCorrect: boolean;
}

export interface Question {
  id: number;
  type: "single_choice";
  text: string;
  choices: Choice[];
  explanation?: string;
  images?: string[];
}

export interface QuestionsResponse {
  questions: Question[];
  total: number;
}

export interface CreateQuestionRequest {
  type: "single_choice";
  text: string;
  choices: Choice[];
  explanation?: string;
  imageIds?: number[];
}

export interface UpdateQuestionRequest {
  type: "single_choice";
  text: string;
  choices: Choice[];
  explanation?: string;
  imageIds?: number[];
}

export interface Category {
  id: number;
  title: string;
  description?: string;
  workbookCount?: number;
}

export interface CategoryDetail {
  id: number;
  title: string;
  description?: string;
  workbooks: Workbook[];
}

export interface CategoriesResponse {
  categories: Category[];
  total: number;
}

export interface CreateCategoryRequest {
  title: string;
  description?: string;
}

export interface UpdateCategoryRequest {
  title: string;
  description?: string;
}

export interface Workbook {
  id: number;
  title: string;
  description?: string;
  questionCount?: number;
  categoryId?: number;
}

export interface WorkbookDetail {
  id: number;
  title: string;
  description?: string;
  categoryId?: number;
  questions: Question[];
}

export interface WorkbooksResponse {
  workbooks: Workbook[];
  total: number;
}

export interface CreateWorkbookRequest {
  title: string;
  description?: string;
  categoryId?: number;
  questionIds?: number[];
}

export interface UpdateWorkbookRequest {
  title: string;
  description?: string;
  categoryId?: number;
  questionIds?: number[];
}

export interface CreatePresignedUrlRequest {
  filename: string;
  contentType: "image/png" | "image/jpeg";
}

export interface PresignedUrlResponse {
  uploadUrl: string;
  imageId: number;
  cdnUrl: string;
}

export interface PublishResponse {
  message: string;
  publishedAt: string;
  categoriesCount?: number;
  workbooksCount?: number;
}

export interface ApiError {
  code: string;
  message: string;
}
