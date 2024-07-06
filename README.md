OpenCart Web Server Setup Script

This script sets up a highly optimized and secure web server environment for running OpenCart 3.0.3.8 on Ubuntu 24.04 with PHP 8.0. It includes configurations for Apache, PHP-FPM, Varnish, Redis, and connects to a Galera Cluster behind pfSense HAProxy.

Components

- Operating System: Ubuntu 24.04
- Web Server: Apache
- PHP Version: 8.0
- Caching: Varnish, Redis
- E-commerce Platform: OpenCart 3.0.3.8
- Database: Galera Cluster behind pfSense HAProxy

Requirements

- Ubuntu 24.04 server
- Proxmox VM (if applicable)
- Access to Galera Cluster behind pfSense HAProxy

Installation Steps

1. Download the Script

Clone this repository to your server:

git clone https://github.com/msitro/oc_webserver.git
cd oc_webserver/

2. Run the Script

Make the script executable:

chmod +x setup_opencart_server.sh

Run the script with necessary parameters:

sudo ./setup_opencart_server.sh <SERVER_NAME> <SERVER_ALIAS>

- <SERVER_NAME>: The server name for your Apache configuration.
- <SERVER_ALIAS>: The server alias for your Apache configuration.

3. Verify the Setup

After the script completes, verify the installation:

- Check Apache status: sudo systemctl status apache2
- Check PHP-FPM status: sudo systemctl status php8.0-fpm
- Check Varnish status: sudo systemctl status varnish
- Check Redis status: sudo systemctl status redis-server

4. Database Configuration

Ensure that your OpenCart installation can connect to the Galera Cluster behind pfSense HAProxy. Update the OpenCart configuration files with the database connection details.

Script Overview

Apache Configuration

- Enables necessary modules.
- Sets up a virtual host configuration with optimized caching headers.

PHP Configuration

- Installs PHP 8.0 with necessary extensions.
- Configures php.ini with optimized settings for performance.

Varnish Configuration

- Installs Varnish and configures it to work with Apache.
- Sets up caching rules and backend definitions.

Redis Configuration

- Installs Redis for session and cache storage.
- Configures Redis to work with OpenCart.

Customization

You can modify the script to fit your specific requirements. The script includes comments and variables for easy customization.

Backup

Before making changes, the script backs up existing configuration files:

- php.ini is backed up to /etc/php/8.0/fpm/php.ini.bak
- Apache virtual host files are backed up to /etc/apache2/sites-available/<SERVER_NAME>.conf.bak

Contributing

If you find any issues or have suggestions for improvements, feel free to open an issue or submit a pull request.

License

This project is licensed under the MIT License. See the LICENSE file for details.
