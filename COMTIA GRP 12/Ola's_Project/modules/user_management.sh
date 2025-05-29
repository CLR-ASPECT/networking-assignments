#!/bin/bash
# Enhanced User Management Script
# Comprehensive user and group management with advanced features

source ./utilis/userInput.sh

# Configuration
PASSWORD_MIN_LENGTH=8
USER_HOME_BASE="/home"
SKEL_DIR="/etc/skel"
PASSWORD_FILE="/etc/passwd"
GROUP_FILE="/etc/group"
SHADOW_FILE="/etc/shadow"
DEFAULT_SHELL="/bin/bash"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper Functions
confirm() {
    local prompt="$1 [y/N] "
    local response
    read -rp "$prompt" response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

header() {
    clear
    echo -e "\n${BLUE}===== $1 =====${NC}\n"
}

## USER FUNCTIONS ##

list_users() {
    header "System Users"
    
    # Detailed user listing with important fields
    echo -e "${BLUE}=== User Accounts ===${NC}"
    awk -F: '{printf "%-15s %5s %5s %-20s %s\n", $1, $3, $4, $6, $7}' "$PASSWORD_FILE" | 
    column -t -N "Username,UID,GID,Home,Shell"
    
    # Group membership summary
    echo -e "\n${BLUE}=== Group Memberships ===${NC}"
    for user in $(cut -d: -f1 "$PASSWORD_FILE"); do
        groups=$(id -nG "$user" | tr ' ' ',')
        printf "%-15s: %s\n" "$user" "$groups"
    done | column -t
    
    # Password status information
    echo -e "\n${BLUE}=== Password Status ===${NC}"
    awk -F: '{
        cmd = "passwd -S " $1 " | cut -d\" \" -f2";
        cmd | getline status;
        close(cmd);
        printf "%-15s: %s\n", $1, status;
    }' "$PASSWORD_FILE" | column -t
}

