import { apiPost } from "./client";
import type { CreatePresignedUrlRequest, PresignedUrlResponse } from "./types";

export function createPresignedUrl(
  data: CreatePresignedUrlRequest,
): Promise<PresignedUrlResponse> {
  return apiPost<PresignedUrlResponse>("/images/presigned-url", data);
}

export async function uploadImage(
  file: File,
): Promise<PresignedUrlResponse> {
  const contentType = file.type as "image/png" | "image/jpeg";
  const presigned = await createPresignedUrl({
    filename: file.name,
    contentType,
  });

  await fetch(presigned.uploadUrl, {
    method: "PUT",
    headers: { "Content-Type": contentType },
    body: file,
  });

  return presigned;
}
