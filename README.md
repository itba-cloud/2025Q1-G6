# 🛒 Mercado-scraping

A Terraform-based deployment for scraping data from MercadoLibre. This project sets up the necessary infrastructure and backend components to run the scraper and the ui.

## 🚀 Deployment Instructions

To deploy the project, navigate to the `terraform` folder and run the following command:

```bash
terraform init
terraform apply
```

> 🕒 **Note:**  
> The first deployment will take ~20 minutes due to the size of the backend.
> Grab a cup of coffee and relax.

Once the deployment is complete, the output in the console will include the relevant links (e.g., API endpoints).

## ⚠️ API Boot Delay
Even after the container is running, the API may take a few extra minutes to start responding.
This is expected behavior — the backend takes a moment to fully boot up.

# Terraform Modules Overview

This document describes the purpose and functionality of each Terraform module provided in this project under the `terraform/modules` directory.

## Modules

### EC2 Module (`terraform/modules/ec2`)
- **Files**: `back.tf`, `front.tf`, `outputs.tf`, `variables.tf`
- **Purpose**: Provisions EC2 instances for hosting backend and frontend components. It includes configuration for instance types, security groups, and networking settings needed to support the application’s compute requirements.

### ECR Module (`terraform/modules/ecr`)
- **Files**: `main.tf`
- **Purpose**: Sets up an Amazon Elastic Container Registry (ECR) repository for storing Docker images. This module creates the repository and configures its access policies to facilitate secure image storage.

### ECR Build Module (`terraform/modules/ecr_build`)
- **Files**: `main.tf`, `outputs.tf`, `variables.tf`
- **Purpose**: Automates the process of building Docker images and pushing them to the ECR repository. It retrieves repository details from the ECR module and manages image tagging (both latest and timestamped versions).

### ECS Module (`terraform/modules/ecs`)
- **Files**: `main.tf`, `outputs.tf`, `variables.tf`
- **Purpose**: Configures the Amazon Elastic Container Service (ECS) cluster and associated services. This module creates ECS Fargate tasks for running both backend and frontend containers, sets up service definitions, and configures load balancers for distributing traffic.

### Lamda Module (`terraform/modules/lamda`)
- **Files**: `main.tf`
- **Purpose**: Deploys AWS Lambda functions as required by the system. This module can be used to implement event-driven backend functionality or microservices that complement the main application.

### RDS Module (`terraform/modules/rds`)
- **Files**: `main.tf`, `variables.tf`
- **Purpose**: Provisions an Amazon RDS PostgreSQL database instance. It manages database instance creation, parameter configurations, and security settings to ensure reliable and secure database operations.

### SQS Module (`terraform/modules/sqs`)
- **Files**: `main.tf`, `output.tf`
- **Purpose**: Sets up Amazon Simple Queue Service (SQS) queues to enable asynchronous messaging between different components of the application. This decouples services and supports scalable task processing.

### VPC Module (`terraform/modules/vpc`)
- **Files**: `main.tf`, `variables.tf`
- **Purpose**: Establishes a Virtual Private Cloud (VPC) with associated subnets, route tables, and security groups. This module provides an isolated network environment that ensures secure communication between all deployed AWS resources.

## Terraform Functions and Meta-Arguments

Terraform leverages built-in functions and meta-arguments to create dynamic and robust configurations.

### Terraform Functions

- **jsonencode(object)**  
  Converts a map or list into a JSON string. This is useful for generating JSON formatted values, such as container definitions for ECS tasks.

- **file(path)**  
  Reads the contents of a file. Often used to import external data like SSH keys or configuration files into your Terraform configuration.

- **timestamp() and formatdate(format, timestamp)**  
  `timestamp()` returns the current date and time, and `formatdate()` formats a timestamp according to the specified format. These functions are typically used to generate immutable, timestamped tags for Docker images.

### Meta-Arguments

- **depends_on**  
  Specifies explicit dependencies between resources or modules. This ensures that resources are created or updated in the proper order (e.g., ensuring that an image is built before deploying ECS tasks).

- **triggers**  
  Used within resources (such as `null_resource`) to force a re-creation when certain defined values change. This is particularly useful when external factors (like a Docker tag) need to prompt a new build or deployment.

- **count and for_each**  
  Allow you to create multiple instances of a resource. `count` is for a fixed number of instances, and `for_each` is for iterating over a collection. These meta-arguments enhance reusability and scalability of your configuration.

- **lifecycle**  
  Provides control over resource behavior during creation, update, or deletion. For example, the `create_before_destroy` setting can be used to minimize downtime during updates.