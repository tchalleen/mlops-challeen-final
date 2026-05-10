#!/bin/bash
set -e

echo "Configuring Airflow for AWS Cloud9..."

# Ensure AIRFLOW_HOME is set
if [ -z "$AIRFLOW_HOME" ]; then
    export AIRFLOW_HOME=$(pwd)/airflow
    echo "AIRFLOW_HOME set to: $AIRFLOW_HOME"
fi

# Backup original config
if [ -f "$AIRFLOW_HOME/airflow.cfg" ]; then
    cp "$AIRFLOW_HOME/airflow.cfg" "$AIRFLOW_HOME/airflow.cfg.backup"
    echo "Backed up airflow.cfg"
fi

# Configure for Cloud9
echo "Updating airflow.cfg for Cloud9 compatibility..."

# Bind to 0.0.0.0 instead of localhost
sed -i 's/web_server_host = 127.0.0.1/web_server_host = 0.0.0.0/' $AIRFLOW_HOME/airflow.cfg

# Update base URL
sed -i 's|base_url = http://localhost:8080|base_url = http://0.0.0.0:8080|' $AIRFLOW_HOME/airflow.cfg

# Disable CSRF protection for Cloud9 (development only!)
sed -i 's/enable_proxy_fix = False/enable_proxy_fix = True/' $AIRFLOW_HOME/airflow.cfg

# Add WTF_CSRF_ENABLED setting if not present
if ! grep -q "WTF_CSRF_ENABLED" $AIRFLOW_HOME/airflow.cfg; then
    sed -i '/\[webserver\]/a WTF_CSRF_ENABLED = False' $AIRFLOW_HOME/airflow.cfg
fi

# Set secret key
if ! grep -q "secret_key =" $AIRFLOW_HOME/airflow.cfg; then
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    sed -i "/\[webserver\]/a secret_key = $SECRET_KEY" $AIRFLOW_HOME/airflow.cfg
fi

echo "✅ Airflow configured for Cloud9"
echo ""
echo "Configuration changes:"
echo "  - web_server_host = 0.0.0.0"
echo "  - enable_proxy_fix = True"
echo "  - WTF_CSRF_ENABLED = False (development only)"
echo ""
echo "Now start Airflow services:"
echo "  airflow webserver --port 8080"
echo "  airflow scheduler (in separate terminal/tmux)"
