// Web 用の X-Device-ID。iOS の匿名 Cognito Identity に相当する端末識別子を
// localStorage に持つ（UUID）。/account/link でアカウント作成/紐付けに使う。
// サーバーは identity_id として扱うだけなので UUID で十分。
const DEVICE_ID_KEY = "rikako.it.deviceId";

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
// 409 はこの device id が既に別アカウントの所有物であることを意味するので、
// 手元の匿名データはそのアカウント側に属している。rotate して新しい匿名 users 行を
// 作り直すのが正しい（この端末の未ログイン分だけを新しいアカウントに紐付ける）。
// （ログアウトでは消さない: 消すと再ログインごとに空の users 行が増えるため。）
export function rotateDeviceId(): string {
  if (typeof window === "undefined") return "";
  const id = crypto.randomUUID();
  window.localStorage.setItem(DEVICE_ID_KEY, id);
  return id;
}
