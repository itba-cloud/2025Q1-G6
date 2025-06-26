# 🎓 AWS Learner Lab Setup Guide for Mercado Scraper

This guide helps you deploy the Mercado Scraper application in AWS Learner Lab environment with its specific limitations.

## 🚨 AWS Learner Lab Limitations

AWS Learner Lab has restrictions that required modifications to the original deployment:

- ❌ **Cannot create IAM roles** - Uses existing `LabRole`
- ⏰ **Session timeouts** - Lab sessions expire after a few hours
- 🔒 **Limited permissions** - Some AWS services may be restricted
- 💰 **Budget constraints** - Limited AWS credits

## ✅ Prerequisites

1. **Active AWS Learner Lab session**
2. **Docker Desktop** running on your machine
3. **AWS CLI** installed
4. **Terraform** installed
5. **Bash environment** (WSL, Git Bash, or Linux terminal)

## 🔧 Setup Steps

### Step 1: Start AWS Learner Lab Session

1. Log into your AWS Learner Lab
2. Click **"Start Lab"** and wait for it to become ready (green)
3. Click **"AWS"** to access the AWS Console
4. Click **"AWS Details"** and copy the credentials

### Step 2: Configure AWS CLI

From your terminal, configure AWS CLI with the lab credentials:

```bash
# Set AWS credentials (replace with your actual values)
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_SESSION_TOKEN="your-session-token"
export AWS_DEFAULT_REGION="us-east-1"

# OR use aws configure (but you'll need to manually add session token)
aws configure
```

**⚠️ Important**: You must include the `AWS_SESSION_TOKEN` for Learner Lab!

### Step 3: Verify AWS Access

```bash
# Test AWS connection
aws sts get-caller-identity

# You should see something like:
# "Arn": "arn:aws:sts::123456789012:assumed-role/voclabs/user123456=your-email"
```

### Step 4: Deploy Application

Make the deployment script executable and run it:

```bash
# From the project root directory
chmod +x deploy-learner-lab.sh
./deploy-learner-lab.sh
```

The script will:
1. ✅ Deploy VPC and ECR
2. 🐳 Build and push Docker images  
3. 🚀 Deploy ECS services
4. 📊 Show deployment URLs

## 🎯 What Gets Deployed

### Modified for Learner Lab:
- **IAM Roles**: Uses existing `LabRole` instead of creating new ones
- **VPC**: Multiple AZ setup for Load Balancer requirements
- **ECS**: Fargate services with proper networking
- **RDS**: PostgreSQL database in private subnets
- **ALB**: Application Load Balancer for traffic distribution

### Architecture:
```
Internet → ALB → ECS Fargate Tasks → RDS PostgreSQL
                      ↑
                 ECR Images
```

## 📱 Access Your Application

After deployment completes (2-3 minutes), you'll get URLs:

```bash
# Example output:
🌐 Frontend:  http://mercado-alb-123456789.us-east-1.elb.amazonaws.com
🔌 Backend:   http://mercado-alb-123456789.us-east-1.elb.amazonaws.com:8000
📚 API Docs:  http://mercado-alb-123456789.us-east-1.elb.amazonaws.com:8000/docs
```

## 🔍 Monitoring & Debugging

### Check ECS Services
```bash
# List services
aws ecs list-services --cluster mercado-scraper-cluster

# Check service details
aws ecs describe-services \
  --cluster mercado-scraper-cluster \
  --services mercado-backend-service mercado-frontend-service
```

### View Logs
```bash
# Backend logs
aws logs tail /ecs/mercado-backend --follow

# Frontend logs
aws logs tail /ecs/mercado-frontend --follow
```

### Check Task Status
```bash
# List running tasks
aws ecs list-tasks --cluster mercado-scraper-cluster

# Get task details
aws ecs describe-tasks \
  --cluster mercado-scraper-cluster \
  --tasks TASK_ARN_HERE
```

## 🛠️ Troubleshooting

### Common Issues:

#### 1. **IAM Permission Denied**
```
Error: AccessDenied: User is not authorized to perform: iam:CreateRole
```
**Solution**: The deployment script now uses existing `LabRole` - this error should not occur with the updated configuration.

#### 2. **Session Token Expired**
```
Error: InvalidToken: The security token included in the request is invalid
```
**Solution**: 
1. Go back to AWS Learner Lab
2. Copy new credentials from "AWS Details"
3. Update your environment variables

#### 3. **Load Balancer AZ Error**
```
Error: At least two subnets in two different Availability Zones must be specified
```
**Solution**: The VPC has been updated to create subnets in multiple AZs - this should be resolved.

#### 4. **ECS Tasks Not Starting**
Check the task definition and logs:
```bash
aws ecs describe-services --cluster mercado-scraper-cluster --services mercado-backend-service
```

#### 5. **Docker Build Failed**
Ensure Docker Desktop is running:
```bash
docker --version
docker ps
```

## 🧹 Cleanup

### Destroy Infrastructure
```bash
./deploy-learner-lab.sh destroy
```

### Or manually:
```bash
cd terraform
terraform destroy
```

**⚠️ Important**: Always clean up when done to conserve AWS credits!

## 📊 Management Commands

```bash
# Check deployment status
./deploy-learner-lab.sh status

# Destroy everything
./deploy-learner-lab.sh destroy

# Re-deploy (if needed)
./deploy-learner-lab.sh
```

## 💡 Tips for Success

1. **Start Fresh**: Begin deployment right after starting a new lab session
2. **Monitor Credits**: Keep an eye on your AWS credit usage
3. **Save Work**: Export any important data before session expires
4. **Test Quickly**: Lab sessions are time-limited, test your app promptly
5. **Document Issues**: Keep notes of any errors for troubleshooting

## 🚀 Expected Timeline

- **VPC + ECR**: 2-3 minutes
- **Image Build**: 5-10 minutes  
- **ECS Deployment**: 3-5 minutes
- **Service Startup**: 2-3 minutes
- **Total**: ~15-20 minutes

## 📞 Need Help?

If you encounter issues:

1. Check the AWS CloudFormation console for stack events
2. Review ECS service events in the AWS Console
3. Check CloudWatch logs for container errors
4. Verify your AWS credentials haven't expired

---

Your Mercado Scraper application will be running on AWS ECS with proper load balancing, logging, and monitoring! 🎉 