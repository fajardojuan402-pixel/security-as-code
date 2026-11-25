# Infraestructura corregida según estándares de Security as Code.
# No ejecutar terraform apply.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "s3_key" {
  description             = "KMS Key para cifrado de S3 Bucket del laboratorio"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_s3_bucket" "lab_data" {
  #checkov:skip=CKV_AWS_144:Replicacion cross-region no requerida en alcance de laboratorio individual
  #checkov:skip=CKV_AWS_18:Access logging requiere bucket destino adicional fuera del alcance
  #checkov:skip=CKV2_AWS_62:Notificaciones de eventos no requeridas en bucket de demostracion

  bucket = "security-as-code-lab-secure-example-123456"
}

resource "aws_s3_bucket_ownership_controls" "lab_data_ownership" {
  bucket = aws_s3_bucket.lab_data.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "lab_data" {
  bucket                  = aws_s3_bucket.lab_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "lab_data_versioning" {
  bucket = aws_s3_bucket.lab_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lab_data_encryption" {
  bucket = aws_s3_bucket.lab_data.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lab_data_lifecycle" {
  bucket = aws_s3_bucket.lab_data.id

  rule {
    id     = "cleanup-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
