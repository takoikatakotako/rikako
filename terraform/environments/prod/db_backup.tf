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
    bucket_key_enabled = true
  }
}

# 30 日で自動削除する。ダンプは日次で増えるだけなので、放置すると際限なく溜まる。
resource "aws_s3_bucket_lifecycle_configuration" "db_backup" {
  bucket = module.db_backup.bucket_id

  rule {
    id     = "expire-after-30-days"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    # 途中で失敗したマルチパートアップロードを残さない。
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# GitHub Actions からダンプを置くための最小権限。
# 読み出し（復旧時）は SSO の管理者権限で行う前提なので、ここでは付けない。
data "aws_iam_policy_document" "github_actions_db_backup" {
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

resource "aws_iam_role_policy" "github_actions_db_backup" {
  name   = "db-backup"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_db_backup.json
}
