variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
}

variable "user_pool_id" {
  description = "Cognito User Pool ID"
  type        = string
}

# variable "client_id" {
#   description = "Cognito User Pool Client ID"
#   type        = string
# }

variable "cognito_region" {
  description = "AWS region where Cognito is deployed"
  type        = string
}

variable "redirect_url_ok" {
  description = "HTTP URL to redirect to after successful authentication"
  type        = string
}

variable "cognito_domain" {
  description = "Cognito hosted UI domain"
  type        = string
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "client_id"   { type = string }
variable "client_secret" { type = string }
variable "alb_dns"     { type = string }

variable "api_gateway_id" {
  description = "ID of the API Gateway"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  type        = string
}

variable "api_gateway_stage_invoke_url" {
  description = "Invoke URL of the API Gateway stage"
  type        = string
}