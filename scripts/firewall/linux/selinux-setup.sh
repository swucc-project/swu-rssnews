#!/bin/bash
# selinux-setup.sh
# Configure SELinux policies for Docker ports

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PORTS=(5000 5173 8080 1433 13714 24678 22)

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ Must run as root${NC}"
        exit 1
    fi
}

check_selinux() {
    if ! command -v getenforce &> /dev/null; then
        echo -e "${YELLOW}⚠️  SELinux tools not installed${NC}"
        return 1
    fi
    
    local status=$(getenforce)
    echo -e "${CYAN}SELinux Status: $status${NC}"
    
    if [[ "$status" == "Disabled" ]]; then
        echo -e "${YELLOW}⚠️  SELinux is disabled${NC}"
        return 1
    fi
    
    return 0
}

add_http_port_context() {
    echo -e "\n${CYAN}🔧 Configuring SELinux port contexts...${NC}"
    
    for port in "${PORTS[@]}"; do
        echo -e "${YELLOW}Adding http_port_t context for port $port${NC}"
        
        # ✅ สำหรับ SSH ใช้ ssh_port_t แทน http_port_t
        if [[ $port -eq 22 ]]; then
            echo -e "${CYAN}Port 22 detected - using ssh_port_t context${NC}"
            semanage port -a -t ssh_port_t -p tcp "$port" 2>/dev/null || \
            semanage port -m -t ssh_port_t -p tcp "$port"
        else
            # Add port to http_port_t type
            semanage port -a -t http_port_t -p tcp "$port" 2>/dev/null || \
            semanage port -m -t http_port_t -p tcp "$port"
        fi
        
        echo -e "${GREEN}✅ Port $port configured${NC}"
    done
}

allow_docker_selinux() {
    echo -e "\n${CYAN}🐳 Configuring Docker SELinux permissions...${NC}"
    
    # Allow Docker containers to bind to any port
    if command -v setsebool &> /dev/null; then
        setsebool -P container_manage_cgroup 1
        setsebool -P virt_use_nfs 1
        setsebool -P virt_use_samba 1
        echo -e "${GREEN}✅ Docker SELinux booleans set${NC}"
    fi
}

show_port_contexts() {
    echo -e "\n${CYAN}📊 Current Port Contexts${NC}"
    echo "=========================="
    
    for port in "${PORTS[@]}"; do
        if [[ $port -eq 22 ]]; then
            # SSH port
            semanage port -l | grep "^ssh_port_t" | grep -w "$port" || echo "Port $port: Not configured"
        else
            # HTTP ports
            semanage port -l | grep "^http_port_t" | grep -w "$port" || echo "Port $port: Not configured"
        fi
    done
}

remove_port_contexts() {
    echo -e "\n${RED}🗑️  Removing port contexts...${NC}"
    
    for port in "${PORTS[@]}"; do
        if [[ $port -eq 22 ]]; then
            semanage port -d -t ssh_port_t -p tcp "$port" 2>/dev/null || true
        else
            semanage port -d -t http_port_t -p tcp "$port" 2>/dev/null || true
        fi
    done
    
    echo -e "${GREEN}✅ Port contexts removed${NC}"
}

main() {
    local action="${1:-enable}"
    
    check_root
    
    if ! check_selinux; then
        echo -e "${YELLOW}⚠️  SELinux not available, skipping...${NC}"
        exit 0
    fi
    
    case "$action" in
        enable)
            add_http_port_context
            allow_docker_selinux
            show_port_contexts
            ;;
            
        remove)
            remove_port_contexts
            ;;
            
        status)
            show_port_contexts
            ;;
            
        *)
            echo "Usage: $0 {enable|remove|status}"
            exit 1
            ;;
    esac
}

main "$@"