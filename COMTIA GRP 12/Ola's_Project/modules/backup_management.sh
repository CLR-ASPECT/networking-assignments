#!/bin/bash

# Enhanced Backup Management Script
# Provides functionality to create, restore, and manage system backups

source ./utilis/log.sh
source ./utilis/userInput.sh

# Configuration
BACKUP_DIR="/var/backups"
TIMESTAMP=$(date +%F_%H-%M-%S)
MAX_BACKUPS=5

validate_directory() {
    if [ ! -d "$1" ]; then
        log_error "Directory does not exist: $1"
        return 1
    fi
    return 0
}

list_backups() {
    header "Available Backups"
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "No backup directory found at $BACKUP_DIR"
        return 1
    fi
    
    local backups=($(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
    if [ ${#backups[@]} -eq 0 ]; then
        echo "No backups available"
        return 1
    fi
    
    echo "Recent backups:"
    for i in "${!backups[@]}"; do
        printf "%2d. %s (%s)\n" $i "${backups[$i]}" \
               "$(du -h "${backups[$i]}" | cut -f1)"
    done
}

rotate_backups() {
    local backups=($(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
    local count=${#backups[@]}
    
    if [ $count -gt $MAX_BACKUPS ]; then
        header "Rotating Backups" "YELLOW"
        echo "Removing old backups (keeping $MAX_BACKUPS most recent)..."
        
        for ((i=MAX_BACKUPS; i<count; i++)); do
            echo "Removing ${backups[$i]}"
            rm -f "${backups[$i]}"
            log_action "Removed old backup: ${backups[$i]}"
        done
    fi
}

create_backup() {
    header "Create Backup"
    
    local src dst backup_file size
    
    while true; do
        src=$(input_prompt "Enter directory to backup: " "" "Directory cannot be empty")
        validate_directory "$src" && break
    done

    dst=$(input_prompt "Enter destination (default: $BACKUP_DIR): " "" "" "$BACKUP_DIR")
    mkdir -p "$dst"
    
    backup_file="$dst/backup_$TIMESTAMP.tar.gz"
    header "Creating Backup" "GREEN"
    echo "Source: $src"
    echo "Destination: $backup_file"
    
    if confirm "Start backup process?"; then
        echo -e "\nBackup in progress..."
        if tar -czf "$backup_file" "$src" 2>/dev/null & pid=$!; then
            progress_bar 5 50
            wait $pid
            
            size=$(du -h "$backup_file" | cut -f1)
            log_action "Created backup: $backup_file ($size)"
            echo -e "\nBackup created successfully: $backup_file ($size)"
            
            rotate_backups
        else
            log_error "Failed to create backup of $src"
            echo -e "\n${RED}Backup failed!${NC}"
            return 1
        fi
    else
        echo "Backup canceled"
    fi
}

restore_backup() {
    header "Restore Backup"
    
    list_backups || return 1
    
    local backups=($(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
    local choice backup dst
    
    choice=$(input_prompt "Enter backup number to restore: " "^[0-9]+$" "Invalid backup number")
    
    if [ -z "${backups[$choice]}" ]; then
        echo "Invalid backup selection"
        return 1
    fi
    
    backup="${backups[$choice]}"
    echo -e "\nSelected backup: $backup"
    
    while true; do
        dst=$(input_prompt "Enter restore destination: " "" "Directory cannot be empty")
        validate_directory "$dst" && break
    done
    
    if confirm "Restore backup to $dst?"; then
        echo -e "\nRestoration in progress..."
        if tar -xzf "$backup" -C "$dst" 2>/dev/null & pid=$!; then
            progress_bar 5 50
            wait $pid
            
            log_action "Restored backup: $backup to $dst"
            echo -e "\n${GREEN}Restore completed successfully${NC}"
        else
            log_error "Failed to restore backup from $backup"
            echo -e "\n${RED}Restore failed!${NC}"
            return 1
        fi
    else
        echo "Restore canceled"
    fi
}

main() {
    local options=("Create Backup" "Restore Backup" "List Backups" "Return to Main Menu")

    while true; do
        header "Backup Management"
        menu "Select Operation" "${options[@]}"
        case $? in
            0) create_backup ;;
            1) restore_backup ;;
            2) list_backups ;;
            3) return 0 ;;
            *) echo "Invalid option" ;;
        esac
        
        read -rp $'\nPress Enter to continue...'
    done
}

main