add_user() {
    header "Add New User"
    
    local username password uid shell groups comment
    
    # Username validation
    while true; do
        read -rp "Enter username: " username
        if [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            if ! id "$username" &>/dev/null; then
                break
            else
                echo -e "${RED}User $username already exists!${NC}"
            fi
        else
            echo -e "${RED}Invalid username format!${NC}"
        fi
    done
    
    # Secure password input
    while true; do
        read -srp "Enter password: " password
        echo
        if [ ${#password} -ge $PASSWORD_MIN_LENGTH ]; then
            read -srp "Confirm password: " confirm_pass
            echo
            if [ "$password" = "$confirm_pass" ]; then
                break
            else
                echo -e "${RED}Passwords do not match!${NC}"
            fi
        else
            echo -e "${RED}Password must be at least $PASSWORD_MIN_LENGTH characters!${NC}"
        fi
    done
    
    # Additional user details
    read -rp "Enter shell (default: $DEFAULT_SHELL): " shell
    [ -z "$shell" ] && shell="$DEFAULT_SHELL"
    
    read -rp "Enter full name/comment: " comment
    read -rp "Enter additional groups (comma separated): " groups
    
    # UID selection
    local next_uid=$(($(cut -d: -f3 "$PASSWORD_FILE" | sort -n | tail -1) + 1))
    read -rp "Enter UID (default: $next_uid): " uid
    [ -z "$uid" ] && uid="$next_uid"
    
    # Create the user
    echo -e "\n${GREEN}Creating user: $username${NC}"
    echo -e "UID: $uid\nShell: $shell\nGroups: ${groups:-none}"
    
    if confirm "Proceed with user creation?"; then
        local useradd_cmd="useradd -m -u $uid -s $shell -c \"$comment\" $username"
        
        # Add to supplementary groups if specified
        if [ -n "$groups" ]; then
            useradd_cmd+=" -G $groups"
        fi
        
        if eval "$useradd_cmd"; then
            # Set password
            echo "$username:$password" | chpasswd
            
            # Set password expiration
            passwd -x 90 -w 7 "$username" >/dev/null
            
            echo -e "${GREEN}User $username created successfully${NC}"
        else
            echo -e "${RED}Failed to create user $username${NC}"
            return 1
        fi
    else
        echo "User creation canceled"
    fi
}

modify_user() {
    header "Modify User"
    
    read -rp "Enter username to modify: " username
    
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}User $username not found!${NC}"
        return 1
    fi
    
    # Display current user info
    echo -e "\n${BLUE}=== Current User Info ===${NC}"
    grep "^$username:" "$PASSWORD_FILE" | awk -F: '{
        printf "Username: %s\nUID: %s\nGID: %s\nHome: %s\nShell: %s\nComment: %s\n", 
               $1, $3, $4, $6, $7, $5
    }'
    
    local current_groups=$(id -nG "$username" | tr ' ' ',')
    echo "Groups: $current_groups"
    
    PS3="Select operation: "
    options=(
        "Change Password"
        "Change Shell"
        "Change Home Directory"
        "Modify Groups"
        "Lock/Unlock Account"
        "Change UID"
        "Change Comment"
        "Back to Menu"
    )
    
    select opt in "${options[@]}"; do
        case $opt in
            "Change Password")
                read -srp "Enter new password: " password
                echo
                if echo "$username:$password" | chpasswd; then
                    echo "Password changed successfully"
                else
                    echo "Failed to change password"
                fi
                ;;
            "Change Shell")
                local current_shell=$(grep "^$username:" "$PASSWORD_FILE" | cut -d: -f7)
                read -rp "Enter new shell (current: $current_shell): " new_shell
                [ -z "$new_shell" ] && new_shell="$current_shell"
                if usermod -s "$new_shell" "$username"; then
                    echo "Shell changed to $new_shell"
                else
                    echo "Failed to change shell"
                fi
                ;;
            "Change Home Directory")
                local current_home=$(grep "^$username:" "$PASSWORD_FILE" | cut -d: -f6)
                read -rp "Enter new home directory (current: $current_home): " new_home
                [ -z "$new_home" ] && new_home="$current_home"
                if usermod -d "$new_home" -m "$username"; then
                    echo "Home directory changed to $new_home"
                else
                    echo "Failed to change home directory"
                fi
                ;;
            "Modify Groups")
                modify_user_groups "$username"
                ;;
            "Lock/Unlock Account")
                local status=$(passwd -S "$username" | awk '{print $2}')
                if [ "$status" = "L" ]; then
                    if usermod -U "$username"; then
                        echo "Account unlocked"
                    fi
                else
                    if usermod -L "$username"; then
                        echo "Account locked"
                    fi
                fi
                ;;
            "Change UID")
                local current_uid=$(id -u "$username")
                read -rp "Enter new UID (current: $current_uid): " new_uid
                [ -z "$new_uid" ] && new_uid="$current_uid"
                if usermod -u "$new_uid" "$username"; then
                    echo "UID changed to $new_uid"
                else
                    echo "Failed to change UID"
                fi
                ;;
            "Change Comment")
                local current_comment=$(grep "^$username:" "$PASSWORD_FILE" | cut -d: -f5)
                read -rp "Enter new comment (current: $current_comment): " new_comment
                [ -z "$new_comment" ] && new_comment="$current_comment"
                if usermod -c "$new_comment" "$username"; then
                    echo "Comment changed successfully"
                else
                    echo "Failed to change comment"
                fi
                ;;
            "Back to Menu")
                return
                ;;
            *) echo "Invalid option";;
        esac
    done
}

modify_user_groups() {
    local username=$1
    
    while true; do
        header "Manage Groups for $username"
        
        # Get current groups
        local current_primary=$(id -gn "$username")
        local current_groups=($(id -nG "$username"))
        local all_groups=($(cut -d: -f1 "$GROUP_FILE" | sort))
        
        # Display current membership
        echo -e "${BLUE}=== Current Groups ===${NC}"
        printf "Primary: ${GREEN}%s${NC}\n" "$current_primary"
        echo "Supplementary:"
        for group in "${current_groups[@]}"; do
            if [ "$group" != "$current_primary" ]; then
                echo " - $group"
            fi
        done
        
        PS3="Select group operation: "
        local options=(
            "Change Primary Group"
            "Add to Group"
            "Remove from Group"
            "View All Groups"
            "Done"
        )
        
        select opt in "${options[@]}"; do
            case $opt in
                "Change Primary Group")
                    read -rp "Enter new primary group: " new_primary
                    if usermod -g "$new_primary" "$username"; then
                        echo "Primary group changed to $new_primary"
                    else
                        echo "Failed to change primary group"
                    fi
                    break
                    ;;
                "Add to Group")
                    select group_to_add in "${all_groups[@]}"; do
                        if [ -n "$group_to_add" ]; then
                            if usermod -aG "$group_to_add" "$username"; then
                                echo "Added $username to $group_to_add"
                            else
                                echo "Failed to add to group"
                            fi
                            break
                        fi
                    done
                    break
                    ;;
                "Remove from Group")
                    if [ ${#current_groups[@]} -le 1 ]; then
                        echo "User must belong to at least one group"
                        break
                    fi
                    
                    local removable_groups=()
                    for group in "${current_groups[@]}"; do
                        if [ "$group" != "$current_primary" ]; then
                            removable_groups+=("$group")
                        fi
                    done
                    
                    select group_to_remove in "${removable_groups[@]}"; do
                        if [ -n "$group_to_remove" ]; then
                            if gpasswd -d "$username" "$group_to_remove"; then
                                echo "Removed $username from $group_to_remove"
                            else
                                echo "Failed to remove from group"
                            fi
                            break
                        fi
                    done
                    break
                    ;;
                "View All Groups")
                    echo -e "\n${BLUE}=== All System Groups ===${NC}"
                    printf "%s\n" "${all_groups[@]}" | column
                    read -rp $'\nPress Enter to continue...'
                    break
                    ;;
                "Done")
                    return
                    ;;
                *) echo "Invalid option";;
            esac
        done
    done
}

