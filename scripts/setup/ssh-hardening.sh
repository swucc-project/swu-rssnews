#!/bin/bash
# ssh-hardening.sh
# Security hardening for SSH server
# Enhanced version with better security practices

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@swu.ac.th}"
SSH_PORT="${SSH_PORT:-22}"
BAN_TIME="${BAN_TIME:-3600}"
MAX_RETRY="${MAX_RETRY:-3}"

# Functions
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ This script must be run as root${NC}"
        exit 1
    fi
}

check_os() {
    if [[ ! -f /etc/rocky-release ]] && [[ ! -f /etc/redhat-release ]]; then
        echo -e "${YELLOW}⚠️  Warning: This script is designed for Rocky Linux/RHEL${NC}"
        read -p "Continue anyway? (yes/no): " confirm
        [[ "$confirm" != "yes" ]] && exit 1
    fi
}

backup_config() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✅ Backed up: $file${NC}"
    fi
}

install_fail2ban() {
    echo -e "\n${CYAN}🔒 Installing and Configuring Fail2Ban...${NC}"
    
    # Check if already installed
    if command -v fail2ban-server &> /dev/null; then
        echo -e "${YELLOW}ℹ️  Fail2Ban already installed${NC}"
    else
        # Install EPEL repository
        dnf install -y epel-release
        
        # Install Fail2Ban
        dnf install -y fail2ban fail2ban-systemd
    fi
    
    # Backup existing config
    [[ -f /etc/fail2ban/jail.local ]] && backup_config /etc/fail2ban/jail.local
    
    # Configure Fail2Ban for SSH
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# Ban time in seconds (1 hour)
bantime = ${BAN_TIME}
# Time window for counting retries (10 minutes)
findtime = 600
# Number of failures before ban
maxretry = ${MAX_RETRY}
# Email configuration
destemail = ${ADMIN_EMAIL}
sendername = Fail2Ban-swu-rssnews
# Action: ban and send email
action = %(action_mwl)s

# Backend
backend = systemd

[sshd]
enabled = true
port = ${SSH_PORT}
logpath = /var/log/secure
maxretry = ${MAX_RETRY}
bantime = ${BAN_TIME}
findtime = 600
# Ignore localhost and private networks
ignoreip = 127.0.0.1/8 ::1 172.16.0.0/12

[sshd-aggressive]
# More aggressive detection
enabled = false
port = ${SSH_PORT}
logpath = /var/log/secure
maxretry = 2
bantime = 86400
findtime = 300
EOF
    
    # Enable and start Fail2Ban
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    # Wait for service to start
    sleep 2
    
    # Check status
    if systemctl is-active --quiet fail2ban; then
        echo -e "${GREEN}✅ Fail2Ban configured and running${NC}"
        
        # Show status
        echo -e "\n${YELLOW}📊 Fail2Ban Status:${NC}"
        fail2ban-client status sshd 2>/dev/null || echo "SSH jail not active yet"
    else
        echo -e "${RED}❌ Fail2Ban failed to start${NC}"
        systemctl status fail2ban
        exit 1
    fi
}

setup_2fa() {
    echo -e "\n${CYAN}🔐 Setting up 2FA (Google Authenticator)...${NC}"
    
    # Install Google Authenticator
    if ! command -v google-authenticator &> /dev/null; then
        dnf install -y google-authenticator
    else
        echo -e "${YELLOW}ℹ️  Google Authenticator already installed${NC}"
    fi
    
    # Backup PAM config
    backup_config /etc/pam.d/sshd
    
    # Configure PAM for 2FA (optional - commented out by default)
    cat > /etc/pam.d/sshd.2fa << 'EOF'
#%PAM-1.0
# Uncomment the line below to enable 2FA
# auth required pam_google_authenticator.so nullok

auth       substack     password-auth
auth       include      postlogin
account    required     pam_sepermit.so
account    required     pam_nologin.so
account    include      password-auth
password   include      password-auth
session    required     pam_selinux.so close
session    required     pam_loginuid.so
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    optional     pam_motd.so
session    include      password-auth
session    include      postlogin
EOF
    
    echo -e "${GREEN}✅ 2FA package installed${NC}"
    echo -e "${YELLOW}⚠️  To enable 2FA:${NC}"
    echo -e "   1. Run as regular user: ${CYAN}google-authenticator${NC}"
    echo -e "   2. Edit /etc/pam.d/sshd and uncomment the 2FA line"
    echo -e "   3. Add to /etc/ssh/sshd_config: ${CYAN}ChallengeResponseAuthentication yes${NC}"
    echo -e "   4. Restart sshd: ${CYAN}systemctl restart sshd${NC}"
}

