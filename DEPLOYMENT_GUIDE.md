# 🚀 Mercado Scraper - Complete Deployment Guide

This guide covers deploying your Mercado Scraper application to AWS using ECS with ECR for container management.

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Deployment Options](#deployment-options)
4. [Method 1: Manual Image Push + Terraform (Recommended)](#method-1-manual-image-push--terraform-recommended)
5. [Method 2: Terraform-Automated Image Building](#method-2-terraform-automated-image-building)
6. [Post-Deployment](#post-deployment)
7. [Troubleshooting](#troubleshooting)

## 🏗️ Architecture Overview

Your deployed application will have:

- **VPC**: Isolated network environment
- **ECR**: Docker image registry
- **ECS Fargate**: Serverless container orchestration
- **Application Load Balancer**: Traffic distribution
- **RDS PostgreSQL**: Managed database
- **CloudWatch**: Logging and monitoring

```
Internet → ALB → ECS Tasks (Frontend + Backend) → RDS
                     ↑
                   ECR Images
```

## ✅ Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **Terraform** >= 1.0
3. **Docker** installed and running
4. **Bash/PowerShell** for running scripts

## 🎯 Deployment Options

### Option A: Separate Image Building (Recommended)
- Use dedicated push scripts for image management
- Keep infrastructure and application deployment separate
- Better for CI/CD integration

### Option B: Terraform-Integrated Building  
- Build images as part of Terraform deployment
- Good for testing/development environments
- Not recommended for production

---

## 🔧 Method 1: Manual Image Push + Terraform (Recommended)

### Step 1: Deploy Infrastructure First

```bash
cd terraform

# Deploy ECR first
terraform apply -target="module.ecr"
```

### Step 2: Build and Push Images

**Option 2a: Using Bash Script (Linux/macOS/WSL)**
```bash
# Make executable and run
chmod +x push.sh
./push.sh
```

**Option 2b: Using PowerShell Script (Windows)**
```powershell
# Run the PowerShell script
.\push.ps1

# Or skip cleanup prompts
.\push.ps1 -SkipCleanup
```

### Step 3: Deploy ECS Infrastructure

```bash
cd terraform

# Deploy everything else
terraform apply
```

### Step 4: Get Application URLs

```bash
# Get the frontend URL
terraform output frontend_url

# Get the backend API URL  
terraform output backend_url
```

---

## ⚙️ Method 2: Terraform-Automated Image Building

**⚠️ Note**: This method is provided for completeness but not recommended for production.

### Step 1: Enable Auto-Building

Add to your `terraform.tfvars`:

```hcl
# Optional: Enable automatic image building via Terraform
auto_build_images = true
force_rebuild = false
cleanup_local_images = true
```

### Step 2: Update Main Terraform Configuration

Add the ECR build module to `terraform/main.tf`:

```hcl
module "ecr_build" {
  source = "./modules/ecr_build"
  
  ecr_repository_url = module.ecr.ecr_repo_url
  repository_name    = "mercado-scraper"
  aws_region         = var.aws_region
  project_root       = "${path.root}/.."
  
  auto_build_images   = var.auto_build_images
  force_rebuild       = var.force_rebuild
  cleanup_local_images = var.cleanup_local_images
}
```

### Step 3: Add Variables

Add to `terraform/variables.tf`:

```hcl
variable "auto_build_images" {
  description = "Whether to automatically build and push images via Terraform"
  type        = bool
  default     = false
}

variable "force_rebuild" {
  description = "Force rebuild of images even if they exist"
  type        = bool
  default     = false
}

variable "cleanup_local_images" {
  description = "Whether to cleanup local Docker images after pushing"
  type        = bool
  default     = true
}
```

### Step 4: Deploy Everything

```bash
cd terraform
terraform apply
```

---

## 🎊 Post-Deployment

### Verify Deployment

1. **Check ECS Services**:
   ```bash
   aws ecs list-services --cluster mercado-scraper-cluster
   ```

2. **Check Task Status**:
   ```bash
   aws ecs list-tasks --cluster mercado-scraper-cluster
   ```

3. **View Logs**:
   ```bash
   # Backend logs
   aws logs tail /ecs/mercado-backend --follow
   
   # Frontend logs  
   aws logs tail /ecs/mercado-frontend --follow
   ```

### Access Your Application

```bash
# Get URLs from Terraform
terraform output frontend_url    # Main application
terraform output backend_url     # API endpoint
terraform output load_balancer_dns  # Load balancer
```

### Test Endpoints

```bash
# Test backend health (adjust path as needed)
curl $(terraform output -raw backend_url)/health

# Test frontend
curl $(terraform output -raw frontend_url)
```

---

## 🐛 Troubleshooting

### Common Issues

#### 1. **ECR Authentication Failed**
```bash
# Re-authenticate Docker with ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ECR_URL
```

#### 2. **ECS Tasks Not Starting**
```bash
# Check task definition
aws ecs describe-task-definition --task-definition mercado-backend

# Check service events
aws ecs describe-services --cluster mercado-scraper-cluster --services mercado-backend-service
```

#### 3. **Database Connection Issues**
- Verify RDS security groups allow ECS task connections
- Check database URL format in task definition
- Ensure RDS is in the same VPC as ECS tasks

#### 4. **Load Balancer Health Checks Failing**
- Verify your application responds to health check paths
- Check security group rules
- Ensure containers are listening on correct ports

### Update Images

#### Using Push Scripts:
```bash
# Rebuild and push new images
./push.sh
```

#### Force ECS Service Update:
```bash
aws ecs update-service \
  --cluster mercado-scraper-cluster \
  --service mercado-backend-service \
  --force-new-deployment

aws ecs update-service \
  --cluster mercado-scraper-cluster \
  --service mercado-frontend-service \
  --force-new-deployment
```

### Scale Services

```bash
# Scale backend to 2 instances
aws ecs update-service \
  --cluster mercado-scraper-cluster \
  --service mercado-backend-service \
  --desired-count 2
```

### View Resource Usage

```bash
# ECS service metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=mercado-backend-service \
  --start-time 2023-01-01T00:00:00Z \
  --end-time 2023-01-01T23:59:59Z \
  --period 3600 \
  --statistics Average
```

---

## 🔒 Security Notes

1. **Database Password**: Update the hardcoded password in RDS module
2. **Environment Variables**: Consider using AWS Secrets Manager
3. **Network Security**: Review security group rules
4. **IAM Roles**: Follow principle of least privilege

---

## 💰 Cost Optimization

1. **ECS Tasks**: Start with t3.nano/micro for testing
2. **RDS**: Use db.t3.micro for development
3. **Load Balancer**: Consider using Network Load Balancer for lower costs
4. **Auto Scaling**: Implement to handle traffic variations

---

## 🚀 Next Steps

1. **Set up CI/CD**: Integrate with GitHub Actions or AWS CodePipeline
2. **Monitoring**: Set up CloudWatch alarms and dashboards
3. **Domain**: Configure Route 53 and SSL certificates
4. **Auto Scaling**: Implement ECS auto scaling policies
5. **Backup**: Set up RDS automated backups

---

## 📝 Configuration Files Summary

After following this guide, you'll have:

- ✅ `terraform/modules/ecs/` - Complete ECS infrastructure
- ✅ `terraform/modules/ecr_build/` - Optional automated building
- ✅ `push.sh` / `push.ps1` - Manual image building scripts
- ✅ Updated main Terraform configuration
- ✅ Load balancer with health checks
- ✅ CloudWatch logging
- ✅ Proper IAM roles and security groups

Your application will be accessible via the Application Load Balancer DNS name provided in the Terraform outputs! 