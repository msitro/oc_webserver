#!/bin/bash

# Variables
DOMAIN_NAME=$1
ADMIN_EMAIL=$2

if [ -z "$DOMAIN_NAME" ] || [ -z "$ADMIN_EMAIL" ]; then
  echo "Usage: $0 <domain_name> <admin_email>"
  exit 1
fi

# Set non-interactive mode
export DEBIAN_FRONTEND=noninteractive

# Update system and install prerequisites
apt update && apt upgrade -y && apt install -y software-properties-common curl

# Add PHP repository
add-apt-repository ppa:ondrej/php -y && apt update

# Install Apache2, PHP-FPM 8.0, Varnish, Redis, and required PHP modules
apt install -y apache2 libapache2-mod-fcgid php8.0-fpm php8.0 php8.0-common php8                                                                                                                                                             .0-mysql php8.0-xml php8.0-curl php8.0-gd php8.0-mbstring php8.0-zip php8.0-bcma                                                                                                                                                             th php8.0-intl php8.0-opcache php8.0-bz2 php8.0-dba php8.0-enchant php8.0-imap p                                                                                                                                                             hp8.0-ldap php8.0-msgpack php8.0-odbc php8.0-readline php8.0-snmp php8.0-soap ph                                                                                                                                                             p8.0-sqlite3 php8.0-tidy php8.0-xsl php8.0-redis redis-server

# Install Varnish
apt install -y varnish

# Update Varnish to listen on port 8080
sed -i '/ExecStart/d' /lib/systemd/system/varnish.service
sed -i '/\[Service\]/a ExecStart=/usr/sbin/varnishd -j unix,user=vcache -F -a :8                                                                                                                                                             080 -T localhost:6082 -f /etc/varnish/default.vcl -S /etc/varnish/secret -s mall                                                                                                                                                             oc,256m' /lib/systemd/system/varnish.service

# Reload systemd to apply changes
systemctl daemon-reload

# Restart Varnish to apply changes
systemctl restart varnish

# Enable necessary Apache2 modules
a2enmod actions fcgid alias proxy_fcgi rewrite ssl headers proxy proxy_http defl                                                                                                                                                             ate expires

# Configure Apache2 for PHP-FPM, Varnish, and Redis
cat <<EOT > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin ${ADMIN_EMAIL}
    ServerName ${DOMAIN_NAME}
    ServerAlias www.${DOMAIN_NAME}
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    <FilesMatch "\.php$">
        SetHandler "proxy:unix:/run/php/php8.0-fpm.sock|fcgi://localhost/"
    </FilesMatch>
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined

    # Varnish Configuration
    <Proxy "http://127.0.0.1:8080">
        Allow from all
    </Proxy>
    ProxyPass / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/

    # Redis Configuration
    <IfModule mod_rewrite.c>
        RewriteEngine On
        RewriteCond %{HTTP:Authorization} ^(.*)
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%1]
    </IfModule>

    # Compression
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css tex                                                                                                                                                             t/javascript application/javascript application/json
    </IfModule>

    # Caching
    <IfModule mod_expires.c>
        ExpiresActive On
        ExpiresByType image/jpg "access plus 1 year"
        ExpiresByType image/jpeg "access plus 1 year"
        ExpiresByType image/gif "access plus 1 year"
        ExpiresByType image/png "access plus 1 year"
        ExpiresByType text/css "access plus 1 month"
        ExpiresByType application/pdf "access plus 1 month"
        ExpiresByType text/x-javascript "access plus 1 month"
        ExpiresByType application/x-shockwave-flash "access plus 1 month"
        ExpiresByType image/x-icon "access plus 1 year"
        ExpiresDefault "access plus 2 days"
    </IfModule>

    # Security Headers
    <IfModule mod_headers.c>
        Header always set X-Content-Type-Options "nosniff"
        Header always set X-Frame-Options "DENY"
        Header always set X-XSS-Protection "1; mode=block"
        Header always set Strict-Transport-Security "max-age=31536000; includeSu                                                                                                                                                             bDomains"
    </IfModule>
</VirtualHost>
EOT

# Create self-signed certificate for Apache SSL
mkdir -p /etc/apache2/ssl
openssl req -new -x509 -days 365 -nodes -out /etc/apache2/ssl/apache.crt -keyout                                                                                                                                                              /etc/apache2/ssl/apache.key -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=${DOM                                                                                                                                                             AIN_NAME}"

# Create Apache SSL configuration
cat <<EOT > /etc/apache2/sites-available/default-ssl.conf
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerAdmin ${ADMIN_EMAIL}
    ServerName ${DOMAIN_NAME}
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/apache.crt
    SSLCertificateKeyFile /etc/apache2/ssl/apache.key
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined

    # Varnish Configuration
    <Proxy "http://127.0.0.1:8080">
        Allow from all
    </Proxy>
    ProxyPass / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/

    # Redis Configuration
    <IfModule mod_rewrite.c>
        RewriteEngine On
        RewriteCond %{HTTP:Authorization} ^(.*)
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%1]
    </IfModule>

    # Compression
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css tex                                                                                                                                                             t/javascript application/javascript application/json
    </IfModule>

    # Caching
    <IfModule mod_expires.c>
        ExpiresActive On
        ExpiresByType image/jpg "access plus 1 year"
        ExpiresByType image/jpeg "access plus 1 year"
        ExpiresByType image/gif "access plus 1 year"
        ExpiresByType image/png "access plus 1 year"
        ExpiresByType text/css "access plus 1 month"
        ExpiresByType application/pdf "access plus 1 month"
        ExpiresByType text/x-javascript "access plus 1 month"
        ExpiresByType application/x-shockwave-flash "access plus 1 month"
        ExpiresByType image/x-icon "access plus 1 year"
        ExpiresDefault "access plus 2 days"
    </IfModule>

    # Security Headers
    <IfModule mod_headers.c>
        Header always set X-Content-Type-Options "nosniff"
        Header always set X-Frame-Options "DENY"
        Header always set X-XSS-Protection "1; mode=block"
        Header always set Strict-Transport-Security "max-age=31536000; includeSu                                                                                                                                                             bDomains"
    </IfModule>
</VirtualHost>
</IfModule>
EOT

# Enable SSL site configuration and restart Apache
a2ensite default-ssl
systemctl reload apache2

# Configure Varnish to forward requests to Apache on port 80
cat <<EOT > /etc/varnish/default.vcl
vcl 4.0;
backend default {
    .host = "127.0.0.1";
    .port = "80";
}
EOT

# Update apache ServerName parameter
echo "ServerName ${DOMAIN_NAME}" >> /etc/apache2/apache2.conf

# Reload systemd to apply changes
systemctl daemon-reload

# Restart services to apply changes
systemctl restart apache2
systemctl restart php8.0-fpm
systemctl restart varnish
systemctl restart redis-server

# Ensure services are enabled to start on boot
systemctl enable apache2
systemctl enable php8.0-fpm
systemctl enable varnish
systemctl enable redis-server

# Setup permissions for web root directory
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

echo "Setup completed!"
