#!/bin/bash

# Enhanced Network Management Script
# Provides network information, diagnostics, and configuration

source ./utilis/log.sh
source ./utilis/userInput.sh

# Configuration
INTERFACES=($(ip -o link show | awk -F': ' '{print $2}' | grep -v lo))

get_network_info() {
    header "Network Information"
    
    echo -e "${BLUE}=== Network Interfaces ===${NC}"
    ip -br -c a
    
    echo -e "\n${BLUE}=== Routing Table ===${NC}"
    ip -c route
    
    echo -e "\n${BLUE}=== Active Connections ===${NC}"
    ss -tulnp | awk '{$1=$1};1' | column -t
    
    echo -e "\n${BLUE}=== Bandwidth Usage ===${NC}"
    if command -v iftop &>/dev/null; then
        echo "Run 'iftop' for real-time bandwidth monitoring"
    else
        echo "Install 'iftop' for bandwidth monitoring"
    fi
    
    log_action "Viewed network information"
}

test_connectivity() {
    header "Network Test"
    
    local host choice
    host=$(input_prompt "Enter host to test (default: 8.8.8.8): " "" "" "8.8.8.8")
    
    local options=("Ping Test" "Traceroute" "DNS Lookup" "Port Check" "Cancel")
    menu "Test Type" "${options[@]}"
    choice=$?
    
    case $choice in
        0) # Ping
            echo -e "\n${GREEN}Pinging $host...${NC}"
            ping -c 4 "$host" | grep --color=always -E '^|time=.*ms'
            ;;
        1) # Traceroute
            if command -v traceroute &>/dev/null; then
                echo -e "\n${GREEN}Tracing route to $host...${NC}"
                traceroute "$host"
            else
                echo "Install 'traceroute' for this functionality"
            fi
            ;;
        2) # DNS Lookup
            echo -e "\n${GREEN}Performing DNS lookup...${NC}"
            dig +short "$host" | grep --color=always -E '^|$'
            ;;
        3) # Port Check
            local port=$(input_prompt "Enter port to check: " "^[0-9]+$" "Invalid port number")
            echo -e "\n${GREEN}Checking port $port on $host...${NC}"
            if timeout 2 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
                echo -e "${GREEN}Port $port is open${NC}"
            else
                echo -e "${RED}Port $port is closed or filtered${NC}"
            fi
            ;;
        *) return ;;
    esac
    
    log_action "Performed connectivity test to $host"
}

interface_stats() {
    header "Interface Statistics"
    
    menu "Select Interface" "${INTERFACES[@]}"
    local iface=${INTERFACES[$?]}
    
    echo -e "\n${BLUE}=== Statistics for $iface ===${NC}"
    ip -s link show "$iface"
    
    echo -e "\n${BLUE}Packet Counters:${NC}"
    awk "/$iface:/ {print}" /proc/net/dev | column -t
    
    log_action "Viewed statistics for interface: $iface"
}

main() {
    local options=("Show Network Info" "Test Connectivity" "Interface Stats" "Return to Main Menu")

    while true; do
        header "Network Management"
        menu "Select Operation" "${options[@]}"
        case $? in
            0) get_network_info ;;
            1) test_connectivity ;;
            2) interface_stats ;;
            3) return 0 ;;
            *) echo "Invalid option" ;;
        esac
        
        read -rp $'\nPress Enter to continue...'
    done
}

main
