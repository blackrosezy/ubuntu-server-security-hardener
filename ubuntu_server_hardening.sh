#!/bin/bash

# Ubuntu 24.04 LTS Server Hardening Script with Fail2ban and SMTP Configuration

# Before running this script:
# 1. Create a sudo user for SSH login:
#    a. Create user: sudo adduser newusername
#    b. Add to sudo group: sudo usermod -aG sudo newusername
#    c. Set up SSH key authentication for the new user
#    d. Test SSH login with the new user before running this script
#
# 2. If you need to enable additional ports (e.g., for web server):
#    a. For HTTP: Add the line 'sudo ufw allow 80/tcp' after the existing ufw rules
#    b. For HTTPS: Add the line 'sudo ufw allow 443/tcp' after the existing ufw rules
#    c. For other services, use: sudo ufw allow [port_number]/tcp
#    Remember to adjust your cloud firewall settings if necessary

# Configuration Variables
SSH_PORT=52369  # Random 5-digit port number
ALLOWED_USERS="newusername"  # Space-separated list of users allowed to SSH
ALERT_EMAIL="your_email@example.com"
SMTP_SERVER="mail.smtp2go.com"
SMTP_PORT="2525"
SMTP_USERNAME="your_smtp2go_username"
SMTP_PASSWORD="your_smtp2go_password"
SMTP_FROM_EMAIL="root@yourdomain.com"  # Replace with your verified sender email

# Fail2ban Configuration
BANTIME="1h"
FINDTIME="30m"
MAXRETRY=3

# Update and upgrade
sudo apt update && sudo apt upgrade -y

# Backup original sshd_config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Install fail2ban and postfix
sudo apt install fail2ban postfix libsasl2-modules mailutils -y

# Configure SSH
sudo sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i 's/^#LoginGraceTime 2m/LoginGraceTime 20/' /etc/ssh/sshd_config
sudo sed -i 's/^#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
sudo sed -i 's/^#MaxSessions 10/MaxSessions 5/' /etc/ssh/sshd_config
sudo sed -i 's/^#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sudo sed -i 's/^#ClientAliveInterval 0/ClientAliveInterval 60/' /etc/ssh/sshd_config
sudo sed -i 's/^#ClientAliveCountMax 3/ClientAliveCountMax 3/' /etc/ssh/sshd_config
sudo sed -i 's/^#IgnoreRhosts yes/IgnoreRhosts yes/' /etc/ssh/sshd_config
sudo sed -i 's/^X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
sudo sed -i 's/^#AllowAgentForwarding yes/AllowAgentForwarding no/' /etc/ssh/sshd_config
sudo sed -i 's/^#AllowTcpForwarding yes/AllowTcpForwarding no/' /etc/ssh/sshd_config
sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Add AllowUsers directive
echo "AllowUsers $ALLOWED_USERS" | sudo tee -a /etc/ssh/sshd_config

# Configure Fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo cp /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local

# Configure jail.local
sudo sed -i "s/bantime  = 10m/bantime  = $BANTIME/" /etc/fail2ban/jail.local
sudo sed -i "s/findtime  = 10m/findtime  = $FINDTIME/" /etc/fail2ban/jail.local
sudo sed -i "s/maxretry = 5/maxretry = $MAXRETRY/" /etc/fail2ban/jail.local

# Set default action to include logging
sudo sed -i 's/action = %(action_)s/action = %(action_mwl)s/' /etc/fail2ban/jail.local

# Ensure sshd jail is enabled
echo "[sshd]
enabled = true
port = $SSH_PORT
logpath = %(sshd_log)s
backend = %(sshd_backend)s" | sudo tee -a /etc/fail2ban/jail.local

# Configure Postfix for SMTP relay
sudo sed -i "s/^relayhost =.*/relayhost = $SMTP_SERVER:$SMTP_PORT/" /etc/postfix/main.cf
echo "
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = static:$SMTP_USERNAME:$SMTP_PASSWORD
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = may
header_size_limit = 4096000
relay_destination_concurrency_limit = 20" | sudo tee -a /etc/postfix/main.cf

# Configure firewall
sudo apt install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow $SSH_PORT/tcp
sudo ufw enable

# Verify sshd_config syntax
sudo sshd -t

# Reload SSH service
sudo systemctl reload ssh

# Restart Postfix
sudo systemctl restart postfix

# Start and enable Fail2ban
sudo systemctl start fail2ban
sudo systemctl enable fail2ban

# Send a test email
echo "This is a test email from your hardened server." | mail -s "Server Hardening Complete" $ALERT_EMAIL

echo "Server hardening complete. Please review changes and ensure you can still access the server."
echo "Remember to use 'ssh -p $SSH_PORT username@server_ip' to connect after this change."
echo "Fail2ban is now active and monitoring SSH access attempts."
echo "A test email has been sent to $ALERT_EMAIL. Please check your inbox (and spam folder) to confirm email functionality."