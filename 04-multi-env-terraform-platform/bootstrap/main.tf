# One-time bootstrap (run locally with admin creds): remote state, locking, GitHub OIDC, per-env CI roles.
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}
provider "aws" {
  region = var.region
}

variable "region" {
  default = "ap-south-1"
}
variable "project" {
  default = "mep"
}
variable "github_repo" {
  description = "owner/repo allowed to assume CI roles"
  type        = string
}
variable "environments" {
  default = ["dev", "staging", "prod"]
}

data "aws_caller_identity" "me" {}
locals {
  bucket = "${var.project}-tfstate-${data.aws_caller_identity.me.account_id}"
}

resource "aws_s3_bucket" "state" {
  bucket = local.bucket
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_dynamodb_table" "lock" {
  name         = "${var.project}-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Isolated permissions: each env role is bound to its GitHub Environment and can only touch its own state prefix.
data "aws_iam_policy_document" "trust" {
  for_each = toset(var.environments)
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:${each.key}", "repo:${var.github_repo}:pull_request"]
    }
  }
}
resource "aws_iam_role" "ci" {
  for_each           = toset(var.environments)
  name               = "${var.project}-ci-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.trust[each.key].json
}
data "aws_iam_policy_document" "state_access" {
  for_each = toset(var.environments)
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${each.key}/*"]
    }
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/${each.key}/*"]
  }
  statement {
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.lock.arn]
  }
}
resource "aws_iam_role_policy" "state" {
  for_each = toset(var.environments)
  role     = aws_iam_role.ci[each.key].id
  policy   = data.aws_iam_policy_document.state_access[each.key].json
}
# Demo-level resource permissions; tighten to least privilege for your account before real production use.
resource "aws_iam_role_policy_attachment" "power" {
  for_each   = toset(var.environments)
  role       = aws_iam_role.ci[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

output "state_bucket" {
  value = aws_s3_bucket.state.id
}
output "lock_table" {
  value = aws_dynamodb_table.lock.name
}
output "ci_role_arns" {
  value = { for k, r in aws_iam_role.ci : k => r.arn }
}
