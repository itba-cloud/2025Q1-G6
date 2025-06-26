# modules/ecs/variables.tf

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "sqs_queue_url" {
  description = "Queue url for scraping requests"
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks for NLB security"
  type        = list(string)
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "sqs_region" {
  description = "SQS region"
}

variable "database_url" {
  description = "Database connection URL"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "backend_image" {
  description = "Backend Docker image URI with immutable tag"
  type        = string
}



variable "scraper_image" {
  description = "Scraper Docker image URI with immutable tag"
  type        = string
} 

# Meta-argument variables for scaling
variable "backend_replicas" {
  description = "Number of backend service replicas"
  type        = number
  default     = 1
}

variable "scraper_replicas" {
  description = "Number of scraper service replicas"
  type        = number
  default     = 1
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
  default     = "dev"
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "db_access_sg_id" {
  description = "Security group ID for database access"
  type        = string
}

variable "cognito_pool_id" {
  description = "Cognito User Pool ID"
  type        = string
} 

variable "cognito_client_id" {
  description = "Cognito User-Pool Client ID"
  type        = string
}

variable "cognito_domain" {
  description = "Cognito hosted-UI domain prefix (e.g. myapp.auth.us-east-1.amazoncognito.com)"
  type        = string
}
