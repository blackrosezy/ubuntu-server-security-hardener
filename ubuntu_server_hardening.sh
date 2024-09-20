#!/bin/bash

# Ubuntu 24.04 LTS Server Hardening Script with Fail2ban and SMTP Configuration
# This script is designed to be safe to run multiple times

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
SMTP_PORT="465"  # Can be changed to 587 if needed
SMTP_USERNAME="your_smtp2go_username"
SMTP_PASSWORD="your_smtp2go_password"
SMTP_FROM_EMAIL="root@yourdomain.com"  # Replace with your verified sender email

# Fail2ban Configuration
BANTIME="1h"
FINDTIME="30m"
MAXRETRY=3

# Update and upgrade
sudo apt update && sudo apt upgrade -y

# Backup original sshd_config if not already done
if [ ! -f /etc/ssh/sshd_config.bak ]; then
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
fi

# Install fail2ban and postfix if not already installed
sudo apt install fail2ban postfix libsasl2-modules mailutils -y

# Configure SSH
sudo sed -i "s/^#*Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i 's/^#*LoginGraceTime .*/LoginGraceTime 20/' /etc/ssh/sshd_config
sudo sed -i 's/^#*MaxAuthTries .*/MaxAuthTries 3/' /etc/ssh/sshd_config
sudo sed -i 's/^#*MaxSessions .*/MaxSessions 5/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitEmptyPasswords .*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*ClientAliveInterval .*/ClientAliveInterval 60/' /etc/ssh/sshd_config
sudo sed -i 's/^#*ClientAliveCountMax .*/ClientAliveCountMax 3/' /etc/ssh/sshd_config
sudo sed -i 's/^#*IgnoreRhosts .*/IgnoreRhosts yes/' /etc/ssh/sshd_config
sudo sed -i 's/^X11Forwarding .*/X11Forwarding no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*AllowAgentForwarding .*/AllowAgentForwarding no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*AllowTcpForwarding .*/AllowTcpForwarding no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config

# Add or update AllowUsers directive
if grep -q "^AllowUsers" /etc/ssh/sshd_config; then
    sudo sed -i "s/^AllowUsers .*/AllowUsers $ALLOWED_USERS/" /etc/ssh/sshd_config
else
    echo "AllowUsers $ALLOWED_USERS" | sudo tee -a /etc/ssh/sshd_config
fi

# Configure Fail2ban
sudo cp -n /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo cp -n /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local

# Configure jail.local
sudo sed -i "s/^bantime  = .*/bantime  = $BANTIME/" /etc/fail2ban/jail.local
sudo sed -i "s/^findtime  = .*/findtime  = $FINDTIME/" /etc/fail2ban/jail.local
sudo sed -i "s/^maxretry = .*/maxretry = $MAXRETRY/" /etc/fail2ban/jail.local

# Set default action to include logging
sudo sed -i 's/^action = %(action_)s/action = %(action_mwl)s/' /etc/fail2ban/jail.local

# Ensure sshd jail is enabled and configured
if ! grep -q "\[sshd\]" /etc/fail2ban/jail.local; then
    echo "
[sshd]
enabled = true
port = $SSH_PORT
logpath = %(sshd_log)s
backend = %(sshd_backend)s" | sudo tee -a /etc/fail2ban/jail.local
else
    sudo sed -i "/\[sshd\]/,/^$/c\
[sshd]\n\
enabled = true\n\
port = $SSH_PORT\n\
logpath = %(sshd_log)s\n\
backend = %(sshd_backend)s" /etc/fail2ban/jail.local
fi

# Configure Postfix for SMTP relay
sudo sed -i "s/^relayhost =.*/relayhost = [$SMTP_SERVER]:$SMTP_PORT/" /etc/postfix/main.cf
sudo sed -i '/smtp_sasl_auth_enable/d' /etc/postfix/main.cf
sudo sed -i '/smtp_sasl_password_maps/d' /etc/postfix/main.cf
sudo sed -i '/smtp_sasl_security_options/d' /etc/postfix/main.cf
sudo sed -i '/smtp_tls_security_level/d' /etc/postfix/main.cf
sudo sed -i '/smtp_tls_wrappermode/d' /etc/postfix/main.cf
sudo sed -i '/header_size_limit/d' /etc/postfix/main.cf
sudo sed -i '/relay_destination_concurrency_limit/d' /etc/postfix/main.cf

echo "
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = static:$SMTP_USERNAME:$SMTP_PASSWORD
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt" | sudo tee -a /etc/postfix/main.cf

# Configure TLS wrapper mode for port 465, or STARTTLS for port 587
if [ "$SMTP_PORT" = "465" ]; then
    echo "smtp_tls_wrappermode = yes" | sudo tee -a /etc/postfix/main.cf
fi

echo "
header_size_limit = 4096000
relay_destination_concurrency_limit = 20" | sudo tee -a /etc/postfix/main.cf

# Configure firewall
sudo apt install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow $SSH_PORT/tcp
sudo ufw allow 465/tcp
sudo ufw allow 587/tcp
sudo ufw --force enable

# Verify sshd_config syntax
sudo sshd -t

# Reload SSH service
sudo systemctl reload ssh

# Restart Postfix
sudo systemctl restart postfix

# Start and enable Fail2ban
sudo systemctl restart fail2ban
sudo systemctl enable fail2ban

# Send a test email
echo "This is a test email from your hardened server." | mail -s "Server Hardening Complete" $ALERT_EMAIL

echo "Server hardening complete. Please review changes and ensure you can still access the server."
echo "Remember to use 'ssh -p $SSH_PORT username@server_ip' to connect after this change."
echo "Fail2ban is now active and monitoring SSH access attempts."
echo "A test email has been sent to $ALERT_EMAIL. Please check your inbox (and spam folder) to confirm email functionality."
echo "Both SMTP ports 465 and 587 are now open. You can change the SMTP_PORT variable to use either."