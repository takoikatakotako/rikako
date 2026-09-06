# フロントエンド（web / portal / admin）の Cache-Control を CloudFront 側で付与する。
#
# 以前は `aws s3 sync --cache-control` で S3 オブジェクトのメタデータとして設定していたが、
# sync は「ローカルの方が新しい / サイズが違う」ファイルしか転送しないため、対象が少しでも
# 重なると 2 本目がスキップされて意図した値が付かない（#336 で実際に it.rikako.org の
# ハッシュ付きチャンクが max-age=0 で配信されていた）。配信ヘッダはデプロイ手順ではなく
# 配信基盤の責務にして、この種の取りこぼしをクラスごと無くす。
#
# override = true なので、既存オブジェクトに残っている古い Cache-Control も上書きされる。
# S3 側のメタデータを貼り直す必要はない。

# ハッシュ名付きアセット（_next/static/）専用。Next.js は内容が変われば URL も変わるので
# 恒久キャッシュしてよい。これを当ててよいのは _next/static/ だけ。public/ の画像などは
# ハッシュが付かず、1年 immutable にすると更新が永久に届かなくなる。
resource "aws_cloudfront_response_headers_policy" "next_static" {
  name    = "${local.project}-next-static-${local.environment}"
  comment = "Immutable Cache-Control for Next.js content-hashed assets"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "public, max-age=31536000, immutable"
      override = true
    }
  }
}

# HTML やハッシュの付かないアセット。デプロイのたびに同じ URL で内容が変わりうるため、
# ブラウザには毎回再検証させる（エッジ側の保持は各ビヘイビアの default_ttl + デプロイ時の
# `/*` invalidation で制御する）。
resource "aws_cloudfront_response_headers_policy" "html_revalidate" {
  name    = "${local.project}-html-revalidate-${local.environment}"
  comment = "Always-revalidate Cache-Control for HTML and unhashed assets"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "public, max-age=0, must-revalidate"
      override = true
    }
  }
}
