variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}
# variables.tf

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet"
}


variable "private_subnet_cidr" {
  type        = string
  description = "CIDR block for the private subnet"
}

variable "availability_zone" {
  type        = string
  description = "AWS availability zone"
}

/* variable "ssh_key_pair_name" {
  type        = string
  description = "The name of the SSH key pair"
} */

variable "public_key_path" {
  type        = string
  description = "Path to your SSH public key"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Password for the RDS instance"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "key_pair_name" {
  description = "Key pair name for SSH access"
  type        = string
}

variable "my_ip" {
  description = "Your IP address with /32 for SSH"
  type        = string
}

# New variables for multi-environment support and meta-arguments
variable "environments" {
  description = "Configuration for different environments"
  type = map(object({
    instance_type     = string
    backend_replicas  = number
    scraper_replicas  = number
    db_instance_class = string # Add RDS instance class per environment
  }))
  default = {
    # dev = {
    #   instance_type     = "t2.micro"
    #   backend_replicas  = 1
    #   frontend_replicas = 1
    #   scraper_replicas  = 0
    #   db_instance_class = "db.t4g.micro" # Small instance for dev
    # }
    prod = {
      instance_type     = "t2.small"
      backend_replicas  = 2
      scraper_replicas  = 1
      db_instance_class = "db.t3.small" # Larger instance for prod
    }
  }
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "mercado-scraper"
    ManagedBy = "Terraform"
    Owner     = "Cloud-Course"
  }
}
