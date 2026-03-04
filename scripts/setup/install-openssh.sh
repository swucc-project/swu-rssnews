#!/bin/bash
# install-openssh.sh
# Install and configure OpenSSH server on Rocky Linux

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SSH_PORT=22
ALLOW_ROOT_LOGIN=no
PASSWORD_AUTH=no
PUBKEY_AUTH=yes

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ This script must be run as root${NC}"
        exit 1
    fi
}

install_openssh() {
    echo -e "${CYAN}📦 Installing OpenSSH Server...${NC}"
    
    # Update system
    dnf update -y
    
    # Install OpenSSH
    dnf install -y openssh-server openssh-clients
    
    echo -e "${GREEN}✅ OpenSSH installed${NC}"
}

configure_ssh() {
    echo -e "${CYAN}🔧 Configuring SSH...${NC}"
    
    # Backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
    
    # Configure SSH settings
    cat > /etc/ssh/sshd_config.d/99-custom.conf << EOF
# Custom SSH Configuration for swu-rssnews project

# Port Configuration
Port ${SSH_PORT}

# Authentication
PermitRootLogin ${ALLOW_ROOT_LOGIN}
PubkeyAuthentication ${PUBKEY_AUTH}
PasswordAuthentication ${PASSWORD_AUTH}

# Security Settings
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Disable weak algorithms
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# Connection Settings
MaxAuthTries 3
MaxSessions 10
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging
SyslogFacility AUTH
LogLevel INFO

# Allow specific users (uncomment and modify as needed)
# AllowUsers developer docker-admin

# X11 Forwarding (useful for GUI apps)
X11Forwarding yes
X11DisplayOffset 10

# Accept locale-related environment variables
AcceptEnv LANG LC_*

# Override default of no subsystems
Subsystem sftp /usr/libexec/openssh/sftp-server
EOF
    
    echo -e "${GREEN}✅ SSH configured${NC}"
}

setup_firewall() {
    echo -e "${CYAN}🔥 Configuring Firewall for SSH...${NC}"
    
    if command -v firewall-cmd &> /dev/null; then
        # Add SSH service
        firewall-cmd --permanent --add-service=ssh
        
        # If using custom port
        if [[ ${SSH_PORT} != "22" ]]; then
            firewall-cmd --permanent --add-port=${SSH_PORT}/tcp
            firewall-cmd --permanent --remove-service=ssh
        fi
        
        # Reload firewall
        firewall-cmd --reload
        
        echo -e "${GREEN}✅ Firewall configured${NC}"
    else
        echo -e "${YELLOW}⚠️  firewalld not found, skipping firewall configuration${NC}"
    fi
}

setup_selinux() {
    echo -e "${CYAN}🔒 Configuring SELinux for SSH...${NC}"
    
    if command -v semanage &> /dev/null; then
        # Allow custom SSH port
        if [[ ${SSH_PORT} != "22" ]]; then
            semanage port -a -t ssh_port_t -p tcp ${SSH_PORT} 2>/dev/null || \
            semanage port -m -t ssh_port_t -p tcp ${SSH_PORT}
        fi
        
        echo -e "${GREEN}✅ SELinux configured${NC}"
    else
        echo -e "${YELLOW}⚠️  SELinux tools not found, skipping${NC}"
    fi
}

enable_ssh_service() {
    echo -e "${CYAN}🚀 Starting SSH Service...${NC}"
    
    # Enable and start SSH
    systemctl enable sshd
    systemctl restart sshd
    
    # Check status
    if systemctl is-active --quiet sshd; then
        echo -e "${GREEN}✅ SSH service is running${NC}"
    else
        echo -e "${RED}❌ SSH service failed to start${NC}"
        systemctl status sshd
        exit 1
    fi
}

setup_ssh_keys() {
    echo -e "${CYAN}🔑 Setting up SSH keys...${NC}"
    
    # Create .ssh directory for current user
    if [[ -n "$SUDO_USER" ]]; then
        local user_home=$(eval echo ~$SUDO_USER)
        local ssh_dir="$user_home/.ssh"
        
        mkdir -p "$ssh_dir"
        touch "$ssh_dir/authorized_keys"
        chmod 700 "$ssh_dir"
        chmod 600 "$ssh_dir/authorized_keys"
        chown -R $SUDO_USER:$SUDO_USER "$ssh_dir"
        
        echo -e "${GREEN}✅ SSH directory created for $SUDO_USER${NC}"
        echo -e "${YELLOW}💡 Add your public key to: $ssh_dir/authorized_keys${NC}"
    fi
}

show_status() {
    echo -e "\n${CYAN}📊 SSH Status${NC}"
    echo "===================="
    
    echo -e "\n${YELLOW}Service Status:${NC}"
    systemctl status sshd --no-pager | grep -E "Active:|Main PID:"
    
    echo -e "\n${YELLOW}Listening Ports:${NC}"
    ss -tlnp | grep sshd
    
    echo -e "\n${YELLOW}SSH Configuration:${NC}"
    grep -E "^Port|^PermitRootLogin|^PubkeyAuthentication|^PasswordAuthentication" /etc/ssh/sshd_config.d/99-custom.conf
    
    echo -e "\n${YELLOW}Firewall Rules:${NC}"
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --list-services
        firewall-cmd --list-ports
    fi
    
    echo -e "\n${GREEN}✅ Installation Complete!${NC}"
    echo -e "${CYAN}Connect using: ssh user@$(hostname -I | awk '{print $1}') -p ${SSH_PORT}${NC}"
}

# Main execution
main() {
    check_root
    
    echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   OpenSSH Server Installation         ║${NC}"
    echo -e "${CYAN}║   for swu-rssnews project             ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}\n"
    
    install_openssh
    configure_ssh
    setup_firewall
    setup_selinux
    setup_ssh_keys
    enable_ssh_service
    show_status
}

main "$@"