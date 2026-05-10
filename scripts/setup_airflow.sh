#!/bin/bash
set -e

echo "=========================================="
echo "Setting up Airflow Environment"
echo "=========================================="

# Set Airflow home
export AIRFLOW_HOME=$(pwd)/airflow
echo "AIRFLOW_HOME set to: $AIRFLOW_HOME"

# Create necessary directories
mkdir -p $AIRFLOW_HOME/dags
mkdir -p $AIRFLOW_HOME/logs
mkdir -p $AIRFLOW_HOME/plugins

# Copy DAGs
echo "Copying DAGs..."
cp dags/*.py $AIRFLOW_HOME/dags/

# Initialize database
echo "Initializing Airflow database..."
airflow db init

# Create admin user
echo "Creating admin user..."
airflow users create \
  --username admin \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@example.com \
  --password admin

echo "=========================================="
echo "✅ Airflow setup complete!"
echo ""
echo "To start Airflow:"
echo "  Terminal 1: airflow webserver --port 8080"
echo "  Terminal 2: airflow scheduler"
echo ""
echo "Access UI at: http://localhost:8080"
echo "Username: admin"
echo "Password: admin"
echo "=========================================="
