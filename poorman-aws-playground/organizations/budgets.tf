resource "aws_budgets_budget" "monthly_budget" {
  name         = "budget-monthly"
  budget_type  = "COST"
  limit_amount = var.org_budget_limit_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.org_budget_subscriber_email_addresses
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.org_budget_subscriber_email_addresses
  }
}