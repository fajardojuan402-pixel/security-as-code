# Infraestructura de ejemplo. No ejecutar terraform apply.
# HALLAZGO INTENCIONAL: bucket S3 con configuración de acceso público.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "lab_data" {
  bucket = "security-as-code-lab-public-example-123456"
}

resource "aws_s3_bucket_acl" "lab_data_acl" {
  bucket = aws_s3_bucket.lab_data.id
  acl    = "public-read"
}

resource "aws_s3_bucket_public_access_block" "lab_data" {
  bucket                  = aws_s3_bucket.lab_data.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
