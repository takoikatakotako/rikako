/**
 * 実行環境とそれに応じた表示名。
 *
 * static export のため、ビルド時の NEXT_PUBLIC_APP_ENV を焼き込む。
 * - prod ビルド: NEXT_PUBLIC_APP_ENV=production → "Rikako Admin"
 * - dev ビルド / ローカル(未設定): "Rikako Admin（Dev）"
 */
export const APP_ENV = process.env.NEXT_PUBLIC_APP_ENV ?? "development";

export const IS_PRODUCTION = APP_ENV === "production";

export const APP_TITLE = IS_PRODUCTION ? "Rikako Admin" : "Rikako Admin（Dev）";
