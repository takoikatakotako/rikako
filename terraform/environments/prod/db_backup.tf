# =============================================================================
# 本番 Neon DB の日次バックアップ（#280）
# =============================================================================
# Neon の Free プランは Point-in-Time Restore の保持が 6 時間しかないため、
# 誤操作や不正なマイグレーションを翌日以降に気づいた場合に戻せない。
# Neon とは独立した日次バックアップを S3 に置く。
#
# 取得は GitHub Actions（.github/workflows/backup-db-prod.yml）から OIDC で行う。
# メールログイン（#283）でアカウントと学習記録が prod に載り始めるため、
# 実ユーザーのデータが増える前に用意しておく。

module "db_backup" {
  source = "../../modules/s3"

  bucket_name = "${local.project}-db-backups-${local.environment}"

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Purpose     = "database-backup"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "db_backup" {
  bucket = module.db_backup.bucket_id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 同じキーへの上書きから戻せるようにする。CI は DeleteObject を持たないが、
# PutObject は既存キーを上書きできるため、versioning が無いと復旧手段が無い。
resource "aws_s3_bucket_versioning" "db_backup" {
  bucket = module.db_backup.bucket_id

  versioning_configuration {
    status = "Enabled"
  }
}

# 30 日で自動削除する。ダンプは日次で増えるだけなので、放置すると際限なく溜まる。
# versioning を入れたので、旧バージョンにも同じ保持期間を設定する
# （設定しないと noncurrent version が残り続ける）。
resource "aws_s3_bucket_lifecycle_configuration" "db_backup" {
  # noncurrent_version_expiration を含むため、versioning が有効になってから作る。
  # 依存を書かないと並列に作られ、versioning 未有効のバケットとして失敗しうる。
  depends_on = [aws_s3_bucket_versioning.db_backup]

  bucket = module.db_backup.bucket_id

  rule {
    id     = "expire-after-30-days"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    # 途中で失敗したマルチパートアップロードを残さない。
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# バックアップ専用の OIDC ロール。
#
# 共有の rikako-production-github-actions は trust が
# `repo:takoikatakotako/rikako:*` で、**どのブランチ・どのワークフローからでも**
# assume できる。そこへ本番 database-url の復号権限を足すと、任意のブランチの
# ワークフローから本番 DB の接続情報へ到達できてしまう。ワークフロー側を
# schedule / manual に限定しても、それは role の信頼境界にはならない。
#
# そのため専用ロールを作り、**main ブランチからの実行に限定**する。
data "aws_iam_policy_document" "db_backup_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # ワイルドカードを使わない。main 以外のブランチからは assume できない。
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:takoikatakotako/rikako:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "db_backup" {
  name               = "${local.project}-${local.environment}-db-backup"
  assume_role_policy = data.aws_iam_policy_document.db_backup_assume_role.json

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Purpose     = "database-backup"
  }
}

# バックアップに必要な最小権限だけを与える。
# 復旧時の読み出しは SSO の管理者権限で行う前提なので、一覧や削除は付けない。
data "aws_iam_policy_document" "db_backup" {
  statement {
    sid       = "PutBackupObject"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${module.db_backup.bucket_arn}/*"]
  }

  # ダンプが置けたことの確認に使う。
  statement {
    sid       = "HeadBackupObject"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${module.db_backup.bucket_arn}/*"]
  }

  # 接続情報と失敗通知先を読む。値はワークフロー側でマスクする。
  statement {
    sid     = "ReadSecrets"
    effect  = "Allow"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/rikako/${local.environment}/database-url",
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/rikako/${local.environment}/slack-alert-webhook-url",
    ]
  }

  statement {
    sid       = "DecryptSecureString"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "db_backup" {
  name   = "db-backup"
  role   = aws_iam_role.db_backup.id
  policy = data.aws_iam_policy_document.db_backup.json
}

output "db_backup_role_arn" {
  description = "バックアップワークフローが assume する専用ロール"
  value       = aws_iam_role.db_backup.arn
}
