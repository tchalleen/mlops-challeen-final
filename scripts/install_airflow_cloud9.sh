#!/bin/bash
set -e

echo "=========================================="
echo "Installing Airflow for AWS Cloud9"
echo "=========================================="

# Check Python version
PYTHON_VERSION=$(python3 --version | cut -d " " -f 2 | cut -d "." -f 1-2)
echo "Python version: $PYTHON_VERSION"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install Airflow using constraints file (avoids compilation errors)
echo "Installing Apache Airflow with constraints..."
AIRFLOW_VERSION=2.10.0
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"

echo "Using constraints: $CONSTRAINT_URL"

pip install "apache-airflow==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"

# Install additional providers and dependencies
echo "Installing additional packages..."
pip install apache-airflow-providers-amazon
pip install boto3==1.34.51
pip install scikit-learn==1.4.1.post1
pip install joblib==1.3.2
pip install numpy==1.26.4

echo "=========================================="
echo "✅ Airflow installation complete!"
echo ""
echo "Next steps:"
echo "  1. Run: ./scripts/setup_airflow.sh"
echo "  2. Start: ./scripts/start_airflow_cloud9.sh"
echo "  3. Access via Cloud9 Preview"
echo "=========================================="
