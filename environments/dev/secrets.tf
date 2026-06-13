# SSM Parameter Store - SecureString parameters for secrets
# These are created by Terraform but values are managed externally after initial creation.

resource "aws_ssm_parameter" "database_uri" {
  name  = "/${var.app_name}/${var.environment}/database-uri"
  type  = "SecureString"
  value = var.database_uri

  tags = { Name = "${var.app_name}-database-uri-${var.environment}" }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "jwt_secret" {
  name  = "/${var.app_name}/${var.environment}/jwt-secret"
  type  = "SecureString"
  value = var.jwt_secret

  tags = { Name = "${var.app_name}-jwt-secret-${var.environment}" }

  lifecycle {
    ignore_changes = [value]
  }
}
