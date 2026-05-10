#!/bin/bash

echo "Stopping Airflow services..."

# Kill tmux session if exists
tmux kill-session -t airflow 2>/dev/null && echo "✅ Killed tmux session" || echo "No tmux session found"

# Kill any remaining Airflow processes
pkill -f "airflow webserver" 2>/dev/null && echo "✅ Killed webserver" || echo "No webserver running"
pkill -f "airflow scheduler" 2>/dev/null && echo "✅ Killed scheduler" || echo "No scheduler running"

echo "✅ All Airflow services stopped"
