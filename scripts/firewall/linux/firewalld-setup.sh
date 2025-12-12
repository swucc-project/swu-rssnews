#!/bin/bash
# firewalld-setup.sh
# Firewall configuration for Rocky Linux (firewalld)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Port configurations
declare -A DEV_PORTS=(
    ["ASP.NET Core API"]="5000/tcp"
    ["Vite Dev Server"]="5173/tcp"
    ["Nginx Dev HTTP"]="8080/tcp"
    ["SSR Server"]="13714/tcp"
    ["Vite HMR WebSocket"]="24678/tcp"
    ["SQL Server"]="1433/tcp"
    ["OpenSSH Server"]="22/tcp"
)

declare -A PROD_PORTS=(
    ["Nginx HTTP"]="80/tcp"
    ["Nginx HTTPS"]="443/tcp"
)

# Functions
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ This script must be run as root${NC}"
        exit 1
    fi
}

check_firewalld() {
    if ! systemctl is-active --quiet firewalld; then
        echo -e "${YELLOW}⚠️  firewalld is not running. Starting...${NC}"
        systemctl start firewalld
        systemctl enable firewalld
    fi
    echo -e "${GREEN}✅ firewalld is running${NC}"
}

setup_zones() {
    local zone="${1:-public}"
    
    echo -e "\n${CYAN}🔧 Configuring zone: $zone${NC}"
    
    # Set default zone
    firewall-cmd --set-default-zone="$zone"
    
    # Allow Docker interface
    if firewall-cmd --get-active-zones | grep -q docker; then
        firewall-cmd --zone=trusted --add-interface=docker0 --permanent 2>/dev/null || true
    fi
}

add_development_ports() {
    local zone="${1:-public}"
    
    echo -e "\n${CYAN}📦 Adding Development Ports...${NC}"
    
    for name in "${!DEV_PORTS[@]}"; do
        local port="${DEV_PORTS[$name]}"
        echo -e "${YELLOW}🔧 Opening: $name ($port)${NC}"
        
        firewall-cmd --zone="$zone" --add-port="$port" --permanent
        
        # Add rich rule for localhost and Docker subnet
        firewall-cmd --zone="$zone" --add-rich-rule="rule family=ipv4 source address=127.0.0.1 port port=${port%/*} protocol=tcp accept" --permanent
        firewall-cmd --zone="$zone" --add-rich-rule="rule family=ipv4 source address=172.16.0.0/12 port port=${port%/*} protocol=tcp accept" --permanent
    done
    
    echo -e "${GREEN}✅ Development ports configured${NC}"
}

add_production_ports() {
    local zone="${1:-public}"
    
    echo -e "\n${CYAN}🏭 Adding Production Ports...${NC}"
    
    for name in "${!PROD_PORTS[@]}"; do
        local port="${PROD_PORTS[$name]}"
        echo -e "${YELLOW}🔧 Opening: $name ($port)${NC}"
        
        firewall-cmd --zone="$zone" --add-port="$port" --permanent
        
        # Add service if available
        if [[ "$name" == *"HTTP"* ]]; then
            firewall-cmd --zone="$zone" --add-service=http --permanent
        fi
        if [[ "$name" == *"HTTPS"* ]]; then
            firewall-cmd --zone="$zone" --add-service=https --permanent
        fi
    done
    
    echo -e "${GREEN}✅ Production ports configured${NC}"
}

add_docker_rules() {
    local zone="${1:-public}"
    
    echo -e "\n${CYAN}🐳 Configuring Docker-specific rules...${NC}"
    
    # Allow Docker subnet
    firewall-cmd --zone="$zone" --add-rich-rule='rule family=ipv4 source address=172.17.0.0/16 accept' --permanent
    firewall-cmd --zone="$zone" --add-rich-rule='rule family=ipv4 source address=172.18.0.0/16 accept' --permanent
    
    # Allow WSL2 bridge (if exists)
    if ip addr show | grep -q "172.24"; then
        firewall-cmd --zone="$zone" --add-rich-rule='rule family=ipv4 source address=172.24.0.0/16 accept' --permanent
    fi
    
    # Masquerade for Docker
    firewall-cmd --zone="$zone" --add-masquerade --permanent
    
    echo -e "${GREEN}✅ Docker rules configured${NC}"
}

reload_firewall() {
    echo -e "\n${CYAN}🔄 Reloading firewall...${NC}"
    firewall-cmd --reload
    echo -e "${GREEN}✅ Firewall reloaded${NC}"
}

show_status() {
    echo -e "\n${CYAN}📊 Firewall Status${NC}"
    echo "===================="
    
    echo -e "\n${YELLOW}Active Zones:${NC}"
    firewall-cmd --get-active-zones
    
    echo -e "\n${YELLOW}Default Zone:${NC}"
    firewall-cmd --get-default-zone
    
    echo -e "\n${YELLOW}Open Ports (public):${NC}"
    firewall-cmd --zone=public --list-ports
    
    echo -e "\n${YELLOW}Services (public):${NC}"
    firewall-cmd --zone=public --list-services
    
    echo -e "\n${YELLOW}Rich Rules:${NC}"
    firewall-cmd --zone=public --list-rich-rules
}

remove_rules() {
    local zone="${1:-public}"
    
    echo -e "\n${RED}🗑️  Removing firewall rules...${NC}"
    
    # Remove development ports
    for port in "${DEV_PORTS[@]}"; do
        firewall-cmd --zone="$zone" --remove-port="$port" --permanent 2>/dev/null || true
    done
    
    # Remove production ports
    for port in "${PROD_PORTS[@]}"; do
        firewall-cmd --zone="$zone" --remove-port="$port" --permanent 2>/dev/null || true
    done
    
    reload_firewall
    echo -e "${GREEN}✅ Rules removed${NC}"
}

# Main execution
main() {
    local action="${1:-enable}"
    local environment="${2:-development}"
    local zone="${3:-public}"
    
    check_root
    check_firewalld
    
    case "$action" in
        enable)
            echo -e "${GREEN}🚀 Enabling firewall rules...${NC}"
            setup_zones "$zone"
            add_docker_rules "$zone"
            
            if [[ "$environment" == "development" ]] || [[ "$environment" == "all" ]]; then
                add_development_ports "$zone"
            fi
            
            if [[ "$environment" == "production" ]] || [[ "$environment" == "all" ]]; then
                add_production_ports "$zone"
            fi
            
            reload_firewall
            show_status
            ;;
            
        disable)
            echo -e "${YELLOW}⏸️  Disabling firewall...${NC}"
            systemctl stop firewalld
            ;;
            
        remove)
            remove_rules "$zone"
            ;;
            
        status)
            show_status
            ;;
            
        *)
            echo -e "${RED}❌ Invalid action: $action${NC}"
            echo "Usage: $0 {enable|disable|remove|status} [development|production|all] [zone]"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"