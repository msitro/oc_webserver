#!/bin/bash

# Variables
SERVER_NAME=$1
SERVER_ALIAS=$2
DOC_ROOT="/var/www/html"

if [[ -z "$SERVER_NAME" || -z "$SERVER_ALIAS" ]]; then
  echo "Usage: $0 <server_name> <server_alias>"
  exit 1
fi

# Update and upgrade system
if ! sudo apt update && sudo apt upgrade -y; then
  echo "System update and upgrade failed."
  exit 1
fi

# Install PHP 8.0 and extensions
if ! sudo apt install -y net-tools software-properties-common; then
  echo "Failed to install prerequisites."
  exit 1
fi

if ! sudo add-apt-repository ppa:ondrej/php -y; then
  echo "Failed to add PHP repository."
  exit 1
fi

if ! sudo apt update; then
  echo "Failed to update after adding PHP repository."
  exit 1
fi

if ! sudo apt install -y php8.0 php8.0-fpm php8.0-mysql php8.0-zip php8.0-xml php8.0-gd php8.0-curl php8.0-mbstring php8.0-bcmath php8.0-intl php8.0-soap; then
  echo "Failed to install PHP and extensions."
  exit 1
fi

# Install Apache
if ! sudo apt install -y apache2 libapache2-mod-fcgid; then
  echo "Failed to install Apache."
  exit 1
fi

if ! sudo a2enmod actions fcgid alias proxy_fcgi rewrite headers expires; then
  echo "Failed to enable Apache modules."
  exit 1
fi

# Configure Apache Virtual Host
if ! sudo tee /etc/apache2/sites-available/opencart.conf > /dev/null <<EOL
<VirtualHost *:8080>
  ServerAdmin support@${SERVER_NAME}
  ServerName ${SERVER_NAME}
  ServerAlias ${SERVER_ALIAS}
  DocumentRoot ${DOC_ROOT}

  <Directory ${DOC_ROOT}>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
  </Directory>

  ErrorLog \${APACHE_LOG_DIR}/error.log
  CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL
then
  echo "Failed to configure Apache virtual host."
  exit 1
fi

# Enable site and restart Apache
if ! sudo a2ensite opencart.conf; then
  echo "Failed to enable site."
  exit 1
fi

if ! sudo systemctl restart apache2; then
  echo "Failed to restart Apache."
  exit 1
fi

# Configure PHP settings
PHP_INI=/etc/php/8.0/fpm/php.ini

if ! sudo sed -i 's/^upload_max_filesize.*/upload_max_filesize = 64M/' $PHP_INI ||
   ! sudo sed -i 's/^post_max_size.*/post_max_size = 64M/' $PHP_INI ||
   ! sudo sed -i 's/^memory_limit.*/memory_limit = 256M/' $PHP_INI ||
   ! sudo sed -i 's/^max_execution_time.*/max_execution_time = 300/' $PHP_INI ||
   ! sudo sed -i 's/^max_input_vars.*/max_input_vars = 5000/' $PHP_INI; then
  echo "Failed to configure PHP settings."
  exit 1
fi

# Restart PHP service
if ! sudo systemctl restart php8.0-fpm; then
  echo "Failed to restart PHP-FPM."
  exit 1
fi

echo "Web server setup completed successfully."