delete_user() {
    header "Delete User"
    
    read -rp "Enter username to delete: " username
    
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}User $username not found!${NC}"
        return 1
    fi
    
    # Show user info before deletion
    echo -e "\n${RED}=== WARNING: USER DELETION ===${NC}"
    grep "^$username:" "$PASSWORD_FILE" | awk -F: '{
        printf "Username: %s\nUID: %s\nGID: %s\nHome: %s\nShell: %s\nComment: %s\n", 
               $1, $3, $4, $6, $7, $5
    }'
    
    if ! confirm "Are you sure you want to delete this user?"; then
        echo "User deletion canceled"
        return
    fi
    
    # Check for running processes
    local process_count=$(pgrep -u "$username" | wc -l)
    if [ $process_count -gt 0 ]; then
        echo -e "${YELLOW}User has $process_count running processes.${NC}"
        if confirm "Terminate these processes?"; then
            pkill -9 -u "$username"
            sleep 2
        fi
    fi
    
    # Delete the user
    if userdel -r "$username"; then
        echo -e "${GREEN}User $username deleted successfully${NC}"
    else
        echo -e "${RED}Failed to delete user $username${NC}"
        echo -e "${YELLOW}Trying alternative method...${NC}"
        userdel "$username" && rm -rf "/home/$username"
    fi
}

## GROUP FUNCTIONS ##

list_groups() {
    header "System Groups"
    
    # Detailed group listing
    echo -e "${BLUE}=== Group Information ===${NC}"
    awk -F: '{printf "%-15s %5s %s\n", $1, $3, $4}' "$GROUP_FILE" | 
    column -t -N "Group,GID,Members"
    
    # Password status for groups
    echo -e "\n${BLUE}=== Group Password Status ===${NC}"
    awk -F: '{
        if ($2 ~ /^[^x]/) printf "%-15s: Password protected\n", $1;
    }' "$GROUP_FILE"
}