enable_ssh_audit_log() {
    echo -e "\n${CYAN}📋 Enabling SSH Audit Logging...${NC}"
    
    # Install auditd
    if ! command -v auditctl &> /dev/null; then
        dnf install -y audit
    else
        echo -e "${YELLOW}ℹ️  Auditd already installed${NC}"
    fi
    
    # Enable and start auditd
    systemctl enable auditd
    systemctl start auditd || true  # May already be running
    
    # Create audit rules directory if not exists
    mkdir -p /etc/audit/rules.d
    
    # Backup existing SSH audit rules
    [[ -f /etc/audit/rules.d/ssh.rules ]] && backup_config /etc/audit/rules.d/ssh.rules
    
    # Add comprehensive SSH audit rules
    cat > /etc/audit/rules.d/ssh.rules << EOF
# SSH Security Audit Rules for swu-rssnews project
# Monitor SSH configuration changes
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/ssh/sshd_config.d/ -p wa -k sshd_config

# Monitor SSH keys
-w /root/.ssh -p wa -k root_ssh_keys
-w /etc/ssh/ -p wa -k ssh_host_keys

# Monitor authentication logs
-w /var/log/secure -p wa -k ssh_logs
-w /var/log/auth.log -p wa -k auth_logs

# Monitor user additions/modifications
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/group -p wa -k group_changes

# Monitor sudo usage
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

# Monitor PAM configuration
-w /etc/pam.d/ -p wa -k pam_changes
EOF
    
    # Load audit rules
    augenrules --load 2>/dev/null || service auditd restart
    
    echo -e "${GREEN}✅ SSH audit logging enabled${NC}"
    
    # Show active rules
    echo -e "\n${YELLOW}📊 Active Audit Rules:${NC}"
    auditctl -l | grep -E "ssh|auth" || echo "No SSH audit rules found"
}

configure_ssh_logging() {
    echo -e "\n${CYAN}📝 Configuring SSH Logging...${NC}"
    
    # Backup SSH config
    backup_config /etc/ssh/sshd_config
    
    # Create custom logging config
    cat > /etc/ssh/sshd_config.d/98-logging.conf << EOF
# Enhanced SSH Logging Configuration
# Log level: QUIET, FATAL, ERROR, INFO, VERBOSE, DEBUG, DEBUG1, DEBUG2, DEBUG3
LogLevel VERBOSE

# Log authentication attempts
SyslogFacility AUTH

# Log failed login attempts
MaxAuthTries ${MAX_RETRY}
EOF
    
    # Configure rsyslog for SSH
    if command -v rsyslogd &> /dev/null; then
        cat > /etc/rsyslog.d/ssh.conf << EOF
# SSH Logging Configuration
# Separate SSH logs
:programname, isequal, "sshd" /var/log/ssh.log

# Also log authentication failures
:msg, contains, "Failed password" /var/log/ssh-failed.log
:msg, contains, "Invalid user" /var/log/ssh-invalid.log
EOF
        
        systemctl restart rsyslog
        echo -e "${GREEN}✅ rsyslog configured for SSH${NC}"
    fi
}

install_intrusion_detection() {
    echo -e "\n${CYAN}🛡️  Installing Intrusion Detection (AIDE)...${NC}"
    
    # Install AIDE (Advanced Intrusion Detection Environment)
    if ! command -v aide &> /dev/null; then
        dnf install -y aide
        
        # Initialize AIDE database
        echo -e "${YELLOW}⏳ Initializing AIDE database (this may take a while)...${NC}"
        aide --init
        mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz 2>/dev/null || true
        
        echo -e "${GREEN}✅ AIDE installed and initialized${NC}"
    else
        echo -e "${YELLOW}ℹ️  AIDE already installed${NC}"
    fi
    
    # Create daily check cron job
    cat > /etc/cron.daily/aide-check << 'EOF'
#!/bin/bash
# Daily AIDE integrity check
/usr/sbin/aide --check 2>&1 | mail -s "AIDE Daily Check - $(hostname)" root
EOF
    
    chmod +x /etc/cron.daily/aide-check
}

configure_ssh_rate_limiting() {
    echo -e "\n${CYAN}⏱️  Configuring SSH Rate Limiting...${NC}"
    
    # Create rate limiting config
    cat > /etc/ssh/sshd_config.d/97-rate-limit.conf << EOF
# SSH Connection Rate Limiting
# Limit new connections to prevent brute force
MaxStartups 10:30:60

# Maximum number of concurrent sessions per connection
MaxSessions 10

# Client alive interval (keep-alive)
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
    
    echo -e "${GREEN}✅ Rate limiting configured${NC}"
}

setup_logwatch() {
    echo -e "\n${CYAN}📧 Setting up Logwatch for SSH monitoring...${NC}"
    
    if ! command -v logwatch &> /dev/null; then
        dnf install -y logwatch
        
        # Configure logwatch
        mkdir -p /etc/logwatch/conf
        cat > /etc/logwatch/conf/logwatch.conf << EOF
LogDir = /var/log
TmpDir = /var/cache/logwatch
Output = mail
Format = html
Encode = base64
MailTo = ${ADMIN_EMAIL}
MailFrom = logwatch@$(hostname)
Subject = Logwatch Report for $(hostname)
Service = sshd
Service = sshd-session
Detail = Med
Range = yesterday
EOF
        
        echo -e "${GREEN}✅ Logwatch configured${NC}"
    else
        echo -e "${YELLOW}ℹ️  Logwatch already installed${NC}"
    fi
}

