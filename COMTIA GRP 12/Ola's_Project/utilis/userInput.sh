#!/bin/bash
# Stylish User Input Utilities
# A visually distinct version of input and menu functions with a modern interface

# Source bashsimplecurses
source ./bashsimplecurses/simplecurses.sh

# Prompt for user input with validation - now with stylish presentation
input_prompt() {
    local prompt="$1"
    local validation_regex="$2"
    local error_msg="$3"
    local default_value="$4"

    while true; do
        read -rp "$prompt" input

        # Use default if input is empty and default provided
        if [ -z "$input" ] && [ -n "$default_value" ]; then
            echo "$default_value"
            return 0
        fi

        # Validate input if regex provided
        if [ -z "$validation_regex" ] || [[ "$input" =~ $validation_regex ]]; then
            echo "$input"
            return 0
        else
            echo "$error_msg" >&2
        fi
    done
}

# Display a stylish menu with modern aesthetics
menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected_index=0
    local key
    local options_count=${#options[@]}
    
    # Hide cursor
    tput civis
    
    while true; do
        clear
        # Draw menu header
        echo -e "\033[1;35m╔═══════════════════════════════════════════════════╗"
        echo -e "║ \033[1;36m$(printf "%-47s" "$title")\033[1;35m ║"
        echo -e "╠═══════════════════════════════════════════════════╣"
        echo -e "║ \033[0;37mUse ↑/↓ arrows to navigate • Enter to select\033[1;35m ║"
        echo -e "╟───────────────────────────────────────────────────╢\033[0m"
        
        # Menu items
        for index in "${!options[@]}"; do
            if [ $index -eq $selected_index ]; then
                echo -e "\033[1;35m║ \033[1;33m› \033[1;97m$(printf "%-45s" "${options[$index]}")\033[1;35m ║"
            else
                echo -e "\033[1;35m║   \033[0;37m$(printf "%-45s" "${options[$index]}")\033[1;35m ║"
            fi
        done
        
        # Menu footer
        echo -e "\033[1;35m╚═══════════════════════════════════════════════════╝\033[0m"
        
        # Read single character
        read -rsn1 key
        
        case "$key" in
            $'\x1b') # ESC sequence for arrows
                read -rsn2 -t 0.1 key2
                case "$key2" in
                    '[A') # Up arrow
                        selected_index=$(( (selected_index - 1 + options_count) % options_count ))
                        ;;
                    '[B') # Down arrow
                        selected_index=$(( (selected_index + 1) % options_count ))
                        ;;
                esac
                ;;
            "") # Enter key
                clear
                tput cnorm # Show cursor
                return $selected_index
                ;;
            [1-9]) # Number selection
                if [ "$key" -lt "$options_count" ]; then
                    clear
                    tput cnorm # Show cursor
                    return $key
                fi
                ;;
            q|Q) # Quit
                clear
                tput cnorm # Show cursor
                return 255
                ;;
        esac
    done
}

# Enhanced dialog menu with fallback
dialog_menu() {
    if command -v dialog &> /dev/null; then
        local title="$1"
        shift
        local options=("$@")
        local menu_items=()
        
        for index in "${!options[@]}"; do
            menu_items+=("$index" "${options[$index]}")
        done
        
        # Use custom dialog colors
        export DIALOGRC=<(echo "screen_color = (CYAN,BLACK,ON)
                dialog_color = (BLACK,CYAN,ON)
                title_color = (YELLOW,BLACK,ON)
                border_color = (WHITE,BLACK,ON)")
        
        dialog --clear --title " ✨ $title ✨ " \
               --colors --no-shadow \
               --menu "Please make your selection:" 15 40 10 \
               "${menu_items[@]}" 2>&1 >/dev/tty
        
        return $?
    else
        # Fall back to our stylish menu if dialog not available
        menu "$@"
        return $?
    fi
}

# Example usage (commented out)
# options=("Start Service" "Configure Settings" "View Logs" "Exit Program")
# dialog_menu "System Manager" "${options[@]}"
# selection=$?
# echo "You selected: ${options[$selection]}"
