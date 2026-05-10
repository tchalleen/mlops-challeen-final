#!/bin/bash
set -e

echo "=========================================="
echo "Setting up Airflow Environment"
echo "=========================================="

# Detect if running in Cloud9
if [ -n "$C9_USER" ] || [ -n "$C9_PROJECT" ]; then
    echo "🌩️  AWS Cloud9 detected"
    IS_CLOUD9=true
else
    echo "💻 Local environment detected"
    IS_CLOUD9=false
fi

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

# Configure for Cloud9 if needed
if [ "$IS_CLOUD9" = true ]; then
    echo "Configuring Airflow for Cloud9..."
    
    # Bind to 0.0.0.0 for Cloud9
    sed -i 's/web_server_host = 127.0.0.1/web_server_host = 0.0.0.0/' $AIRFLOW_HOME/airflow.cfg
    sed -i 's|base_url = http://localhost:8080|base_url = http://0.0.0.0:8080|' $AIRFLOW_HOME/airflow.cfg
    
    # Enable proxy fix for Cloud9
    sed -i 's/enable_proxy_fix = False/enable_proxy_fix = True/' $AIRFLOW_HOME/airflow.cfg
    
    # Create webserver config to disable CSRF (development only)
    cat > $AIRFLOW_HOME/webserver_config.py << 'EOF'
import os
from airflow.www.fab_security.manager import AUTH_DB

basedir = os.path.abspath(os.path.dirname(__file__))

# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = False
WTF_CSRF_TIME_LIMIT = None

AUTH_TYPE = AUTH_DB
EOF
    
    echo "✅ Cloud9 configuration applied"
fi

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

if [ "$IS_CLOUD9" = true ]; then
    echo "🌩️  Cloud9 Instructions:"
    echo "  Use 'airflow standalone' for easiest setup:"
    echo "    airflow standalone"
    echo ""
    echo "  Or run separately:"
    echo "    Terminal 1: airflow webserver --port 8080"
    echo "    Terminal 2: airflow scheduler"
    echo ""
    echo "  Access via Cloud9 Preview → Preview Running Application"
    echo "  Or use tmux: ./scripts/start_airflow_cloud9.sh"
else
    echo "To start Airflow:"
    echo "  Terminal 1: airflow webserver --port 8080"
    echo "  Terminal 2: airflow scheduler"
    echo ""
    echo "Access UI at: http://localhost:8080"
fi

echo ""
echo "Username: admin"
echo "Password: admin"
echo "=========================================="
