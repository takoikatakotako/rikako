// Web 用の X-Device-ID。iOS の匿名 Cognito Identity に相当する端末識別子を
// localStorage に持つ（UUID）。/account/link でアカウント作成/紐付けに使う。
// サーバーは identity_id として扱うだけなので UUID で十分。
const DEVICE_ID_KEY = "rikako.portal.deviceId";

export function getDeviceId(): string {
  if (typeof window === "undefined") return "";
  let id = window.localStorage.getItem(DEVICE_ID_KEY);
  if (!id) {
    id = crypto.randomUUID();
    window.localStorage.setItem(DEVICE_ID_KEY, id);
  }
  return id;
}

// 別アカウントに紐付き済みの device id で 409 になった場合に、新しい UUID へ切り替える。
// ポータルの device 行には匿名学習データを積まないため、rotate による損失はない。
export function rotateDeviceId(): string {
  if (typeof window === "undefined") return "";
  const id = crypto.randomUUID();
  window.localStorage.setItem(DEVICE_ID_KEY, id);
  return id;
}

// ログアウト時に消す（同ブラウザで別アカウントへ切り替えた際の 409 を避ける）。
export function clearDeviceId(): void {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(DEVICE_ID_KEY);
}
