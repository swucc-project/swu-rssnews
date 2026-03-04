#!/bin/bash
set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Please run as root${NC}"
        exit 1
    fi
}

install_fail2ban() {
    echo -e "${CYAN}📦 Installing fail2ban...${NC}"
    
    dnf install -y epel-release
    dnf install -y fail2ban fail2ban-systemd
    
    systemctl enable fail2ban
    systemctl start fail2ban
    
    cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = ssh,2222
logpath = /var/log/secure
maxretry = 3
bantime = 3600
findtime = 600
EOF
    
    systemctl restart fail2ban
    echo -e "${GREEN}✅ fail2ban configured${NC}"
}

enable_ssh_audit_log() {
    echo -e "${CYAN}📋 Enabling SSH audit logging...${NC}"
    
    dnf install -y audit
    systemctl enable auditd
    systemctl start auditd
    
    cat >> /etc/audit/rules.d/ssh.rules << 'EOF'
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /var/log/secure -p wa -k ssh_logs
EOF
    
    service auditd restart
    echo -e "${GREEN}✅ SSH audit logging enabled${NC}"
}

check_root
install_fail2ban
enable_ssh_audit_log

echo -e "${GREEN}✅ SSH hardening complete!${NC}"