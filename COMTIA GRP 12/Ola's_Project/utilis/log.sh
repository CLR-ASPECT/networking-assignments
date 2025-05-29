#!/bin/bash
# Logging Utility
# Provides standardized logging functionality

# Configuration
LOG_DIR="./log"
LOG_FILE="$LOG_DIR/system_admin.log"
MAX_LOG_SIZE=1048576 # 1MB

# Initialize logging directory
mkdir -p "$LOG_DIR"

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >>"$LOG_FILE"

    # Rotate log if too large
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
        mv "$LOG_FILE" "$LOG_FILE.old"
    fi
}

log_action() {
    log "ACTION" "$1"
}

log_error() {
    log "ERROR" "$1"
}

log_info() {
    log "INFO" "$1"
}
