"""CloudWatch アラームの SNS 通知、および ERROR ログ（CloudWatch Logs サブスクリプション）を Slack Incoming Webhook へ転送する。"""
import base64
import gzip
import json
import os
import urllib.request

import boto3


def _resolve_ssm(env_name: str) -> str:
    """環境変数の値が "ssm:" プレフィックス付きなら SSM から実値を取得する。

    Lambda 環境変数に値を直接書くと update-function-code のレスポンス JSON 経由で
    ログに露出するため、参照のみを env に置いて起動時に SSM から取得する。
    """
    val = os.environ[env_name]
    if val.startswith("ssm:"):
        path = val[len("ssm:"):]
        client = boto3.client("ssm")
        resp = client.get_parameter(Name=path, WithDecryption=True)
        return resp["Parameter"]["Value"]
    return val


WEBHOOK_URL = _resolve_ssm("SLACK_WEBHOOK_URL")


# Slack の 1 メッセージ上限は大きいが、payload が過大だと拒否されるため上限を設ける。
# panic のスタックトレース等の長いログも極力残すよう緩めに設定。
MAX_LOG_LEN = 8000


def handler(event, _context):
    # CloudWatch Logs サブスクリプション（ERROR ログ直送）か、SNS（CloudWatch アラーム）かで分岐。
    if "awslogs" in event:
        handle_logs(event)
        return
    handle_sns(event)


def handle_logs(event) -> None:
    payload = json.loads(gzip.decompress(base64.b64decode(event["awslogs"]["data"])))
    if payload.get("messageType") != "DATA_MESSAGE":
        return  # CONTROL_MESSAGE（購読確認）や空イベントは無視
    log_group = payload.get("logGroup", "")
    for e in payload.get("logEvents", []):
        message = str(e.get("message", ""))[:MAX_LOG_LEN]
        post_to_slack(f":rotating_light: *{log_group}*\n```{message}```")


def handle_sns(event) -> None:
    for record in event.get("Records", []):
        sns = record.get("Sns", {})
        raw = sns.get("Message", "")
        try:
            message = json.loads(raw)
        except (json.JSONDecodeError, TypeError):
            message = None

        if isinstance(message, dict) and "AlarmName" in message:
            text = format_alarm(message)
        else:
            subject = sns.get("Subject") or "Notification"
            text = f"*{subject}*\n```{raw}```"

        post_to_slack(text)


def format_alarm(m: dict) -> str:
    name = m.get("AlarmName", "Alarm")
    state = m.get("NewStateValue", "")
    reason = m.get("NewStateReason", "")
    region = m.get("Region", "")
    desc = m.get("AlarmDescription") or ""

    emoji = {
        "ALARM": ":rotating_light:",
        "OK": ":white_check_mark:",
        "INSUFFICIENT_DATA": ":grey_question:",
    }.get(state, ":bell:")

    parts = [f"{emoji} *{name}* — `{state}`"]
    if desc:
        parts.append(desc)
    parts.append(reason)
    if region:
        parts.append(f"Region: {region}")
    return "\n".join(parts)


def post_to_slack(text: str) -> None:
    body = json.dumps({"text": text}).encode("utf-8")
    req = urllib.request.Request(
        WEBHOOK_URL,
        data=body,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=5) as resp:
        if resp.status >= 400:
            raise RuntimeError(f"slack returned {resp.status}: {resp.read()!r}")
