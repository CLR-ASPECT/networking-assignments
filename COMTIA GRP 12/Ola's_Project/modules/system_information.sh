#!/bin/bash

# Enhanced System Information Script
# Displays comprehensive system details with monitoring capabilities

source ./utilis/log.sh
source ./utilis/userInput.sh

show_system_info() {
    header "System Information"
    
    echo -e "${BLUE}=== OS Version ===${NC}"
    if [ -f /etc/os-release ]; then
        grep PRETTY_NAME /etc/os-release | cut -d'"' -f2
    else
        lsb_release -d | cut -f2- 2>/dev/null || echo "Not available"
    fi

    echo -e "\n${BLUE}=== Kernel Version ===${NC}"
    uname -r

    echo -e "\n${BLUE}=== CPU Info ===${NC}"
    lscpu | grep -E 'Model name|Socket|Core|Thread|MHz' | sed 's/^[ \t]*//' | column -t -s:

    echo -e "\n${BLUE}=== Memory Usage ===${NC}"
    free -h | awk '{$1=$1};1' | column -t

    echo -e "\n${BLUE}=== Disk Usage ===${NC}"
    df -h | grep -v tmpfs | awk '{$1=$1};1' | column -t

    echo -e "\n${BLUE}=== Uptime ===${NC}"
    uptime -p

    echo -e "\n${BLUE}=== Load Average ===${NC}"
    awk '{printf "1m: %.2f\n5m: %.2f\n15m: %.2f\n", $1, $2, $3}' /proc/loadavg

    echo -e "\n${BLUE}=== Temperature ===${NC}"
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        echo "$(($(cat /sys/class/thermal/thermal_zone0/temp)/1000))°C"
    else
        echo "Not available"
    fi

    log_action "Viewed system information"
}

monitor_system() {
    header "System Monitor"
    echo -e "${GREEN}Monitoring system resources...${NC}"
    echo "Press Ctrl+C to stop monitoring"
    
    local delay=2
    while true; do
        clear
        echo -e "${BLUE}=== $(date) ===${NC}\n"
        
        # CPU
        echo -e "${GREEN}CPU Usage:${NC}"
        top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | \
        awk '{printf "Used: %.1f%%\n", 100 - $1}'
        
        # Memory
        echo -e "\n${GREEN}Memory Usage:${NC}"
        free -m | awk 'NR==2{printf "Used: %sMB (%.1f%%)\n", $3, $3*100/$2 }'
        
        # Disk
        echo -e "\n${GREEN}Disk Usage:${NC}"
        df -h | awk '$NF=="/"{printf "Used: %s (%.1f%%)\n", $3, $5}'
        
        sleep $delay
    done
}

hardware_info() {
    header "Hardware Information"
    
    echo -e "${BLUE}=== CPU Details ===${NC}"
    lscpu | column -t
    
    echo -e "\n${BLUE}=== Memory Details ===${NC}"
    dmidecode -t memory | grep -E 'Size|Type|Speed' | grep -v "No Module" | column -t
    
    echo -e "\n${BLUE}=== Disk Details ===${NC}"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE | column -t
    
    echo -e "\n${BLUE}=== PCI Devices ===${NC}"
    lspci | cut -d' ' -f2- | column -t
    
    log_action "Viewed hardware information"
}

main() {
    local options=("System Info" "Hardware Info" "Monitor System" "Return to Main Menu")

    while true; do
        header "System Information"
        menu "Select Operation" "${options[@]}"
        case $? in
            0) show_system_info ;;
            1) hardware_info ;;
            2) monitor_system ;;
            3) return 0 ;;
            *) echo "Invalid option" ;;
        esac
        
        read -rp $'\nPress Enter to continue...'
    done
}

main
