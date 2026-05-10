#!/bin/bash
set -e

# Configuration
ECR_REGISTRY="576524850000.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPO="mlops-tonychalleen-final"
AWS_REGION="us-east-1"
IMAGE_TAG="${1:-latest}"

echo "=========================================="
echo "Building and Pushing Docker Image"
echo "=========================================="
echo "Registry: $ECR_REGISTRY"
echo "Repository: $ECR_REPO"
echo "Tag: $IMAGE_TAG"
echo "=========================================="

# Navigate to consumer directory
cd "$(dirname "$0")/../consumer"

# Build Docker image
echo "Building Docker image..."
docker build -t ${ECR_REPO}:${IMAGE_TAG} .

# Authenticate to ECR
echo "Authenticating to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Tag image
echo "Tagging image..."
docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}

# Push to ECR
echo "Pushing to ECR..."
docker push ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}

echo "=========================================="
echo "✅ Successfully pushed image:"
echo "${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
echo "=========================================="
