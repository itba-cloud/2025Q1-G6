# Default tags for all resources
locals {
  default_tags = {
    Project   = "mercado-scraper"
    ManagedBy = "Terraform"
    Owner     = "Cloud-Course"
  }
}

# Create API Gateways for each environment (outside auth_proxy module)
resource "aws_apigatewayv2_api" "cognito_callback" {
  for_each = var.environments
  
  name          = "${each.key}-cognito-callback-api"
  protocol_type = "HTTP"
  description   = "HTTPS proxy for Cognito callback URLs"

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["*"]
    allow_methods     = ["*"]
    allow_origins     = ["*"]
    max_age          = 86400
  }

  tags = local.default_tags
}

# Create stages for each API Gateway
resource "aws_apigatewayv2_stage" "prod" {
  for_each = var.environments
  
  api_id      = aws_apigatewayv2_api.cognito_callback[each.key].id
  name        = "prod"
  auto_deploy = true

  tags = local.default_tags
}

# Output the callback URLs (these are now known immediately)
locals {
  cognito_callback_urls = {
    for env, api in aws_apigatewayv2_api.cognito_callback :
    env => "${aws_apigatewayv2_stage.prod[env].invoke_url}/callback"
  }
  
  # Add logout URLs to locals
  cognito_logout_urls = {
    for env, api in aws_apigatewayv2_api.cognito_callback :
    env => "${aws_apigatewayv2_stage.prod[env].invoke_url}/logout"
  }
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr     = var.vpc_cidr
  environment  = "dev" # Default environment for shared resources
  default_tags = local.default_tags
}

module "ecr" {
  source = "./modules/ecr"
}

output "ecr_repo_url" {
  value = module.ecr.ecr_repo_url
}

/* module "ec2" {
  source            = "./modules/ec2"
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_id
  private_subnet_id = module.vpc.private_subnet_id
  ami_id            = var.ami_id
  key_pair_name     = var.key_pair_name
  my_ip             = var.my_ip
} */

module "sqs" {
  source = "./modules/sqs"
}

resource "aws_security_group" "lambda" {
  name   = "lambda-sg"
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.default_tags
}

# Security group for database access from ECS tasks
resource "aws_security_group" "db_access" {
  name        = "mercado-db-access"
  description = "Security group for database access from ECS tasks"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.default_tags
}

module "rds" {
  for_each = var.environments
  source   = "./modules/rds"

  # Environment-specific configuration
  environment    = each.key
  instance_class = each.value.db_instance_class

  # Common configuration
  vpc_id             = module.vpc.vpc_id
  ecs_tasks_sg_id    = aws_security_group.db_access.id
  db_subnet_group    = module.vpc.db_subnet_group
  private_subnet_ids = module.vpc.private_subnet_ids
  lambda_sg_id       = aws_security_group.lambda.id
  db_password        = var.db_password
}

module "ecr_build" {
  source = "./modules/ecr_build"

  # Required variables for the build module
  ecr_repository_url = module.ecr.ecr_repo_url
  aws_region         = var.aws_region
  repository_name    = "mercado-scraper" # Match the ECR repo name
  project_root       = ".."              # Parent directory with backend/frontend folders
  auto_build_images  = true              # Enable building!
  vite_url = module.s3.s3_bucket_website_url

  depends_on = [module.ecr,module.s3.s3_bucket_website_url] # Ensure ECR and S3 are created first
}


module "ecs" {
  for_each = var.environments
  source   = "./modules/ecs"

  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  private_subnet_cidrs = module.vpc.private_subnet_cidrs  # ADD THIS LINE
  ecr_repository_url = module.ecr.ecr_repo_url
  database_url       = module.rds[each.key].database_url
  aws_region         = var.aws_region
  db_access_sg_id    = aws_security_group.db_access.id

  # Environment-specific configuration
  environment       = each.key
  backend_replicas  = each.value.backend_replicas
  scraper_replicas  = each.value.scraper_replicas
  default_tags      = local.default_tags

  # Use image URIs from ECR build module with immutable tags
  backend_image  = module.ecr_build.backend_image
  scraper_image  = module.ecr_build.scraper_image

  sqs_queue_url = module.sqs.scraper_sqs_queue_url
  sqs_region    = var.aws_region

  cognito_pool_id = aws_cognito_user_pool.mercado.id
  cognito_client_id = aws_cognito_user_pool_client.spa.id
  cognito_domain    = aws_cognito_user_pool_domain.this.domain


  depends_on = [module.ecr_build,module.sqs]
}

# Monitoring module for each environment
module "monitoring" {
  for_each = var.environments
  source   = "./modules/monitoring"

  environment              = each.key
  ecs_cluster_name         = module.ecs[each.key].ecs_cluster_name
  ecs_service_name         = "${each.key}-mercado-backend-service"
  load_balancer_arn_suffix = module.ecs[each.key].load_balancer_arn_suffix
  tags                     = local.default_tags
}

module "lambda" {
  source                    = "./modules/lambda"
  sqs_queue_url             = module.sqs.scraper_sqs_queue_url
  sqs_region                = var.aws_region
  database_url              = module.rds["prod"].database_url # Lambda uses prod DB by default
  lambda_subnet_ids         = module.vpc.private_subnet_ids
  lambda_security_group_ids = [aws_security_group.lambda.id]
}

