#!/bin/bash
# ssh-hardening.sh
# Security hardening for SSH server

set -e

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Must run as root"
        exit 1
    fi
}

install_fail2ban() {
    echo "🔒 Installing Fail2Ban..."
    
    dnf install -y epel-release
    dnf install -y fail2ban fail2ban-systemd
    
    # Configure Fail2Ban for SSH
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
destemail = admin@swu.ac.th
sendername = Fail2Ban

[sshd]
enabled = true
port = ssh
logpath = /var/log/secure
maxretry = 3
bantime = 3600
EOF
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    echo "✅ Fail2Ban configured"
}

setup_2fa() {
    echo "🔐 Setting up 2FA (Google Authenticator)..."
    
    dnf install -y google-authenticator
    
    echo "⚠️  Run 'google-authenticator' as regular user to setup"
}

enable_ssh_audit_log() {
    echo "📋 Enabling SSH audit logging..."
    
    # Enable detailed logging
    sed -i 's/^LogLevel.*/LogLevel VERBOSE/' /etc/ssh/sshd_config
    
    # Install auditd
    dnf install -y audit
    systemctl enable auditd
    systemctl start auditd
    
    # Add SSH audit rules
    cat >> /etc/audit/rules.d/ssh.rules << EOF
# SSH Audit Rules
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /var/log/secure -p wa -k ssh_logs
EOF
    
    service auditd restart
    
    echo "✅ SSH audit logging enabled"
}

check_root
install_fail2ban
setup_2fa
enable_ssh_audit_log

echo "✅ SSH hardening complete!"