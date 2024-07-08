OpenCart Server Setup Script

This repository contains a setup script for configuring an OpenCart server with Apache, PHP-FPM, Varnish, and Redis on Ubuntu. This script installs and configures all necessary components to create a high-performance, secure server environment.

Prerequisites

- Ubuntu Server
- Access to the server via SSH
- Root or sudo privileges

Usage

Clone the Repository

First, clone this repository to your server:

git clone https://your-git-repo-url.git
cd your-git-repo-name

Run the Setup Script

Run the setup script with your domain name and admin email as arguments:

chmod +x setup_apache_php.sh
sudo ./setup_apache_php.sh yourdomain.com admin@yourdomain.com

Replace yourdomain.com with your actual domain name and admin@yourdomain.com with your admin email address.

Script Details

Components Installed

- Apache2
- PHP-FPM 8.0 and necessary PHP modules
- Varnish Cache
- Redis Server

Configuration

- Apache2: Configured to handle HTTP (port 80) and HTTPS (port 443) traffic.
- PHP-FPM: Configured for optimal performance with OpenCart.
- Varnish: Configured to listen on port 8080 and proxy requests to Apache.
- Redis: Installed and configured to use the default port.

Self-Signed SSL Certificate

The script creates a self-signed SSL certificate for Apache to use for HTTPS connections. This can be replaced with a certificate from a trusted Certificate Authority (CA) if required.

Directory Permissions

The script sets the correct permissions for the web root directory /var/www/html.

Example

sudo ./setup_apache_php.sh example.com admin@example.com

This command will set up the server for example.com with admin@example.com as the admin email.

Notes

- Ensure that no other services are using the ports required by Apache and Varnish before running the script.
- Modify the script if you need to customize any settings.

License

This project is licensed under the MIT License - see the LICENSE file for details.
