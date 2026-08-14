// Cognito User Pool を Amplify 非依存で直叩きする（cognito-idp, AWS JSON 1.1）。
// App Client は generate_secret=false なので SECRET_HASH は不要。
import { config, cognitoIdpEndpoint } from "./config";
import { AuthTokens, saveTokens, clearTokens, loadTokens } from "./tokens";

export class CognitoError extends Error {
  code: string;
  constructor(code: string, message: string) {
    super(message);
    this.code = code;
    this.name = "CognitoError";
  }
}

async function idpCall<T>(
  action: string,
  body: Record<string, unknown>,
): Promise<T> {
  const res = await fetch(cognitoIdpEndpoint(), {
    method: "POST",
    headers: {
      "Content-Type": "application/x-amz-json-1.1",
      "X-Amz-Target": `AWSCognitoIdentityProviderService.${action}`,
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  const data = text ? JSON.parse(text) : {};
  if (!res.ok) {
    const rawType = (data.__type as string) ?? "UnknownError";
    const code = rawType.split("#").pop() ?? rawType;
    throw new CognitoError(code, (data.message as string) ?? code);
  }
  return data as T;
}

type InitiateAuthResponse = {
  AuthenticationResult?: {
    IdToken: string;
    AccessToken: string;
    RefreshToken: string;
    ExpiresIn: number;
  };
};

function storeAuthResult(r: InitiateAuthResponse): AuthTokens {
  const ar = r.AuthenticationResult;
  if (!ar) {
    throw new CognitoError("NoAuthenticationResult", "認証結果が取得できませんでした");
  }
  const tokens: AuthTokens = {
    idToken: ar.IdToken,
    accessToken: ar.AccessToken,
    refreshToken: ar.RefreshToken,
    expiresAt: Date.now() + ar.ExpiresIn * 1000,
  };
  saveTokens(tokens);
  return tokens;
}

// サインアップ（メール確認コードが送られる）。
export async function signUp(email: string, password: string): Promise<void> {
  await idpCall("SignUp", {
    ClientId: config.cognitoClientId,
    Username: email,
    Password: password,
    UserAttributes: [{ Name: "email", Value: email }],
  });
}

export async function confirmSignUp(email: string, code: string): Promise<void> {
  await idpCall("ConfirmSignUp", {
    ClientId: config.cognitoClientId,
    Username: email,
    ConfirmationCode: code,
  });
}

export async function resendConfirmationCode(email: string): Promise<void> {
  await idpCall("ResendConfirmationCode", {
    ClientId: config.cognitoClientId,
    Username: email,
  });
}

// ログイン（USER_PASSWORD_AUTH）。
export async function signIn(email: string, password: string): Promise<AuthTokens> {
  const r = await idpCall<InitiateAuthResponse>("InitiateAuth", {
    AuthFlow: "USER_PASSWORD_AUTH",
    ClientId: config.cognitoClientId,
    AuthParameters: { USERNAME: email, PASSWORD: password },
  });
  return storeAuthResult(r);
}

// リフレッシュトークンで ID/Access token を更新する。
export async function refresh(): Promise<AuthTokens | null> {
  const current = loadTokens();
  if (!current) return null;
  const r = await idpCall<InitiateAuthResponse>("InitiateAuth", {
    AuthFlow: "REFRESH_TOKEN_AUTH",
    ClientId: config.cognitoClientId,
    AuthParameters: { REFRESH_TOKEN: current.refreshToken },
  });
  // REFRESH_TOKEN_AUTH のレスポンスには RefreshToken が含まれないため引き継ぐ。
  const ar = r.AuthenticationResult;
  if (!ar) return null;
  const tokens: AuthTokens = {
    idToken: ar.IdToken,
    accessToken: ar.AccessToken,
    refreshToken: ar.RefreshToken ?? current.refreshToken,
    expiresAt: Date.now() + ar.ExpiresIn * 1000,
  };
  saveTokens(tokens);
  return tokens;
}

export async function forgotPassword(email: string): Promise<void> {
  await idpCall("ForgotPassword", {
    ClientId: config.cognitoClientId,
    Username: email,
  });
}

export async function confirmForgotPassword(
  email: string,
  code: string,
  newPassword: string,
): Promise<void> {
  await idpCall("ConfirmForgotPassword", {
    ClientId: config.cognitoClientId,
    Username: email,
    ConfirmationCode: code,
    Password: newPassword,
  });
}

// ログアウト。保持中の refresh token を Cognito 側で失効（RevokeToken, secret 不要）
// させたうえで、成否にかかわらずローカルのトークンを消す。
export async function signOut(): Promise<void> {
  const current = loadTokens();
  try {
    if (current?.refreshToken) {
      await idpCall("RevokeToken", {
        Token: current.refreshToken,
        ClientId: config.cognitoClientId,
      });
    }
  } catch {
    // 失効に失敗してもローカルは必ず消す（下の finally）。
  } finally {
    clearTokens();
  }
}

// Cognito のエラーコードを日本語メッセージに寄せる。
// prevent_user_existence_errors=ENABLED のため「ユーザー不存在」は出さない方針。
export function cognitoErrorMessage(e: unknown): string {
  if (e instanceof CognitoError) {
    switch (e.code) {
      case "UsernameExistsException":
        return "このメールアドレスは既に登録されています。";
      case "InvalidPasswordException":
        return "パスワードが要件を満たしていません（8文字以上・大小英字・数字・記号）。";
      case "CodeMismatchException":
        return "確認コードが正しくありません。";
      case "ExpiredCodeException":
        return "確認コードの有効期限が切れています。再送してください。";
      case "NotAuthorizedException":
        return "メールアドレスまたはパスワードが正しくありません。";
      case "UserNotConfirmedException":
        return "メール確認が完了していません。確認コードを入力してください。";
      case "LimitExceededException":
      case "TooManyRequestsException":
        return "試行回数が多すぎます。しばらくしてから再度お試しください。";
      default:
        return e.message || "エラーが発生しました。";
    }
  }
  return "通信エラーが発生しました。";
}
