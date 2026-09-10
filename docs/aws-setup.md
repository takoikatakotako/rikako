# AWS CLI セットアップ

このプロジェクトでは AWS SSO を使って認証します。以下の手順でプロファイルを設定してください。

## プロファイル設定

`~/.aws/config` に以下を追加:

```ini
# dev環境（AWSアカウント: 197865631794）
[profile rikako-development-sso]
sso_start_url = https://your-sso-portal.awsapps.com/start
sso_region = ap-northeast-1
sso_account_id = 197865631794
sso_role_name = AdministratorAccess
region = ap-northeast-1
output = json

# prod環境（AWSアカウント: 211125415945）
[profile rikako-production-sso]
sso_start_url = https://your-sso-portal.awsapps.com/start
sso_region = ap-northeast-1
sso_account_id = 211125415945
sso_role_name = AdministratorAccess
region = ap-northeast-1
output = json

# shared環境（AWSアカウント: 579039992557）
# ECR の IaC は別リポジトリ aws-iac で管理しているため、このリポジトリの作業で使うことは
# ほとんど無い。イメージを直接確認したいときだけ。
[profile rikako-shared-sso]
sso_start_url = https://your-sso-portal.awsapps.com/start
sso_region = ap-northeast-1
sso_account_id = 579039992557
sso_role_name = AdministratorAccess
region = ap-northeast-1
output = json
```

> `sso_start_url` と `sso_role_name` は実際の環境に合わせて変更してください。

## ログイン

```bash
# dev環境
aws sso login --profile rikako-development-sso

# prod環境
aws sso login --profile rikako-production-sso

# shared環境（ECR を直接見るときのみ）
aws sso login --profile rikako-shared-sso
```

> セッションは時間で切れる。`The SSO session associated with this profile has expired`
> が出たら同じコマンドで入り直す。

## 使い方

各コマンドは `AWS_PROFILE` 環境変数でプロファイルを指定します:

```bash
# Terraform
AWS_PROFILE=rikako-development-sso terraform plan

# datasync
AWS_PROFILE=rikako-development-sso go run ./cmd/datasync -data ../data -env dev plan

# AWS CLI
AWS_PROFILE=rikako-development-sso aws s3 ls s3://rikako-images-development/
```

> CI（GitHub Actions）では OIDC 認証を使用するため、プロファイルは不要です。
