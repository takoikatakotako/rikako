# 既存の SSM パラメータを Terraform 管理下に取り込む（#394）。
# import ブロックは冪等（取り込み済みなら no-op）だが、両環境で apply が終わったら
# このファイルは削除してよい。
# aws_ssm_parameter の import ID はパラメータ名。

import {
  to = aws_ssm_parameter.openai_api_key
  id = "/${local.project}/${local.environment}/openai-api-key"
}

import {
  to = aws_ssm_parameter.slack_contact_webhook_url
  id = "/${local.project}/${local.environment}/slack-contact-webhook-url"
}

import {
  to = aws_ssm_parameter.slack_alert_webhook_url
  id = "/${local.project}/${local.environment}/slack-alert-webhook-url"
}

import {
  for_each = local.firebase_ios_param_names
  to       = aws_ssm_parameter.firebase_ios[each.key]
  id       = each.value
}

import {
  to = aws_ssm_parameter.firebase_android
  id = "/${local.project}/${local.environment}/firebase/android"
}

import {
  to = aws_ssm_parameter.admin_basic_auth_user
  id = "/${local.project}/admin-basic-auth-user"
}

import {
  to = aws_ssm_parameter.admin_basic_auth_password
  id = "/${local.project}/admin-basic-auth-password"
}
