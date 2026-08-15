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
