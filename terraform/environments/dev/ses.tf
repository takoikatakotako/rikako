# =============================================================================
# Amazon SES（Cognito User Pool のメール送信元）
# =============================================================================
# dev.rikako.org をドメイン検証し、Cognito のサインアップ確認コード/パスワード
# 再設定メールの送信元にする（COGNITO_DEFAULT の 1日50通・差出人固定から脱却）。
# DKIM/検証レコードは Cloudflare(rikako.org zone) に自動追加する。
#
# 注意: 初期状態の SES は「サンドボックス」。検証済みアドレスにしか送れないため、
# 任意ユーザーへの本番送信には別途コンソールから本番アクセス申請が必要（~24h）。
# =============================================================================

locals {
  ses_domain     = "dev.rikako.org"
  ses_from_email = "no-reply@dev.rikako.org"
}

resource "aws_ses_domain_identity" "main" {
  domain = local.ses_domain
}

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# ドメイン検証用 TXT（_amazonses.dev.rikako.org）
resource "cloudflare_record" "ses_verification" {
  zone_id = data.cloudflare_zone.rikako.id
  name    = "_amazonses.dev"
  type    = "TXT"
  content = aws_ses_domain_identity.main.verification_token
  ttl     = 1
  proxied = false
}

# DKIM CNAME ×3（<token>._domainkey.dev.rikako.org → <token>.dkim.amazonses.com）
resource "cloudflare_record" "ses_dkim" {
  count   = 3
  zone_id = data.cloudflare_zone.rikako.id
  name    = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey.dev"
  type    = "CNAME"
  content = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}.dkim.amazonses.com"
  ttl     = 1
  proxied = false
}

# TXT が伝播して SES がドメインを verified 状態にするまで待つ。
resource "aws_ses_domain_identity_verification" "main" {
  domain     = aws_ses_domain_identity.main.id
  depends_on = [cloudflare_record.ses_verification]
}
