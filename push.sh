#!/bin/bash

# Mercado Scraper - ECR Push Script
# This script builds and pushes both backend and frontend images to ECR

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variable for timestamp
TIMESTAMP=""

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed or not in PATH"
        exit 1
    fi
    
    print_success "All prerequisites are available"
}

# Get ECR repository URL from terraform output
get_ecr_url() {
    print_status "Getting ECR repository URL from terraform..."
    
    cd terraform
    ECR_URL=$(terraform output -raw ecr_repo_url 2>/dev/null)
    cd ..
    
    if [ -z "$ECR_URL" ]; then
        print_error "Could not get ECR URL from terraform output"
        print_error "Make sure terraform has been applied and ECR module is deployed"
        exit 1
    fi
    
    print_success "ECR URL: $ECR_URL"
}

# Extract AWS region and account ID from ECR URL
extract_aws_info() {
    print_status "Extracting AWS information..."
    
    # ECR URL format: ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/REPO_NAME
    AWS_ACCOUNT_ID=$(echo $ECR_URL | cut -d'.' -f1)
    AWS_REGION=$(echo $ECR_URL | cut -d'.' -f4)
    REPO_NAME=$(echo $ECR_URL | cut -d'/' -f2)
    
    print_success "AWS Account ID: $AWS_ACCOUNT_ID"
    print_success "AWS Region: $AWS_REGION"
    print_success "Repository Name: $REPO_NAME"
}

# Authenticate with ECR
authenticate_ecr() {
    print_status "Authenticating with ECR..."
    
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL
    
    if [ $? -eq 0 ]; then
        print_success "Successfully authenticated with ECR"
    else
        print_error "Failed to authenticate with ECR"
        exit 1
    fi
}

# Build Docker images
build_images() {
    print_status "Building Docker images..."
    
    # Build backend image
    print_status "Building backend image..."
    docker build -t mercado-backend ./backend
    if [ $? -eq 0 ]; then
        print_success "Backend image built successfully"
    else
        print_error "Failed to build backend image"
        exit 1
    fi
    
    # Build frontend image
    print_status "Building frontend image..."
    docker build -t mercado-frontend ./frontend
    if [ $? -eq 0 ]; then
        print_success "Frontend image built successfully"
    else
        print_error "Failed to build frontend image"
        exit 1
    fi
}

# Tag images for ECR
tag_images() {
    print_status "Tagging images for ECR..."
    
    # Generate timestamp once and store it
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    
    # Tag backend image
    docker tag mercado-backend:latest $ECR_URL:backend-latest
    docker tag mercado-backend:latest $ECR_URL:backend-$TIMESTAMP
    print_success "Backend image tagged"
    
    # Tag frontend image
    docker tag mercado-frontend:latest $ECR_URL:frontend-latest
    docker tag mercado-frontend:latest $ECR_URL:frontend-$TIMESTAMP
    print_success "Frontend image tagged"
}

# Push images to ECR
push_images() {
    print_status "Pushing images to ECR..."
    
    # Push backend images
    print_status "Pushing backend images..."
    docker push $ECR_URL:backend-latest
    docker push $ECR_URL:backend-$TIMESTAMP
    print_success "Backend images pushed successfully"
    
    # Push frontend images
    print_status "Pushing frontend images..."
    docker push $ECR_URL:frontend-latest
    docker push $ECR_URL:frontend-$TIMESTAMP
    print_success "Frontend images pushed successfully"
}

# Clean up local images (optional)
cleanup() {
    print_status "Cleaning up local images..."
    
    read -p "Do you want to remove local Docker images? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker rmi mercado-backend:latest || true
        docker rmi mercado-frontend:latest || true
        print_success "Local images cleaned up"
    else
        print_status "Keeping local images"
    fi
}

# Display final information
display_summary() {
    print_success "==================== DEPLOYMENT SUMMARY ===================="
    echo
    print_success "✅ Backend image pushed to:"
    echo "   - $ECR_URL:backend-latest"
    echo "   - $ECR_URL:backend-$TIMESTAMP"
    echo
    print_success "✅ Frontend image pushed to:"
    echo "   - $ECR_URL:frontend-latest"
    echo "   - $ECR_URL:frontend-$TIMESTAMP"
    echo
    print_status "You can now use these images in your ECS task definitions or other deployment configurations."
    print_success "=========================================================="
}

# Main execution
main() {
    print_success "🚀 Starting Mercado Scraper ECR Push Process"
    echo
    
    check_prerequisites
    get_ecr_url
    extract_aws_info
    authenticate_ecr
    build_images
    tag_images
    push_images
    cleanup
    display_summary
    
    print_success "🎉 ECR push process completed successfully!"
}

# Run main function
main "$@" 