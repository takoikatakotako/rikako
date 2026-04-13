const API_BASE_URL = process.env.NEXT_PUBLIC_ADMIN_API_URL || "/api";

export class ApiClientError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message);
    this.name = "ApiClientError";
  }
}

async function handleResponse<T>(response: Response): Promise<T> {
  if (!response.ok) {
    const body = await response.json().catch(() => ({
      code: "unknown",
      message: response.statusText,
    }));
    throw new ApiClientError(response.status, body.code, body.message);
  }
  if (response.status === 204) {
    return undefined as T;
  }
  return response.json();
}

// CloudFront OAC + Lambda Function URL ではPOST/PUTのペイロード署名が必要。
// リクエストボディのSHA-256ハッシュを x-amz-content-sha256 ヘッダーに含める。
async function computePayloadHash(payload: string): Promise<string> {
  const data = new TextEncoder().encode(payload);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function apiGet<T>(path: string): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`);
  return handleResponse<T>(response);
}

export async function apiPost<T>(path: string, body: unknown): Promise<T> {
  const jsonBody = JSON.stringify(body);
  const payloadHash = await computePayloadHash(jsonBody);
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-amz-content-sha256": payloadHash,
    },
    body: jsonBody,
  });
  return handleResponse<T>(response);
}

export async function apiPut<T>(path: string, body: unknown): Promise<T> {
  const jsonBody = JSON.stringify(body);
  const payloadHash = await computePayloadHash(jsonBody);
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
      "x-amz-content-sha256": payloadHash,
    },
    body: jsonBody,
  });
  return handleResponse<T>(response);
}

export async function apiDelete(path: string): Promise<void> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: "DELETE",
  });
  return handleResponse<void>(response);
}
