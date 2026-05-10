#!/bin/bash
# Complete verification script for MLOps final project
# Run after all DAGs have completed and consumer has processed messages

set -e

echo "=========================================="
echo "MLOps Final Project - Verification"
echo "=========================================="
echo ""

# 1. Training DAG Status
echo "✅ Requirement 1: Training DAG"
airflow dags list-runs -d breast_cancer_training | grep success | head -1
echo ""

# 2. Model in S3
echo "✅ Requirement 1: Model Saved to S3"
aws s3 ls s3://tony-mlops-2026/models/ | grep -E "(breast_cancer_model|model_metadata)"
echo ""

# 3. Inference DAG Status
echo "✅ Requirement 2: Inference Queue DAG"
airflow dags list-runs -d breast_cancer_inference_queue | grep success | head -1
echo ""

# 4. Queue Status (should be empty after consumer runs)
echo "✅ Requirement 2: SQS Queue Status"
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/576524850000/mlops-tonychalleen-final \
  --attribute-names ApproximateNumberOfMessages \
  --query 'Attributes.ApproximateNumberOfMessages' \
  --output text | xargs -I {} echo "Messages remaining: {}"
echo ""

# 5. Predictions Count
echo "✅ Requirement 3 & 4: Consumer Output"
PRED_COUNT=$(aws s3 ls s3://tony-mlops-2026/predictions/ | wc -l | tr -d ' ')
echo "Total predictions: $PRED_COUNT (expected: 114)"
echo ""

# 6. Sample Prediction Format
echo "✅ Requirement 4: Sample Prediction Format"
aws s3 cp s3://tony-mlops-2026/predictions/sample_0001.json - 2>/dev/null | jq -c '{record_id, prediction, has_timestamp: (.timestamp != null), has_confidence: (.confidence != null)}'
echo ""

# 7. Kubernetes Deployment YAML exists
echo "✅ Requirement 5: Kubernetes Deployment"
if [ -f "kubernetes/deployment.yaml" ]; then
    echo "deployment.yaml exists ($(wc -l < kubernetes/deployment.yaml | tr -d ' ') lines)"
    grep -E "replicas:|image:|app: ml-consumer" kubernetes/deployment.yaml | head -3
else
    echo "❌ deployment.yaml not found"
fi
echo ""

echo "=========================================="
echo "Verification Complete!"
echo "=========================================="
