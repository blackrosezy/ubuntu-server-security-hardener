# Ubuntu Server Security Hardener

This repository contains a comprehensive script for hardening Ubuntu servers. It enhances server security by configuring SSH and setting up Fail2ban.

## Features

- Secures SSH configuration
- Sets up Fail2ban to protect against brute-force attacks
- Installs and configures UFW (Uncomplicated Firewall)
- Provides instructions for creating a sudo user and enabling additional ports

## Prerequisites

- Ubuntu 24.04 LTS server (may work on other Ubuntu versions, but not tested)
- Root or sudo access to the server
- Basic knowledge of Linux command line and server administration

## Usage

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/ubuntu-server-security-hardener.git
   ```

2. Navigate to the repository directory:
   ```
   cd ubuntu-server-security-hardener
   ```

3. Edit the `ubuntu_server_hardening.sh` script to customize variables such as SSH port, allowed users, and SMTP settings.

4. Make the script executable:
   ```
   chmod +x ubuntu_server_hardening.sh
   ```

5. Run the script with sudo privileges:
   ```
   sudo ./ubuntu_server_hardening.sh
   ```

## Important Notes

- Create a sudo user and set up SSH key authentication before running the script.
- Review and modify the UFW rules in the script if you need to open additional ports (e.g., for web servers).
- Always test this script in a safe environment before using it on a production server.

## Contributing

Contributions to improve the script or documentation are welcome. Please feel free to submit a pull request or open an issue.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This script is provided as-is, without any warranty. Use it at your own risk. Always ensure you understand the changes being made to your system and have proper backups before running security scripts.
