# Secrets Manager for N8N credentials
resource "aws_secretsmanager_secret" "n8n_auth_user" {
  name        = "${var.project_name}/n8n-auth-user"
  description = "N8N Basic Auth Username"

  tags = {
    Name = "${var.project_name}-n8n-auth-user"
  }
}

resource "aws_secretsmanager_secret_version" "n8n_auth_user" {
  secret_id     = aws_secretsmanager_secret.n8n_auth_user.id
  secret_string = var.n8n_basic_auth_user
}

resource "aws_secretsmanager_secret" "n8n_auth_password" {
  name        = "${var.project_name}/n8n-auth-password"
  description = "N8N Basic Auth Password"

  tags = {
    Name = "${var.project_name}-n8n-auth-password"
  }
}

resource "aws_secretsmanager_secret_version" "n8n_auth_password" {
  secret_id     = aws_secretsmanager_secret.n8n_auth_password.id
  secret_string = var.n8n_basic_auth_password
}

resource "aws_secretsmanager_secret" "n8n_encryption_key" {
  name        = "${var.project_name}/n8n-encryption-key"
  description = "N8N Encryption Key"

  tags = {
    Name = "${var.project_name}-n8n-encryption-key"
  }
}

resource "aws_secretsmanager_secret_version" "n8n_encryption_key" {
  secret_id     = aws_secretsmanager_secret.n8n_encryption_key.id
  secret_string = var.n8n_encryption_key
}

# Database credentials
resource "aws_secretsmanager_secret" "db_username" {
  name        = "${var.project_name}/db-username"
  description = "Database Username"

  tags = {
    Name = "${var.project_name}-db-username"
  }
}

resource "aws_secretsmanager_secret_version" "db_username" {
  secret_id     = aws_secretsmanager_secret.db_username.id
  secret_string = var.db_username
}

resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.project_name}/db-password"
  description = "Database Password"

  tags = {
    Name = "${var.project_name}-db-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

# S3 Bucket for N8N data storage
resource "aws_s3_bucket" "n8n_data" {
  bucket = "${var.project_name}-data-${random_string.bucket_suffix.result}"

  tags = {
    Name = "${var.project_name}-data"
  }
}

resource "aws_s3_bucket_versioning" "n8n_data" {
  bucket = aws_s3_bucket.n8n_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "n8n_data" {
  bucket = aws_s3_bucket.n8n_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "n8n_data" {
  bucket = aws_s3_bucket.n8n_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "n8n_data" {
  bucket = aws_s3_bucket.n8n_data.id

  rule {
    id     = "lifecycle"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}
