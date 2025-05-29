#!/bin/bash

# Enhanced Log Management Script
# Provides functionality to view, search, and analyze system logs

source ./utilis/log.sh
source ./utilis/userInput.sh

# Configuration
LOG_LINES=50
LOG_DIR="/var/log"
LOG_FILES=("syslog" "auth.log" "kern.log" "messages")

view_logs() {
    header "Recent System Logs"
    journalctl -n $LOG_LINES --no-pager | less -R
    log_action "Viewed recent system logs"
}

search_logs() {
    header "Log Search"
    
    local pattern file choice
    pattern=$(input_prompt "Enter search pattern: " ".+" "Pattern cannot be empty")
    
    local options=("Journal Logs" "System Log Files" "Custom File" "Cancel")
    menu "Search Location" "${options[@]}"
    choice=$?
    
    case $choice in
        0) # Journal
            echo -e "\n${GREEN}Searching journal logs...${NC}"
            journalctl --no-pager | grep -i --color=always "$pattern" | less -R
            ;;
        1) # System Log Files
            header "Search Results" "GREEN"
            for file in "${LOG_FILES[@]}"; do
                if [ -f "$LOG_DIR/$file" ]; then
                    echo -e "${BLUE}=== $file ===${NC}"
                    grep -i --color=always "$pattern" "$LOG_DIR/$file" | tail -n 20
                    echo
                fi
            done
            ;;
        2) # Custom File
            file=$(input_prompt "Enter full path to log file: " ".+" "File path required")
            if [ -f "$file" ]; then
                echo -e "\n${GREEN}Searching $file...${NC}"
                grep -i --color=always "$pattern" "$file" | less -R
            else
                echo "${RED}File not found: $file${NC}"
                return 1
            fi
            ;;
        *) return ;;
    esac
    
    log_action "Searched logs for pattern: $pattern"
}

log_stats() {
    header "Log Statistics"
    
    echo -e "${BLUE}Top error messages:${NC}"
    journalctl --no-pager -p err | grep -v '^\s*$' | sort | uniq -c | sort -nr | head -n 10
    
    echo -e "\n${BLUE}Most frequent processes:${NC}"
    journalctl --no-pager -o short | awk '{print $5}' | sort | uniq -c | sort -nr | head -n 10
    
    log_action "Viewed log statistics"
}

main() {
    local options=("View Recent Logs" "Search Logs" "Log Statistics" "Return to Main Menu")

    while true; do
        header "Log Management"
        menu "Select Operation" "${options[@]}"
        case $? in
            0) view_logs ;;
            1) search_logs ;;
            2) log_stats ;;
            3) return 0 ;;
            *) echo "Invalid option" ;;
        esac
        
        read -rp $'\nPress Enter to continue...'
    done
}

main