add_group() {
    header "Add New Group"
    
    local groupname gid
    
    # Group name validation
    while true; do
        read -rp "Enter group name: " groupname
        if [[ "$groupname" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            if ! grep -q "^$groupname:" "$GROUP_FILE"; then
                break
            else
                echo -e "${RED}Group $groupname already exists!${NC}"
            fi
        else
            echo -e "${RED}Invalid group name format!${NC}"
        fi
    done
    
    # GID selection
    local next_gid=$(($(cut -d: -f3 "$GROUP_FILE" | sort -n | tail -1) + 1))
    read -rp "Enter GID (default: $next_gid): " gid
    [ -z "$gid" ] && gid="$next_gid"
    
    # Create the group
    if groupadd -g "$gid" "$groupname"; then
        echo -e "${GREEN}Group $groupname created successfully${NC}"
        
        if confirm "Add password protection to the group?"; then
            gpasswd "$groupname"
        fi
    else
        echo -e "${RED}Failed to create group${NC}"
    fi
}

modify_group() {
    header "Modify Group"
    
    read -rp "Enter group name to modify: " groupname
    
    if ! grep -q "^$groupname:" "$GROUP_FILE"; then
        echo -e "${RED}Group $groupname not found!${NC}"
        return 1
    fi
    
    # Display current group info
    echo -e "\n${BLUE}=== Current Group Info ===${NC}"
    grep "^$groupname:" "$GROUP_FILE" | awk -F: '{
        printf "Group: %s\nGID: %s\nMembers: %s\nPassword: %s\n", 
               $1, $3, $4, ($2 == "x" ? "No" : "Yes")
    }'
    
    PS3="Select operation: "
    options=(
        "Change GID"
        "Add User to Group"
        "Remove User from Group"
        "Set Group Password"
        "Remove Group Password"
        "Delete Group"
        "Back to Menu"
    )
    
    select opt in "${options[@]}"; do
        case $opt in
            "Change GID")
                local current_gid=$(grep "^$groupname:" "$GROUP_FILE" | cut -d: -f3)
                read -rp "Enter new GID (current: $current_gid): " new_gid
                [ -z "$new_gid" ] && new_gid="$current_gid"
                if groupmod -g "$new_gid" "$groupname"; then
                    echo "GID changed to $new_gid"
                else
                    echo "Failed to change GID"
                fi
                ;;
            "Add User to Group")
                local users=($(cut -d: -f1 "$PASSWORD_FILE"))
                select user_to_add in "${users[@]}"; do
                    if [ -n "$user_to_add" ]; then
                        if gpasswd -a "$user_to_add" "$groupname"; then
                            echo "Added $user_to_add to $groupname"
                        else
                            echo "Failed to add user to group"
                        fi
                        break
                    fi
                done
                ;;
            "Remove User from Group")
                local current_members=$(grep "^$groupname:" "$GROUP_FILE" | cut -d: -f4 | tr ',' '\n')
                if [ -z "$current_members" ]; then
                    echo "No members in this group"
                    break
                fi
                
                select user_to_remove in $current_members; do
                    if [ -n "$user_to_remove" ]; then
                        if gpasswd -d "$user_to_remove" "$groupname"; then
                            echo "Removed $user_to_remove from $groupname"
                        else
                            echo "Failed to remove user from group"
                        fi
                        break
                    fi
                done
                ;;
            "Set Group Password")
                gpasswd "$groupname"
                ;;
            "Remove Group Password")
                gpasswd -r "$groupname"
                echo "Password removed from $groupname"
                ;;
            "Delete Group")
                delete_group "$groupname"
                return
                ;;
            "Back to Menu")
                return
                ;;
            *) echo "Invalid option";;
        esac
    done
}

delete_group() {
    local groupname=${1:-$(input_prompt "Enter group name to delete: ")}
    
    if ! grep -q "^$groupname:" "$GROUP_FILE"; then
        echo -e "${RED}Group $groupname not found!${NC}"
        return 1
    fi
    
    # Show group info before deletion
    echo -e "\n${RED}=== WARNING: GROUP DELETION ===${NC}"
    echo -e "Group: $groupname"
    echo -e "GID: $(grep "^$groupname:" "$GROUP_FILE" | cut -d: -f3)"
    echo -e "Members: $(grep "^$groupname:" "$GROUP_FILE" | cut -d: -f4)"
    
    if ! confirm "Are you sure you want to delete this group?"; then
        echo "Group deletion canceled"
        return
    fi
    
    if groupdel "$groupname"; then
        echo -e "${GREEN}Group $groupname deleted successfully${NC}"
    else
        echo -e "${RED}Failed to delete group $groupname${NC}"
    fi
}

## MAIN MENU ##

main_menu() {
    while true; do
        header "User Management System"
        PS3="Select operation: "
        options=(
            "List Users"
            "Add User"
            "Modify User"
            "Delete User"
            "List Groups"
            "Add Group"
            "Modify Group"
            "Delete Group"
            "Exit"
        )
        
        select opt in "${options[@]}"; do
            case $opt in
                "List Users") list_users; break ;;
                "Add User") add_user; break ;;
                "Modify User") modify_user; break ;;
                "Delete User") delete_user; break ;;
                "List Groups") list_groups; break ;;
                "Add Group") add_group; break ;;
                "Modify Group") modify_group; break ;;
                "Delete Group") delete_group; break ;;
                "Exit") exit 0 ;;
                *) echo "Invalid option";;
            esac
        done
        
        read -rp $'\nPress Enter to continue...'
    done
}

# Start the script
main_menu
