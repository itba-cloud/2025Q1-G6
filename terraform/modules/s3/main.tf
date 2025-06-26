# Generate a random suffix for the bucket name
resource "random_pet" "bucket" {
  length = 2
}

locals {
  vite_bucket_name = "mercado-scraper-${random_pet.bucket.id}"
}

resource "aws_s3_bucket" "vite_site" {
  bucket        = var.bucket_name != "" ? var.bucket_name : local.vite_bucket_name
  force_destroy = true
}


resource "aws_s3_bucket_website_configuration" "vite_site" {
  bucket = aws_s3_bucket.vite_site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }


}

resource "aws_s3_bucket_public_access_block" "vite_site" {
  bucket = aws_s3_bucket.vite_site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.vite_site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.vite_site.arn}/*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.vite_site
  ]
}




resource "null_resource" "build_vite_site" {
  provisioner "local-exec" {
    command = "bash ../frontend/build.sh"
    environment = {
      WSLENV = "VITE_API_URL:VITE_COGNITO_POOL_ID:VITE_COGNITO_CLIENT_ID:VITE_COGNITO_REGION:VITE_COGNITO_DOMAIN:VITE_COGNITO_REDIRECT_URI:VITE_COGNITO_LOGOUT_URI"
      VITE_API_URL = var.vite_api_url
      VITE_COGNITO_POOL_ID = var.vite_cognito_pool_id
      VITE_COGNITO_CLIENT_ID = var.vite_cognito_client_id
      VITE_COGNITO_REGION = var.vite_cognito_region
      VITE_COGNITO_DOMAIN = var.vite_cognito_domain
      VITE_COGNITO_REDIRECT_URI = var.vite_cognito_redirect_uri
      VITE_COGNITO_LOGOUT_URI = var.vite_cognito_logout_uri
    }
  }
  triggers = {
    always_run = timestamp()
  }
}


resource "null_resource" "upload_vite_site" {
  provisioner "local-exec" {
    command = "aws s3 sync ../frontend/dist s3://${aws_s3_bucket.vite_site.id} --delete"
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [null_resource.build_vite_site]
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for Vite static site"
  value       = aws_s3_bucket.vite_site.id
}

output "s3_bucket_website_url" {
  description = "URL of the S3 bucket website"
  value       = "http://${aws_s3_bucket_website_configuration.vite_site.website_endpoint}"
}