# =============================================================================
# Amazon SES（Cognito User Pool のメール送信元）
# =============================================================================
# rikako.org をドメイン検証し、Cognito のサインアップ確認コード/パスワード再設定
# メールの送信元にする（COGNITO_DEFAULT の 1日50通・差出人 verificationemail.com
# から脱却）。DKIM/検証レコードは Cloudflare(rikako.org zone) に自動追加する。
#
# 注意（2段階移行）: 初期状態の SES は「サンドボックス」で、検証済みアドレスに
# しか送れない。本ファイルはドメイン検証のみを行い、Cognito の送信元切替
# （cognito.tf の email_source_arn）は本番アクセス承認後に別 PR で実施する。
# サンドボックス中に Cognito を SES へ切り替えると一般ユーザーの新規登録メールが
# 届かなくなるため。本番アクセス申請は手動（aws sesv2 put-account-details）。
# =============================================================================

locals {
  ses_domain     = "rikako.org"
  ses_from_email = "no-reply@rikako.org"
}

resource "aws_ses_domain_identity" "main" {
  domain = local.ses_domain
}

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# ドメイン検証用 TXT（_amazonses.rikako.org）
resource "cloudflare_record" "ses_verification" {
  zone_id = data.cloudflare_zone.rikako.id
  name    = "_amazonses"
  type    = "TXT"
  content = aws_ses_domain_identity.main.verification_token
  ttl     = 1
  proxied = false
}

# DKIM CNAME ×3（<token>._domainkey.rikako.org → <token>.dkim.amazonses.com）
resource "cloudflare_record" "ses_dkim" {
  count   = 3
  zone_id = data.cloudflare_zone.rikako.id
  name    = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey"
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

# DMARC（_dmarc.rikako.org）。まず p=none で観測から始め、なりすまし/到達性の
# 実態を確認してから p=quarantine → p=reject と段階的に強化する。カスタム MAIL FROM
# は設定しないため、DKIM alignment（送信ドメイン = rikako.org）で DMARC を通す。
# rua（集計レポート送付先）は rikako.org の受信メールを未設定のため今は付けない。
# レポートを受け取りたくなったら受信可能なアドレスを rua= で追加する。
resource "cloudflare_record" "dmarc" {
  zone_id = data.cloudflare_zone.rikako.id
  name    = "_dmarc"
  type    = "TXT"
  content = "v=DMARC1; p=none"
  ttl     = 1
  proxied = false
}
