#!/bin/bash
set -e

echo "=========================================="
echo "Starting Airflow in Cloud9 (using tmux)"
echo "=========================================="

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo "tmux not found. Installing..."
    sudo yum install -y tmux
fi

# Set Airflow home
export AIRFLOW_HOME=$(pwd)/airflow

# Kill any existing Airflow processes
echo "Stopping any existing Airflow processes..."
pkill -f "airflow webserver" 2>/dev/null || true
pkill -f "airflow scheduler" 2>/dev/null || true

# Kill existing tmux session if it exists
tmux kill-session -t airflow 2>/dev/null || true

echo "Starting Airflow in tmux session..."

# Create new tmux session with webserver
tmux new-session -d -s airflow -n webserver "cd $(pwd) && source venv/bin/activate && export AIRFLOW_HOME=$(pwd)/airflow && airflow webserver --port 8080"

# Create new window for scheduler
tmux new-window -t airflow:1 -n scheduler "cd $(pwd) && source venv/bin/activate && export AIRFLOW_HOME=$(pwd)/airflow && airflow scheduler"

echo "=========================================="
echo "✅ Airflow started in tmux session 'airflow'"
echo ""
echo "Access Airflow UI:"
echo "  1. In Cloud9: Preview → Preview Running Application"
echo "  2. Login: admin / admin"
echo ""
echo "Manage tmux session:"
echo "  - Attach: tmux attach -t airflow"
echo "  - Detach: Ctrl+B then D"
echo "  - Switch windows: Ctrl+B then 0 (webserver) or 1 (scheduler)"
echo "  - Stop all: tmux kill-session -t airflow"
echo ""
echo "View logs:"
echo "  - Webserver: tmux attach -t airflow:0"
echo "  - Scheduler: tmux attach -t airflow:1"
echo "=========================================="
