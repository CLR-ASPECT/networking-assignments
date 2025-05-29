#!/bin/bash

# Enhanced Process Management Script
# Provides process monitoring and control with advanced features

source ./utilis/log.sh
source ./utilis/userInput.sh

# Configuration
PROCESS_LIMIT=15

list_processes() {
    header "Process Monitoring"
    
    local options=("By CPU Usage" "By Memory Usage" "By Process Name" "All Processes" "Cancel")
    menu "Sort Option" "${options[@]}"
    local choice=$?
    
    case $choice in
        0) # CPU
            header "Top Processes by CPU" "GREEN"
            ps -eo pid,ppid,user,%mem,%cpu,cmd --sort=-%cpu | head -n $PROCESS_LIMIT | awk '{$1=$1};1' | column -t
            ;;
        1) # Memory
            header "Top Processes by Memory" "GREEN"
            ps -eo pid,ppid,user,%mem,%cpu,cmd --sort=-%mem | head -n $PROCESS_LIMIT | awk '{$1=$1};1' | column -t
            ;;
        2) # Name
            local name=$(input_prompt "Enter process name: " ".+" "Name required")
            header "Processes Matching: $name" "GREEN"
            pgrep -fl "$name" | head -n $PROCESS_LIMIT | column -t
            ;;
        3) # All
            header "All Processes" "GREEN"
            ps -eo pid,ppid,user,%mem,%cpu,cmd --sort=-%cpu | head -n $PROCESS_LIMIT | awk '{$1=$1};1' | column -t
            ;;
        *) return ;;
    esac
    
    log_action "Listed top processes"
}

process_details() {
    header "Process Details"
    
    local pid
    pid=$(input_prompt "Enter PID: " "^[0-9]+$" "Invalid PID")
    
    if ! ps -p "$pid" >/dev/null; then
        echo "Process $pid not found"
        return 1
    fi
    
    echo -e "${BLUE}=== Basic Info ===${NC}"
    ps -fp "$pid" | awk '{$1=$1};1' | column -t
    
    echo -e "\n${BLUE}=== Memory Map ===${NC}"
    pmap -x "$pid" | tail -n +3
    
    echo -e "\n${BLUE}=== Open Files ===${NC}"
    lsof -p "$pid" | head -n 10
    
    log_action "Viewed details for process: $pid"
}

kill_process() {
    header "Process Termination"
    
    local proc
    proc=$(input_prompt "Enter PID or name to kill: " ".+" "Process identifier required")
    
    if [[ $proc =~ ^[0-9]+$ ]]; then
        if ! ps -p "$proc" >/dev/null; then
            echo "Process $proc not found"
            log_error "Attempted to kill non-existent process: $proc"
            return 1
        fi
        
        if confirm "Are you sure you want to kill process $proc?"; then
            if kill "$proc"; then
                echo "Process $proc terminated"
                log_action "Killed process by PID: $proc"
            else
                echo "Failed to kill process $proc"
                log_error "Failed to kill process: $proc"
            fi
        fi
    else
        if ! pgrep "$proc" >/dev/null; then
            echo "No '$proc' processes found"
            log_error "Attempted to kill non-existent processes: $proc"
            return 1
        fi
        
        if confirm "Are you sure you want to kill all '$proc' processes?"; then
            if pkill "$proc"; then
                echo "All '$proc' processes terminated"
                log_action "Killed processes by name: $proc"
            else
                echo "Failed to kill '$proc' processes"
                log_error "Failed to kill processes: $proc"
            fi
        fi
    fi
}

main() {
    local options=("List Processes" "Process Details" "Kill Process" "Return to Main Menu")

    while true; do
        header "Process Management"
        menu "Select Operation" "${options[@]}"
        case $? in
            0) list_processes ;;
            1) process_details ;;
            2) kill_process ;;
            3) return 0 ;;
            *) echo "Invalid option" ;;
        esac
        
        read -rp $'\nPress Enter to continue...'
    done
}

main