show_hardening_status() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          SSH Hardening Status Report                 ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${YELLOW}🔒 Fail2Ban:${NC}"
    if systemctl is-active --quiet fail2ban; then
        echo "   ✅ Running"
        fail2ban-client status sshd 2>/dev/null | grep -E "Currently banned|Total banned"
    else
        echo "   ❌ Not running"
    fi
    
    echo -e "\n${YELLOW}📋 Audit Daemon:${NC}"
    if systemctl is-active --quiet auditd; then
        echo "   ✅ Running"
        echo "   Rules: $(auditctl -l | wc -l) active rules"
    else
        echo "   ❌ Not running"
    fi
    
    echo -e "\n${YELLOW}🔐 2FA:${NC}"
    if rpm -q google-authenticator &> /dev/null; then
        echo "   ✅ Installed (manual setup required)"
    else
        echo "   ❌ Not installed"
    fi
    
    echo -e "\n${YELLOW}🛡️  AIDE:${NC}"
    if command -v aide &> /dev/null; then
        echo "   ✅ Installed"
    else
        echo "   ❌ Not installed"
    fi
    
    echo -e "\n${YELLOW}📝 SSH Log Files:${NC}"
    [[ -f /var/log/secure ]] && echo "   ✅ /var/log/secure"
    [[ -f /var/log/ssh.log ]] && echo "   ✅ /var/log/ssh.log"
    
    echo -e "\n${YELLOW}🔥 Firewall:${NC}"
    if systemctl is-active --quiet firewalld; then
        echo "   ✅ Running"
        firewall-cmd --list-services | grep -q ssh && echo "   ✅ SSH allowed"
    else
        echo "   ⚠️  Not running"
    fi
}

create_monitoring_script() {
    echo -e "\n${CYAN}📊 Creating monitoring script...${NC}"
    
    cat > /usr/local/bin/ssh-monitor << 'EOFSCRIPT'
#!/bin/bash
# SSH monitoring script

echo "=== SSH Security Monitor ==="
echo ""

echo "Recent Failed Login Attempts:"
grep "Failed password" /var/log/secure | tail -10

echo -e "\nRecent Successful Logins:"
last -10

echo -e "\nCurrent SSH Connections:"
who

echo -e "\nFail2Ban Status:"
fail2ban-client status sshd 2>/dev/null

echo -e "\nActive SSH Sessions:"
ss -tnp | grep sshd

echo -e "\nSSH Configuration:"
sshd -T 2>/dev/null | grep -E "permitrootlogin|passwordauthentication|pubkeyauthentication"
EOFSCRIPT
    
    chmod +x /usr/local/bin/ssh-monitor
    echo -e "${GREEN}✅ Monitoring script created: /usr/local/bin/ssh-monitor${NC}"
}

# Main execution
main() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        SSH Security Hardening Script                ║${NC}"
    echo -e "${CYAN}║        for swu-rssnews project                       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}\n"
    
    check_root
    check_os
    
    # Show configuration
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Admin Email: $ADMIN_EMAIL"
    echo "  SSH Port: $SSH_PORT"
    echo "  Ban Time: $BAN_TIME seconds"
    echo "  Max Retry: $MAX_RETRY"
    echo ""
    
    read -p "Continue with hardening? (yes/no): " confirm
    [[ "$confirm" != "yes" ]] && exit 0
    
    # Execute hardening steps
    install_fail2ban
    enable_ssh_audit_log
    configure_ssh_logging
    configure_ssh_rate_limiting
    setup_2fa
    install_intrusion_detection
    setup_logwatch
    create_monitoring_script
    
    # Restart SSH to apply changes
    echo -e "\n${CYAN}🔄 Restarting SSH service...${NC}"
    systemctl restart sshd
    
    if systemctl is-active --quiet sshd; then
        echo -e "${GREEN}✅ SSH service restarted successfully${NC}"
    else
        echo -e "${RED}❌ SSH service failed to restart!${NC}"
        systemctl status sshd
        exit 1
    fi
    
    # Show final status
    show_hardening_status
    
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          SSH Hardening Complete! ✅                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${YELLOW}📝 Next Steps:${NC}"
    echo "  1. Review logs: tail -f /var/log/secure"
    echo "  2. Monitor with: ssh-monitor"
    echo "  3. Check Fail2Ban: fail2ban-client status sshd"
    echo "  4. Test SSH connection from another terminal"
    echo "  5. Enable 2FA if needed (see instructions above)"
    echo ""
    echo -e "${CYAN}💡 Backup files saved with .backup.YYYYMMDD_HHMMSS suffix${NC}"
}

# Run main function
main "$@"