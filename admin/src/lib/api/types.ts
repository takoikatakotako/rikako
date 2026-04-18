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

export interface User {
  id: number;
  identityId: string;
  displayName?: string;
  createdAt: string;
}

export interface UserAppSetting {
  appSlug: string;
  appTitle: string;
  selectedWorkbookId?: number;
}

export interface UserDetail {
  id: number;
  identityId: string;
  displayName?: string;
  createdAt: string;
  appSettings: UserAppSetting[];
}

export interface UsersResponse {
  users: User[];
  total: number;
}

export interface UserAnswerLog {
  id: number;
  questionId: number;
  questionText: string;
  workbookId: number;
  workbookTitle: string;
  selectedChoice: number;
  isCorrect: boolean;
  answeredAt: string;
}

export interface UserAnswersResponse {
  answers: UserAnswerLog[];
  total: number;
}

export interface App {
  id: number;
  slug: string;
  title: string;
  createdAt?: string;
}

export interface AppsResponse {
  apps: App[];
  total: number;
}

export interface CreateAppRequest {
  slug: string;
  title: string;
}

export interface ApiError {
  code: string;
  message: string;
}

export interface AppStatus {
  isMaintenance: boolean;
  maintenanceMessage: string;
  updatedAt: string;
}

export interface UpdateAppStatusRequest {
  isMaintenance: boolean;
  maintenanceMessage: string;
}
