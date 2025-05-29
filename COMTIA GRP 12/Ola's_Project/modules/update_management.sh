#!/bin/bash

# Enhanced Update Management Script
# Handles system package updates with safety checks

source ./utilis/log.sh
source ./utilis/userInput.sh

check_updates() {
    header "Checking for Updates"
    
    echo -e "${GREEN}Updating package lists...${NC}"
    if sudo apt update 2>&1 | tee /tmp/apt_update.log; then
        echo -e "\n${BLUE}=== Available Updates ===${NC}"
        apt list --upgradable 2>/dev/null | column -t
        
        local count=$(apt list --upgradable 2>/dev/null | wc -l)
        count=$((count-1))
        
        if [ $count -gt 0 ]; then
            echo -e "\n${YELLOW}$count updates available${NC}"
        else
            echo -e "\n${GREEN}System is up to date${NC}"
        fi
        
        log_action "Checked for system updates ($count available)"
    else
        echo -e "\n${RED}Failed to check for updates${NC}"
        log_error "Failed to check for updates"
        return 1
    fi
}

apply_updates() {
    header "Applying Updates"
    
    check_updates || return 1
    
    local count=$(apt list --upgradable 2>/dev/null | wc -l)
    count=$((count-1))
    
    if [ $count -eq 0 ]; then
        echo "No updates to apply"
        return 0
    fi
    
    if confirm "Apply $count updates now?"; then
        echo -e "\n${GREEN}Applying updates...${NC}"
        
        # Create a backup of important files
        echo "Creating backup of package lists..."
        mkdir -p /tmp/update_backup
        dpkg --get-selections > /tmp/update_backup/packages.list
        cp -R /etc/apt/sources.list* /tmp/update_backup/
        
        # Perform the upgrade
        if sudo apt upgrade -y 2>&1 | tee /tmp/apt_upgrade.log; then
            echo -e "\n${GREEN}Updates applied successfully${NC}"
            log_action "Applied system updates"
            
            # Check if reboot is needed
            if [ -f /var/run/reboot-required ]; then
                echo -e "\n${YELLOW}Reboot required to complete updates${NC}"
                if confirm "Reboot now?"; then
                    sudo reboot
                fi
            fi
        else
            echo -e "\n${RED}Update failed${NC}"
            log_error "Failed to apply updates"
            return 1
        fi
    else
        echo "Update canceled"
    fi
}

clean_packages() {
    header "Package Cleanup"
    
    local size=$(sudo apt-get clean --dry-run | awk '/freed/ {print $4$5}')
    
    if [ -z "$size" ]; then
        echo "No packages to clean"
        return 0
    fi
    
    echo "Packages to remove will free: $size"
    
    if confirm "Remove unnecessary packages?"; then
        echo -e "\n${GREEN}Cleaning up...${NC}"
        if sudo apt autoremove -y && sudo apt clean; then
            echo "Cleanup completed"
            log_action "Performed package cleanup"
        else
            echo "Cleanup failed"
            log_error "Failed to clean packages"
        fi
    else
        echo "Cleanup canceled"
    fi
}

main() {
    local options=("Check for Updates" "Apply Updates" "Clean Packages" "Return to Main Menu")

    while true; do
        header "Update Management"
        menu "Select Operation" "${options[@]}"
        case $? in
            0) check_updates ;;
            1) apply_updates ;;
            2) clean_packages ;;
            3) return 0 ;;
            *) echo "Invalid option" ;;
        esac
        
        read -rp $'\nPress Enter to continue...'
    done
}

main
