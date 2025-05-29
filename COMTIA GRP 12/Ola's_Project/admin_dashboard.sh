#!/bin/bash
# Admin Dashboard Launcher
# Provides sudo access to the main system management interface

if [ "$(id -u)" -ne 0 ]; then
    echo "Restarting with sudo..."
    exec sudo "$0" "$@"
fi

exec ./main.sh
