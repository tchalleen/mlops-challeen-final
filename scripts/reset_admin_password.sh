#!/bin/bash
set -e

echo "=========================================="
echo "Resetting Airflow Admin Password"
echo "=========================================="

# Set Airflow home
export AIRFLOW_HOME=$(pwd)/airflow

# Delete existing admin user
echo "Removing existing admin user..."
airflow users delete --username admin 2>/dev/null || echo "No existing admin user found"

# Create new admin user
echo "Creating new admin user..."
airflow users create \
  --username admin \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@example.com \
  --password admin

echo "=========================================="
echo "✅ Admin user reset complete!"
echo ""
echo "Credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo "=========================================="
