# S3 access for Admin API Lambda (Presigned URL generation)
resource "aws_iam_role_policy" "lambda_admin_s3_presign" {
  name   = "s3-presign-access"
  role   = module.lambda_admin.role_name
  policy = data.aws_iam_policy_document.lambda_admin_s3_presign.json
}

data "aws_iam_policy_document" "lambda_admin_s3_presign" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${module.image_s3.bucket_arn}/*",
    ]
  }
}
