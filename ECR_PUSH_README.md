# ECR Push Scripts for Mercado Scraper

This repository contains scripts to build and push both backend and frontend Docker images to Amazon ECR (Elastic Container Registry).

## Prerequisites

Before running the push scripts, ensure you have the following tools installed:

1. **Docker** - For building and pushing images
2. **AWS CLI** - For ECR authentication (configured with appropriate credentials)
3. **Terraform** - For getting ECR repository information

## Scripts

### 1. `push.sh` (Bash - Linux/macOS/WSL)
A comprehensive bash script that handles the entire ECR push process.

#### Usage:
```bash
./push.sh
```

### 2. `push.ps1` (PowerShell - Windows)
A PowerShell equivalent for Windows users.

#### Usage:
```powershell
# Basic usage
.\push.ps1

# Skip cleanup prompt
.\push.ps1 -SkipCleanup
```

## What the Scripts Do

1. **Prerequisites Check**: Verifies that Docker, AWS CLI, and Terraform are installed
2. **Get ECR URL**: Retrieves the ECR repository URL from Terraform output
3. **Extract AWS Info**: Parses AWS account ID and region from the ECR URL
4. **ECR Authentication**: Authenticates Docker with ECR using AWS CLI
5. **Build Images**: Builds both backend and frontend Docker images
6. **Tag Images**: Tags images with both `latest` and timestamped versions
7. **Push Images**: Pushes all tagged images to ECR
8. **Cleanup**: Optionally removes local Docker images
9. **Summary**: Displays final deployment information

## Image Tagging Strategy

The scripts create the following tags for each image:

### Backend Images:
- `{ECR_URL}:backend-latest`
- `{ECR_URL}:backend-{timestamp}`

### Frontend Images:
- `{ECR_URL}:frontend-latest`
- `{ECR_URL}:frontend-{timestamp}`

Where `{timestamp}` is in the format `YYYYMMDD-HHMMSS`.

## Prerequisites Setup

### 1. Terraform
Make sure your Terraform infrastructure is deployed:
```bash
cd terraform
terraform apply -target="module.ecr"
terraform apply
```

### 2. AWS CLI Configuration
Ensure your AWS CLI is configured with appropriate credentials:
```bash
aws configure
```

Or use environment variables:
```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=us-east-1
```

### 3. Docker
Ensure Docker is running and you have permissions to run Docker commands.

## Troubleshooting

### Common Issues:

1. **ECR URL not found**
   - Ensure Terraform has been applied successfully
   - Check that the ECR module is properly configured

2. **Authentication failed**
   - Verify AWS CLI credentials
   - Ensure your AWS user has ECR permissions

3. **Docker build failed**
   - Check Dockerfile syntax in backend/frontend directories
   - Ensure all required files are present

4. **Permission denied**
   - On Linux/macOS: Make the script executable with `chmod +x push.sh`
   - On Windows: Ensure PowerShell execution policy allows script execution

### PowerShell Execution Policy (Windows)
If you get an execution policy error, run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Environment Variables

The scripts automatically detect the following from your Terraform configuration:
- AWS Account ID
- AWS Region
- ECR Repository URL

## Security Notes

- The scripts use temporary authentication tokens
- No sensitive information is stored permanently
- Local images can be cleaned up after push to save disk space

## Example Output

```
🚀 Starting Mercado Scraper ECR Push Process

[INFO] Checking prerequisites...
[SUCCESS] All prerequisites are available
[INFO] Getting ECR repository URL from terraform...
[SUCCESS] ECR URL: 123456789012.dkr.ecr.us-east-1.amazonaws.com/mercado-scraper
[INFO] Extracting AWS information...
[SUCCESS] AWS Account ID: 123456789012
[SUCCESS] AWS Region: us-east-1
[SUCCESS] Repository Name: mercado-scraper
[INFO] Authenticating with ECR...
[SUCCESS] Successfully authenticated with ECR
[INFO] Building Docker images...
[INFO] Building backend image...
[SUCCESS] Backend image built successfully
[INFO] Building frontend image...
[SUCCESS] Frontend image built successfully
[INFO] Tagging images for ECR...
[SUCCESS] Backend image tagged
[SUCCESS] Frontend image tagged
[INFO] Pushing images to ECR...
[INFO] Pushing backend images...
[SUCCESS] Backend images pushed successfully
[INFO] Pushing frontend images...
[SUCCESS] Frontend images pushed successfully

==================== DEPLOYMENT SUMMARY ====================

✅ Backend image pushed to:
   - 123456789012.dkr.ecr.us-east-1.amazonaws.com/mercado-scraper:backend-latest
   - 123456789012.dkr.ecr.us-east-1.amazonaws.com/mercado-scraper:backend-20231215-143022

✅ Frontend image pushed to:
   - 123456789012.dkr.ecr.us-east-1.amazonaws.com/mercado-scraper:frontend-latest
   - 123456789012.dkr.ecr.us-east-1.amazonaws.com/mercado-scraper:frontend-20231215-143022

🎉 ECR push process completed successfully! 