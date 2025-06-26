# Mercado Scraper - ECR Push Script (PowerShell)
# This script builds and pushes both backend and frontend images to ECR

param(
    [switch]$SkipCleanup
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check if required tools are installed
function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    $tools = @("docker", "aws", "terraform")
    foreach ($tool in $tools) {
        if (!(Get-Command $tool -ErrorAction SilentlyContinue)) {
            Write-Error "$tool is not installed or not in PATH"
            exit 1
        }
    }
    
    Write-Success "All prerequisites are available"
}

# Get ECR repository URL from terraform output
function Get-EcrUrl {
    Write-Status "Getting ECR repository URL from terraform..."
    
    Push-Location terraform
    try {
        $script:EcrUrl = terraform output -raw ecr_repo_url 2>$null
        if ([string]::IsNullOrEmpty($script:EcrUrl)) {
            throw "Empty ECR URL"
        }
    }
    catch {
        Write-Error "Could not get ECR URL from terraform output"
        Write-Error "Make sure terraform has been applied and ECR module is deployed"
        exit 1
    }
    finally {
        Pop-Location
    }
    
    Write-Success "ECR URL: $script:EcrUrl"
}

# Extract AWS region and account ID from ECR URL
function Get-AwsInfo {
    Write-Status "Extracting AWS information..."
    
    # ECR URL format: ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/REPO_NAME
    $urlParts = $script:EcrUrl.Split('.')
    $script:AwsAccountId = $urlParts[0]
    $script:AwsRegion = $urlParts[3]
    $script:RepoName = $script:EcrUrl.Split('/')[1]
    
    Write-Success "AWS Account ID: $script:AwsAccountId"
    Write-Success "AWS Region: $script:AwsRegion"
    Write-Success "Repository Name: $script:RepoName"
}

# Authenticate with ECR
function Connect-Ecr {
    Write-Status "Authenticating with ECR..."
    
    try {
        $loginToken = aws ecr get-login-password --region $script:AwsRegion
        $loginToken | docker login --username AWS --password-stdin $script:EcrUrl
        Write-Success "Successfully authenticated with ECR"
    }
    catch {
        Write-Error "Failed to authenticate with ECR"
        exit 1
    }
}

# Build Docker images
function Build-Images {
    Write-Status "Building Docker images..."
    
    # Build backend image
    Write-Status "Building backend image..."
    docker build -t mercado-backend ./backend
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build backend image"
        exit 1
    }
    Write-Success "Backend image built successfully"
    
    # Build frontend image
    Write-Status "Building frontend image..."
    docker build -t mercado-frontend ./frontend
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build frontend image"
        exit 1
    }
    Write-Success "Frontend image built successfully"
}

# Tag images for ECR
function Set-ImageTags {
    Write-Status "Tagging images for ECR..."
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    
    # Tag backend image
    docker tag mercado-backend:latest "$script:EcrUrl`:backend-latest"
    docker tag mercado-backend:latest "$script:EcrUrl`:backend-$timestamp"
    Write-Success "Backend image tagged"
    
    # Tag frontend image
    docker tag mercado-frontend:latest "$script:EcrUrl`:frontend-latest"
    docker tag mercado-frontend:latest "$script:EcrUrl`:frontend-$timestamp"
    Write-Success "Frontend image tagged"
    
    $script:Timestamp = $timestamp
}

# Push images to ECR
function Push-Images {
    Write-Status "Pushing images to ECR..."
    
    # Push backend images
    Write-Status "Pushing backend images..."
    docker push "$script:EcrUrl`:backend-latest"
    docker push "$script:EcrUrl`:backend-$script:Timestamp"
    Write-Success "Backend images pushed successfully"
    
    # Push frontend images
    Write-Status "Pushing frontend images..."
    docker push "$script:EcrUrl`:frontend-latest"
    docker push "$script:EcrUrl`:frontend-$script:Timestamp"
    Write-Success "Frontend images pushed successfully"
}

# Clean up local images (optional)
function Remove-LocalImages {
    if ($SkipCleanup) {
        Write-Status "Skipping cleanup as requested"
        return
    }
    
    Write-Status "Cleaning up local images..."
    
    $response = Read-Host "Do you want to remove local Docker images? (y/N)"
    if ($response -match "^[Yy]$") {
        try {
            docker rmi mercado-backend:latest -ErrorAction SilentlyContinue
            docker rmi mercado-frontend:latest -ErrorAction SilentlyContinue
            Write-Success "Local images cleaned up"
        }
        catch {
            # Ignore errors during cleanup
        }
    }
    else {
        Write-Status "Keeping local images"
    }
}

# Display final information
function Show-Summary {
    Write-Success "==================== DEPLOYMENT SUMMARY ===================="
    Write-Host ""
    Write-Success "✅ Backend image pushed to:"
    Write-Host "   - $script:EcrUrl`:backend-latest"
    Write-Host "   - $script:EcrUrl`:backend-$script:Timestamp"
    Write-Host ""
    Write-Success "✅ Frontend image pushed to:"
    Write-Host "   - $script:EcrUrl`:frontend-latest"
    Write-Host "   - $script:EcrUrl`:frontend-$script:Timestamp"
    Write-Host ""
    Write-Status "You can now use these images in your ECS task definitions or other deployment configurations."
    Write-Success "=========================================================="
}

# Main execution
function Main {
    Write-Success "🚀 Starting Mercado Scraper ECR Push Process"
    Write-Host ""
    
    Test-Prerequisites
    Get-EcrUrl
    Get-AwsInfo
    Connect-Ecr
    Build-Images
    Set-ImageTags
    Push-Images
    Remove-LocalImages
    Show-Summary
    
    Write-Success "🎉 ECR push process completed successfully!"
}

# Run main function
try {
    Main
}
catch {
    Write-Error "Script failed: $_"
    exit 1
} 