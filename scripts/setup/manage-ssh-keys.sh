#!/bin/bash
# manage-ssh-keys.sh
# Manage SSH keys for the project

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SSH_KEY_DIR="$HOME/.ssh"
KEY_NAME="swu-rssnews"

generate_ssh_key() {
    echo -e "${CYAN}🔑 Generating SSH Key Pair...${NC}"
    
    mkdir -p "$SSH_KEY_DIR"
    chmod 700 "$SSH_KEY_DIR"
    
    local key_path="$SSH_KEY_DIR/$KEY_NAME"
    
    if [[ -f "$key_path" ]]; then
        echo -e "${YELLOW}⚠️  Key already exists: $key_path${NC}"
        read -p "Overwrite? (yes/no): " confirm
        [[ "$confirm" != "yes" ]] && return
    fi
    
    ssh-keygen -t ed25519 -C "swu-rssnews-$(hostname)" -f "$key_path"
    
    echo -e "${GREEN}✅ SSH key generated${NC}"
    echo -e "${CYAN}Public key:${NC}"
    cat "$key_path.pub"
}

add_key_to_server() {
    local server="${1}"
    local user="${2:-$USER}"
    
    if [[ -z "$server" ]]; then
        echo -e "${RED}❌ Server address required${NC}"
        echo "Usage: $0 add-to-server <server> [user]"
        exit 1
    fi
    
    echo -e "${CYAN}📤 Adding key to server: $user@$server${NC}"
    
    local key_path="$SSH_KEY_DIR/$KEY_NAME.pub"
    
    if [[ ! -f "$key_path" ]]; then
        echo -e "${RED}❌ Public key not found: $key_path${NC}"
        echo -e "${YELLOW}Run: $0 generate${NC}"
        exit 1
    fi
    
    ssh-copy-id -i "$key_path" "$user@$server"
    
    echo -e "${GREEN}✅ Key added to server${NC}"
}

list_keys() {
    echo -e "${CYAN}📋 SSH Keys:${NC}"
    echo "===================="
    
    ls -lh "$SSH_KEY_DIR"/*.pub 2>/dev/null || echo "No keys found"
    
    echo -e "\n${CYAN}🔓 SSH Agent Keys:${NC}"
    ssh-add -l 2>/dev/null || echo "No keys in agent"
}

add_to_agent() {
    echo -e "${CYAN}🔐 Adding key to SSH agent...${NC}"
    
    eval "$(ssh-agent -s)"
    ssh-add "$SSH_KEY_DIR/$KEY_NAME"
    
    echo -e "${GREEN}✅ Key added to agent${NC}"
}

test_connection() {
    local server="${1}"
    local user="${2:-$USER}"
    
    if [[ -z "$server" ]]; then
        echo -e "${RED}❌ Server address required${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}🧪 Testing SSH connection to $user@$server...${NC}"
    
    ssh -v -i "$SSH_KEY_DIR/$KEY_NAME" "$user@$server" "echo '✅ Connection successful!'"
}

show_config() {
    echo -e "${CYAN}📝 SSH Client Configuration:${NC}"
    echo "===================="
    
    cat << EOF
Add this to ~/.ssh/config:

Host swu-rssnews-prod
    HostName <production-server-ip>
    User <your-username>
    Port 22
    IdentityFile ~/.ssh/$KEY_NAME
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host swu-rssnews-dev
    HostName <dev-server-ip>
    User <your-username>
    Port 22
    IdentityFile ~/.ssh/$KEY_NAME
    
# For WSL2 access from Windows
Host wsl-rocky
    HostName 127.0.0.1
    User <your-username>
    Port 22
    IdentityFile ~/.ssh/$KEY_NAME
EOF
}

# Main execution
case "${1}" in
    generate)
        generate_ssh_key
        ;;
    add-to-server)
        add_key_to_server "${2}" "${3}"
        ;;
    list)
        list_keys
        ;;
    add-to-agent)
        add_to_agent
        ;;
    test)
        test_connection "${2}" "${3}"
        ;;
    show-config)
        show_config
        ;;
    *)
        echo "Usage: $0 {generate|add-to-server|list|add-to-agent|test|show-config}"
        exit 1
        ;;
esac