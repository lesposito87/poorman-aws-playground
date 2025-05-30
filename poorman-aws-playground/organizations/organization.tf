resource "aws_organizations_organization" "org" {
  aws_service_access_principals = try(var.org_aws_service_access_principals, null)
  feature_set                   = var.org_feature_set
  enabled_policy_types          = var.org_enabled_policy_types
}

resource "aws_iam_account_alias" "alias" {
  account_alias = var.org_account_alias
}