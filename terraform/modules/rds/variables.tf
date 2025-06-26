variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "lambda_sg_id" {
  description = "Security group ID for Lambda"
  type        = string
  default     = null
}

variable "ecs_tasks_sg_id" {
  description = "Security group ID of the ECS tasks"
  type        = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "db_subnet_group" {
  description = "RDS subnet group name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
