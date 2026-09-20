"""prod DB バックアップの鮮度を確認し、古ければ SNS（→ Slack）へ通知する（Issue #331）。

backup-db-prod.yml（GitHub Actions）は「実行されて失敗した」ときしか通知しない。
schedule の停止（public リポジトリは 60 日無活動で自動停止する）や GitHub 側の障害で
「実行されなかった」場合は無音になるため、GitHub の外（EventBridge Scheduler → この Lambda）
から S3 の実体を見て検知する。

  s3://<BUCKET>/<PREFIX> の最新オブジェクトの LastModified が MAX_AGE_HOURS より古い、
  または 1 件も無い → SNS に publish
"""
import json
import os
from datetime import datetime, timedelta, timezone

import boto3

BUCKET = os.environ["BUCKET"]
PREFIX = os.environ.get("PREFIX", "")
MAX_AGE_HOURS = int(os.environ.get("MAX_AGE_HOURS", "48"))
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

s3 = boto3.client("s3")
sns = boto3.client("sns")


def latest_object():
    """PREFIX 配下で LastModified が最新のオブジェクトを返す（無ければ None）。

    バックアップは production/YYYY/MM/DD/ に日次で置かれ、ライフサイクルで 30 日後に消える。
    多くても数十件なので全件を舐める（ページングは念のため）。
    """
    newest = None
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=BUCKET, Prefix=PREFIX):
        for obj in page.get("Contents", []):
            if newest is None or obj["LastModified"] > newest["LastModified"]:
                newest = obj
    return newest


def handler(_event, _context):
    now = datetime.now(timezone.utc)
    newest = latest_object()

    if newest is None:
        notify(
            f":rotating_light: *prod DB バックアップが 1 件もありません*\n"
            f"s3://{BUCKET}/{PREFIX} にオブジェクトが無い。backup-db-prod.yml が動いているか確認してください。"
        )
        return {"status": "missing"}

    age = now - newest["LastModified"]
    age_hours = age.total_seconds() / 3600
    result = {
        "status": "ok" if age <= timedelta(hours=MAX_AGE_HOURS) else "stale",
        "latest_key": newest["Key"],
        "latest_last_modified": newest["LastModified"].isoformat(),
        "age_hours": round(age_hours, 1),
        "max_age_hours": MAX_AGE_HOURS,
        "size_bytes": newest.get("Size", 0),
    }
    print(json.dumps(result))

    if result["status"] == "stale":
        notify(
            f":rotating_light: *prod DB バックアップが {age_hours:.0f} 時間更新されていません*（閾値 {MAX_AGE_HOURS} 時間）\n"
            f"最新: `s3://{BUCKET}/{newest['Key']}`（{newest['LastModified'].strftime('%Y-%m-%d %H:%M UTC')}）\n"
            "backup-db-prod.yml の schedule が止まっていないか（60 日無活動で自動停止する）、"
            "直近の run が失敗していないかを確認してください。"
        )
    return result


def notify(text: str) -> None:
    # slack_notifier は AlarmName を含まない SNS メッセージを
    # 「*Subject*\n```Message```」で Slack に流す。Subject を見出しにする。
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject="prod DB backup freshness",
        Message=text,
    )
