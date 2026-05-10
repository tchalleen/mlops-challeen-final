#!/bin/bash

echo "=========================================="
echo "Complete Airflow Cleanup"
echo "=========================================="

# Set Airflow home
export AIRFLOW_HOME=$(pwd)/airflow

# Kill all Airflow processes
echo "Killing all Airflow processes..."
pkill -9 -f "airflow webserver" 2>/dev/null || true
pkill -9 -f "airflow scheduler" 2>/dev/null || true
pkill -9 -f "airflow triggerer" 2>/dev/null || true
pkill -9 -f "airflow standalone" 2>/dev/null || true
pkill -9 -f "gunicorn" 2>/dev/null || true

# Kill tmux session
tmux kill-session -t airflow 2>/dev/null || true

# Remove stale PID files
echo "Removing stale PID files..."
rm -f $AIRFLOW_HOME/airflow-webserver.pid
rm -f $AIRFLOW_HOME/airflow-webserver-monitor.pid
rm -f $AIRFLOW_HOME/airflow-scheduler.pid

# Wait a moment
sleep 2

echo "✅ Cleanup complete!"
echo ""
echo "You can now start Airflow with:"
echo "  airflow standalone"
echo "  OR"
echo "  ./scripts/start_airflow_cloud9.sh"
