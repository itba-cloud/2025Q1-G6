#!/bin/bash

# AWS Learner Lab Deployment Script for Mercado Scraper
# This script handles the specific limitations of AWS Learner Lab

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_header() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Check if we're in the right directory
check_directory() {
    if [[ ! -d "terraform" ]] || [[ ! -f "push.sh" ]]; then
        print_error "Please run this script from the project root directory"
        print_error "Expected structure: terraform/, backend/, frontend/, push.sh"
        exit 1
    fi
}

# Check AWS credentials
check_aws_credentials() {
    print_status "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity &>/dev/null; then
        print_error "AWS credentials not configured or expired"
        print_error "Please ensure you're logged into AWS Learner Lab and have copied the credentials"
        exit 1
    fi
    
    # Check if we're using LabRole
    IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text)
    if [[ $IDENTITY == *"LabRole"* ]] || [[ $IDENTITY == *"voclabs"* ]]; then
        print_success "AWS Learner Lab credentials detected"
    else
        print_warning "Not using AWS Learner Lab credentials - some features may not work"
    fi
}

# Deploy infrastructure step by step
deploy_infrastructure() {
    print_header "STEP 1: DEPLOYING BASE INFRASTRUCTURE"
    
    cd terraform
    
    print_status "Initializing Terraform..."
    terraform init
    
    print_status "Deploying VPC and ECR first..."
    terraform apply -target="module.vpc" -target="module.ecr" -auto-approve
    
    if [ $? -eq 0 ]; then
        print_success "Base infrastructure deployed successfully"
    else
        print_error "Failed to deploy base infrastructure"
        exit 1
    fi
    
    cd ..
}

# Build and push images
build_and_push_images() {
    print_header "STEP 2: BUILDING AND PUSHING DOCKER IMAGES"
    
    print_status "Making push script executable..."
    chmod +x push.sh
    
    print_status "Running image build and push..."
    ./push.sh
    
    if [ $? -eq 0 ]; then
        print_success "Images built and pushed successfully"
    else
        print_error "Failed to build/push images"
        print_error "Check Docker is running and ECR access is available"
        exit 1
    fi
}

# Deploy ECS services
deploy_ecs() {
    print_header "STEP 3: DEPLOYING ECS SERVICES"
    
    cd terraform
    
    print_status "Deploying RDS database..."
    terraform apply -target="module.rds" -auto-approve
    
    print_status "Deploying ECS cluster and services..."
    terraform apply -target="module.ecs" -auto-approve
    
    if [ $? -eq 0 ]; then
        print_success "ECS services deployed successfully"
    else
        print_error "Failed to deploy ECS services"
        cd ..
        exit 1
    fi
    
    cd ..
}

# Get deployment information
show_deployment_info() {
    print_header "DEPLOYMENT COMPLETED SUCCESSFULLY!"
    
    cd terraform
    
    echo ""
    print_success "🎉 Your Mercado Scraper is now running on AWS!"
    echo ""
    
    print_status "Application URLs:"
    FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null)
    BACKEND_URL=$(terraform output -raw backend_url 2>/dev/null)
    ALB_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null)
    
    if [[ -n "$FRONTEND_URL" ]]; then
        echo "   🌐 Frontend:  $FRONTEND_URL"
    fi
    
    if [[ -n "$BACKEND_URL" ]]; then
        echo "   🔌 Backend:   $BACKEND_URL"
        echo "   📚 API Docs:  $BACKEND_URL/docs"
    fi
    
    if [[ -n "$ALB_DNS" ]]; then
        echo "   ⚖️  Load Balancer: $ALB_DNS"
    fi
    
    echo ""
    print_status "Next steps:"
    echo "   1. Wait 2-3 minutes for services to start"
    echo "   2. Check ECS service status: aws ecs list-services --cluster mercado-scraper-cluster"
    echo "   3. View logs: aws logs tail /ecs/mercado-backend --follow"
    echo "   4. Test your application using the URLs above"
    
    echo ""
    print_warning "⚠️  AWS Learner Lab Notes:"
    echo "   - Sessions expire after a few hours"
    echo "   - Resources will be terminated when lab session ends"
    echo "   - Save any important data before session expires"
    
    cd ..
}

# Cleanup function
cleanup_on_error() {
    print_error "Deployment failed. Cleaning up..."
    cd terraform 2>/dev/null || true
    terraform destroy -auto-approve 2>/dev/null || true
    cd .. 2>/dev/null || true
}

# Main execution
main() {
    print_header "AWS LEARNER LAB - MERCADO SCRAPER DEPLOYMENT"
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    check_directory
    check_aws_credentials
    deploy_infrastructure
    build_and_push_images
    deploy_ecs
    show_deployment_info
    
    print_success "🚀 Deployment completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    "destroy")
        print_header "DESTROYING INFRASTRUCTURE"
        cd terraform
        terraform destroy
        cd ..
        print_success "Infrastructure destroyed"
        ;;
    "status")
        print_header "DEPLOYMENT STATUS"
        cd terraform
        terraform output
        cd ..
        ;;
    *)
        main
        ;;
esac 