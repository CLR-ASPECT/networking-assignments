#!/bin/bash

# Enhanced Service Management Script
# Provides control over system services with monitoring features

source ./utilis/log.sh
source ./utilis/userInput.sh

list_services() {
    header "System Services"
    
    local state
    state=$(input_prompt "Filter by state (running/active/all, default: running): " "" "" "running")
    
    case $state in
        running)
            systemctl list-units --type=service --state=running --no-pager --no-legend | \
            awk '{print $1}' | column
            ;;
        active)
            systemctl list-units --type=service --state=active --no-pager --no-legend | \
            awk '{print $1}' | column
            ;;
        *)
            systemctl list-units --type=service --no-pager --no-legend | \
            awk '{print $1}' | column
            ;;
    esac
    
    log_action "Listed system services (state: $state)"
}

service_operation() {
    local operation=$1
    local svc
    
    svc=$(input_prompt "Enter service name: " ".+" "Service name required")
    
    if ! systemctl is-enabled "$svc" >/dev/null 2>&1; then
        echo "Service $svc not found"
        log_error "Attempted $operation on non-existent service: $svc"
        return 1
    fi
    
    case $operation in
        start)
            if systemctl start "$svc"; then
                echo "Service $svc started successfully"
                log_action "Started service: $svc"
            else
                echo "Failed to start $svc"
                log_error "Failed to start service: $svc"
            fi
            ;;
        stop)
            if systemctl stop "$svc"; then
                echo "Service $svc stopped successfully"
                log_action "Stopped service: $svc"
            else
                echo "Failed to stop $svc"
                log_error "Failed to stop service: $svc"
            fi
            ;;
        restart)
            if systemctl restart "$svc"; then
                echo "Service $svc restarted successfully"
                log_action "Restarted service: $svc"
            else
                echo "Failed to restart $svc"
                log_error "Failed to restart service: $svc"
            fi
            ;;
        status)
            systemctl status "$svc" -n 20
            log_action "Checked status of service: $svc"
            ;;
        enable)
            if systemctl enable "$svc"; then
                echo "Service $svc enabled to start at boot"
                log_action "Enabled service: $svc"
            else
                echo "Failed to enable $svc"
                log_error "Failed to enable service: $svc"
            fi
            ;;
        disable)
            if systemctl disable "$svc"; then
                echo "Service $svc disabled from starting at boot"
                log_action "Disabled service: $svc"
            else
                echo "Failed to disable $svc"
                log_error "Failed to disable service: $svc"
            fi
            ;;
    esac
}

service_monitor() {
    header "Service Monitor"
    
    local svc
    svc=$(input_prompt "Enter service name to monitor: " ".+" "Service name required")
    
    if ! systemctl is-enabled "$svc" >/dev/null 2>&1; then
        echo "Service $svc not found"
        return 1
    fi
    
    echo -e "${GREEN}Monitoring service: $svc${NC}"
    echo "Press Ctrl+C to stop monitoring"
    
    while true; do
        clear
        systemctl status "$svc" -n 10 --no-pager
        sleep 2
    done
}

main() {
    local options=("List Services" "Start Service" "Stop Service" "Restart Service" 
                   "Enable Service" "Disable Service" "Check Status" "Monitor Service" 
                   "Return to Main Menu")

    while true; do
        header "Service Management"
        menu "Select Operation" "${options[@]}"
        case $? in
            0) list_services ;;
            1) service_operation "start" ;;
            2) service_operation "stop" ;;
            3) service_operation "restart" ;;
            4) service_operation "enable" ;;
            5) service_operation "disable" ;;
            6) service_operation "status" ;;
            7) service_monitor ;;
            8) return 0 ;;
            *) echo "Invalid option" ;;
        esac
        
        read -rp $'\nPress Enter to continue...'
    done
}

main