# Auth proxy for Cognito HTTPS callback
module "auth_proxy" {
  for_each = var.environments
  source   = "./modules/auth_proxy"

  environment     = each.key
  user_pool_id    = aws_cognito_user_pool.mercado.id
  client_id       = aws_cognito_user_pool_client.spa.id
  client_secret   = aws_cognito_user_pool_client.spa.client_secret
  cognito_region  = var.aws_region
  redirect_url_ok = "${module.s3.s3_bucket_website_url}/login"
  cognito_domain  = aws_cognito_user_pool_domain.this.domain
  default_tags    = local.default_tags
  alb_dns         = module.s3.s3_bucket_website_url
  
  # Pass API Gateway info
  api_gateway_id               = aws_apigatewayv2_api.cognito_callback[each.key].id
  api_gateway_execution_arn    = aws_apigatewayv2_api.cognito_callback[each.key].execution_arn
  api_gateway_stage_invoke_url = aws_apigatewayv2_stage.prod[each.key].invoke_url

  depends_on = [
    module.ecs,
    module.s3,
    aws_apigatewayv2_api.cognito_callback,
    aws_apigatewayv2_stage.prod
  ]
}

# ECS-related outputs for each environment
output "ecs_cluster_names" {
  description = "Names of the ECS clusters by environment"
  value       = { for env, ecs in module.ecs : env => ecs.ecs_cluster_name }
}

output "backend_urls" {
  description = "Backend API URLs by environment"
  value       = { for env, ecs in module.ecs : env => ecs.backend_url }
}



output "load_balancer_dns_names" {
  description = "Load balancer DNS names by environment"
  value       = { for env, ecs in module.ecs : env => ecs.load_balancer_dns_name }
}

output "monitoring_sns_topics" {
  description = "SNS topic ARNs for monitoring alerts by environment"
  value       = { for env, mon in module.monitoring : env => mon.sns_topic_arn }
}

output "rds_endpoints" {
  description = "RDS endpoints by environment"
  value       = { for env, rds in module.rds : env => rds.rds_endpoint }
}

output "database_urls" {
  description = "Database connection URLs by environment"
  value       = { for env, rds in module.rds : env => rds.database_url }
  sensitive   = true
}

# -------------------------------------
# Cognito User Pool for SPA authentication
# -------------------------------------

resource "aws_cognito_user_pool" "mercado" {
  name                     = "mercado-scraper-user-pool"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_symbols   = false
    require_numbers   = false
    require_uppercase = false
    require_lowercase = true
  }

  tags = local.default_tags
}

# Create Cognito User Pool Client early (before ECS)
resource "aws_cognito_user_pool_client" "spa" {
  name         = "mercado-scraper-spa-client"
  user_pool_id = aws_cognito_user_pool.mercado.id

  generate_secret              = true
  supported_identity_providers = ["COGNITO"]

  # Use the callback URLs from local
  callback_urls = values(local.cognito_callback_urls)
  
  # Temporary placeholder for logout URLs - will be updated later
  logout_urls = values(local.cognito_logout_urls)
  
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  depends_on = [
    aws_cognito_user_pool.mercado,
    aws_apigatewayv2_stage.prod
  ]
}

resource "random_pet" "cognito_domain" {
  length = 2
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = "mercado-${random_pet.cognito_domain.id}"
  user_pool_id = aws_cognito_user_pool.mercado.id
}


module "s3" {
  source = "./modules/s3"
  
  # Required variables for the S3 module
  vite_build_folder = "../frontend/dist"  # Path to Vite build output
  vite_api_url = module.ecs["prod"].backend_url   # Use the backend_url output from the ECS module
  vite_cognito_pool_id = aws_cognito_user_pool.mercado.id
  vite_cognito_client_id = aws_cognito_user_pool_client.spa.id
  vite_cognito_region = var.aws_region
  vite_cognito_domain = aws_cognito_user_pool_domain.this.domain
  vite_cognito_redirect_uri = local.cognito_callback_urls["prod"]  # Use prod callback URL
  vite_cognito_logout_uri = local.cognito_logout_urls["prod"]      # Use prod logout URL
  
  
}

output "name_of_s3_bucket" {
  description = "Name of the S3 bucket for Vite static site"
  value       = module.s3.s3_bucket_name
  
}

output "s3_bucket_website_url" {
  description = "URL of the S3 bucket website"
  value       = module.s3.s3_bucket_website_url
}

output "cognito_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = "http://${aws_cognito_user_pool.mercado.id}"
}

output "cognito_client_id" {
  description = "ID of the Cognito User Pool client"
  value       = aws_cognito_user_pool_client.spa.id
}

output "cognito_domain" {
  description = "Cognito hosted UI domain"
  value       = aws_cognito_user_pool_domain.this.domain
}

output "cognito_callback_urls" {
  description = "HTTPS callback URLs for Cognito by environment"
  value       = local.cognito_callback_urls
}

output "cognito_logout_urls" {
  description = "HTTPS logout URLs for Cognito by environment"
  value       = local.cognito_logout_urls
}

