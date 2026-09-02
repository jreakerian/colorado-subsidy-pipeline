# ── GitHub Actions OIDC Identity Provider ─────────────────────────────────────
# One-time account-level resource. Tells AWS to trust short-lived JWTs minted
# by GitHub Actions so jobs can assume IAM roles without any static keys.
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  # GitHub's OIDC audience claim for AWS STS
  client_id_list = ["sts.amazonaws.com"]

  # GitHub's current OIDC thumbprint — stable unless GitHub rotates their cert
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name      = "GitHubActionsOIDC"
    ManagedBy = "terraform"
  }
}

# ── IAM Role for terraform-ci (plan only, read-only to state) ─────────────────
resource "aws_iam_role" "github_actions_terraform_ci" {
  name = "GitHubActions-TerraformCI-${var.project_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # Only trust tokens issued for this specific repository via pull_request
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:jreakerian/colorado-subsidy-pipeline:pull_request"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "GitHubActions-TerraformCI"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── Policy: read/write the S3 state bucket (needed for terraform plan) ────────
resource "aws_iam_policy" "terraform_ci_state_policy" {
  name        = "TerraformCI-StateAccess-${var.project_name}"
  description = "Allows terraform-ci GitHub Actions job to read Terraform state from S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          "arn:aws:s3:::colorado-subsidy-terraform-state",
          "arn:aws:s3:::colorado-subsidy-terraform-state/*"
        ]
      },
      {
        Sid    = "ReadOnlyInfra"
        Effect = "Allow"
        Action = [
          "s3:Get*",
          "s3:List*",
          "s3:Describe*",
          "iam:Get*",
          "iam:List*",
          "dynamodb:Describe*",
          "dynamodb:List*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_ci_state" {
  role       = aws_iam_role.github_actions_terraform_ci.name
  policy_arn = aws_iam_policy.terraform_ci_state_policy.arn
}

# ── Output the role ARN so it can be used in the workflow ─────────────────────
output "github_actions_terraform_ci_role_arn" {
  description = "ARN of the IAM role terraform-ci assumes via GitHub Actions OIDC. Add to GitHub Variables as AWS_TERRAFORM_CI_ROLE_ARN."
  value       = aws_iam_role.github_actions_terraform_ci.arn
}

# ── IAM Role for terraform-cd (apply — full write access) ─────────────────────
resource "aws_iam_role" "github_actions_terraform_cd" {
  name = "GitHubActions-TerraformCD-${var.project_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            # Only trust push events to main — never from PRs or feature branches
            "token.actions.githubusercontent.com:sub" = "repo:jreakerian/colorado-subsidy-pipeline:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "GitHubActions-TerraformCD"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CD role needs full admin to create/modify/delete all Terraform-managed AWS resources
resource "aws_iam_role_policy_attachment" "terraform_cd_admin" {
  role       = aws_iam_role.github_actions_terraform_cd.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_terraform_cd_role_arn" {
  description = "ARN of the IAM role terraform-cd assumes via GitHub Actions OIDC. Add to GitHub Variables as AWS_TERRAFORM_CD_ROLE_ARN."
  value       = aws_iam_role.github_actions_terraform_cd.arn
}
