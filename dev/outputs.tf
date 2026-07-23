output "environment_url" {
  value = module.dev.environment_url
}

data "aws_caller_identity" "current" {}

output "aws_account" {
  value = data.aws_caller_identity.current.account_id
}
