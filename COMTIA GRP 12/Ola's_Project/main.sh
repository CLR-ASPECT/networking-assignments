#!/bin/bash
# Enhanced System Management Dashboard
# Provides menu navigation to all system management modules with better UI/UX

# Load dependencies
source ./utilis/userInput.sh
source ./utilis/log.sh

# Configuration
MODULE_DIR="./modules"
LOGFILE="./log/system_admin.log"
CONFIG_FILE="./config/system_admin.conf"

# Ensure required directories exist
mkdir -p ./log ./config

# Load or create config
if [ ! -f "$CONFIG_FILE" ]; then
    echo "# System Admin Configuration" > "$CONFIG_FILE"
    echo "THEME_COLOR=\"blue\"" >> "$CONFIG_FILE"
    echo "SHOW_BANNER=false" >> "$CONFIG_FILE"
    echo "DEFAULT_MODULE=\"system_information\"" >> "$CONFIG_FILE"
fi
source "$CONFIG_FILE"

#!/bin/bash
# Enhanced System Management Dashboard
# Provides menu navigation to all system management modules

# Load dependencies
source ./utilis/userInput.sh
source ./utilis/log.sh

# Configuration
MODULE_DIR="./modules"
LOGFILE="./log/system_admin.log"
CONFIG_FILE="./config/system_admin.conf"

# Ensure required directories exist
mkdir -p ./log ./config

# Load or create config
if [ ! -f "$CONFIG_FILE" ]; then
    echo "# System Admin Configuration" > "$CONFIG_FILE"
    echo "THEME_COLOR=\"blue\"" >> "$CONFIG_FILE"
    echo "SHOW_BANNER=true" >> "$CONFIG_FILE"
    echo "DEFAULT_MODULE=\"system_information\"" >> "$CONFIG_FILE"
fi
source "$CONFIG_FILE"

# Define the confirm function if not already sourced
confirm() {
    local prompt="$1 [y/N]: "
    local response
    read -rp "$prompt" response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Main menu options
menu_options=(
    "System Information"
    "User Management"
    "Process Management"
    "Network Management"
    "Service Management"
    "Update Management"
    "Log Management"
    "Backup Management"
    "System Configuration"
    "Exit"
)

# Module mapping
module_map=(
    "system_information.sh"
    "user_management.sh"
    "process_management.sh"
    "network_management.sh"
    "service_management.sh"
    "update_management.sh"
    "log_management.sh"
    "backup_management.sh"
    "system_config.sh"
)

# Display welcome banner
show_banner() {
    if [ "$SHOW_BANNER" = "true" ]; then
        clear
        echo -e "${BLUE}============================================${NC}"
        echo -e "${GREEN}   System Management Dashboard v2.0${NC}"
        echo -e "${BLUE}============================================${NC}"
        echo -e "Last login: $(date)"
        echo -e "Hostname : $(hostname)"
        echo -e "Uptime   : $(uptime -p)"
        echo -e "${BLUE}============================================${NC}"
        echo
    fi
}

# System configuration editor
system_config() {
    header "System Configuration"
    
    local options=(
        "Toggle Welcome Banner (Current: $SHOW_BANNER)"
        "Change Theme Color (Current: $THEME_COLOR)"
        "Set Default Module (Current: $DEFAULT_MODULE)"
        "Reset All Settings"
        "Return to Main Menu"
    )
    
    menu "Configuration Options" "${options[@]}"
    case $? in
        0) # Toggle banner
            if [ "$SHOW_BANNER" = "true" ]; then
                sed -i 's/SHOW_BANNER=.*/SHOW_BANNER=false/' "$CONFIG_FILE"
            else
                sed -i 's/SHOW_BANNER=.*/SHOW_BANNER=true/' "$CONFIG_FILE"
            fi
            source "$CONFIG_FILE"
            echo "Banner setting updated"
            ;;
        1) # Change theme
            local colors=("blue" "green" "red" "yellow" "magenta" "cyan")
            menu "Select Theme Color" "${colors[@]}"
            if [ $? -lt ${#colors[@]} ]; then
                new_color="${colors[$?]}"
                sed -i "s/THEME_COLOR=.*/THEME_COLOR=\"$new_color\"/" "$CONFIG_FILE"
                source "$CONFIG_FILE"
                # Update color variables
                eval "MAIN_COLOR=\$$(echo ${THEME_COLOR^^})"
                echo "Theme color changed to $new_color"
            fi
            ;;
        2) # Set default module
            menu "Select Default Module" "${menu_options[@]:0:$((${#menu_options[@]}-2))}"
            if [ $? -lt $((${#menu_options[@]}-2)) ]; then
                new_default="${module_map[$?]%.*}"
                sed -i "s/DEFAULT_MODULE=.*/DEFAULT_MODULE=\"$new_default\"/" "$CONFIG_FILE"
                echo "Default module set to ${menu_options[$?]}"
            fi
            ;;
        3) # Reset settings
            if confirm "Are you sure you want to reset all settings?"; then
                rm -f "$CONFIG_FILE"
                echo "Settings reset. Please restart the application."
                exit 0
            fi
            ;;
        *) return ;;
    esac
    
    read -rp $'\nPress Enter to continue...'
}

# Main loop
while true; do
    show_banner
    
    header "Main Menu" "${THEME_COLOR^^}"
    menu "Select Module" "${menu_options[@]}"
    choice=$?
    
    # Handle exit option
    if [ "$choice" -eq $((${#menu_options[@]} - 1)) ]; then
        if confirm "Are you sure you want to exit?"; then
            log_action "System dashboard closed"
            echo -e "\n${GREEN}Thank you for using System Management Dashboard${NC}"
            exit 1
        else
            continue
        fi
    fi
    
    # Handle configuration option
    if [ "$choice" -eq $((${#menu_options[@]} - 2)) ]; then
        system_config
        continue
    fi
    
    # Launch selected module
    module="${module_map[$choice]}"
    if [ -f "$MODULE_DIR/$module" ]; then
        log_action "Accessed module: ${menu_options[$choice]}"
        bash "$MODULE_DIR/$module"
    else
        log_error "Module not found: $module"
        echo -e "${RED}Error: Module not available${NC}"
        sleep 2
    fi
done
  
