// Cognito / API の設定。ビルド時の NEXT_PUBLIC_* から解決する。
// User Pool の App Client は generate_secret=false なので SECRET_HASH 不要。
export const config = {
  cognitoRegion: process.env.NEXT_PUBLIC_COGNITO_REGION ?? "ap-northeast-1",
  cognitoClientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID ?? "",
  // 既定は dev。ローカルの npm run dev で本番へ書き込んでしまわないようにする
  // （dev/prod のデプロイでは workflow が明示的に設定する）。
  apiBaseUrl:
    process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://api.dev.rikako.org",
};

export function cognitoIdpEndpoint(): string {
  return `https://cognito-idp.${config.cognitoRegion}.amazonaws.com/`;
}
