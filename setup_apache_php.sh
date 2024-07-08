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
apt install -y apache2 libapache2-mod-fcgid php8.0-fpm php8.0 php8.0-common php8.0-mysql php8.0-xml php8.0-curl php8.0-gd php8.0-mbstring php8.0-zip php8.0-bcmath php8.0-intl php8.0-opcache php8.0-bz2 php8.0-dba php8.0-enchant php8.0-imap php8.0-ldap php8.0-msgpack php8.0-odbc php8.0-readline php8.0-snmp php8.0-soap php8.0-sqlite3 php8.0-tidy php8.0-xsl php8.0-redis redis-server

# Install Varnish
apt install -y varnish

# Update Varnish to listen on port 8080
sed -i '/ExecStart/d' /lib/systemd/system/varnish.service
sed -i '/\[Service\]/a ExecStart=/usr/sbin/varnishd -j unix,user=vcache -F -a :8080 -T localhost:6082 -f /etc/varnish/default.vcl -S /etc/varnish/secret -s malloc,256m' /lib/systemd/system/varnish.service

# Reload systemd to apply changes
systemctl daemon-reload

# Restart Varnish to apply changes
systemctl restart varnish

# Enable necessary Apache2 modules
a2enmod actions fcgid alias proxy_fcgi rewrite ssl headers proxy proxy_http

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
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json
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
        Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    </IfModule>
</VirtualHost>
EOT

# Create self-signed certificate for Apache SSL
mkdir -p /etc/apache2/ssl
openssl req -new -x509 -days 365 -nodes -out /etc/apache2/ssl/apache.crt -keyout /etc/apache2/ssl/apache.key -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=${DOMAIN_NAME}"

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

# PHP Configuration
cat <<EOT > /etc/php/8.0/fpm/php.ini
[PHP]
engine = On
short_open_tag = Off
precision = 14
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
unserialize_callback_func =
serialize_precision = -1
disable_functions =
disable_classes =
zend.enable_gc = On
expose_php = Off
max_execution_time = 30
max_input_time = 60
memory_limit = 256M
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
display_startup_errors = Off
log_errors = On
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
html_errors = Off
variables_order = "GPCS"
request_order = "GP"
register_argc_argv = Off
auto_globals_jit = On
post_max_size = 32M
auto_prepend_file =
auto_append_file =
default_mimetype = "text/html"
default_charset = "UTF-8"
doc_root =
user_dir =
enable_dl = Off
file_uploads = On
upload_max_filesize = 32M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60
[CLI Server]
cli_server.color = On
[Date]
date.timezone = UTC
[filter]
[iconv]
[intl]
[sqlite3]
[Pcre]
pcre.backtrack_limit = 1000000
pcre.recursion_limit = 100000
[Pdo]
pdo_odbc.connection_pooling = strict
[Phar]
phar.readonly = On
phar.require_hash = On
[mail function]
SMTP = localhost
smtp_port = 25
mail.add_x_header = Off
[SQL]
sql.safe_mode = Off
[ODBC]
odbc.allow_persistent = On
odbc.check_persistent = On
odbc.max_persistent = -1
odbc.max_links = -1
odbc.defaultlrl = 4096
odbc.defaultbinmode = 1
[Interbase]
ibase.allow_persistent = 1
ibase.max_persistent = -1
ibase.max_links = -1
ibase.timestampformat = "%Y-%m-%d %H:%M:%S"
ibase.dateformat = "%Y-%m-%d"
ibase.timeformat = "%H:%M:%S"
[MySQL]
mysql.allow_local_infile = On
mysql.allow_persistent = On
mysql.cache_size = 2000
mysql.max_persistent = -1
mysql.max_links = -1
mysql.default_port =
mysql.default_socket =
mysql.default_host =
mysql.default_user =
mysql.default_password =
mysql.connect_timeout = 60
mysql.trace_mode = Off
[mysqli]
mysqli.max_persistent = -1
mysqli.allow_persistent = On
mysqli.max_links = -1
mysqli.cache_size = 2000
mysqli.default_port = 3306
mysqli.default_socket =
mysqli.default_host =
mysqli.default_user =
mysqli.default_pw =
mysqli.reconnect = Off
[mysqlnd]
mysqlnd.collect_statistics = On
mysqlnd.collect_memory_statistics = Off
[OCI8]
oci8.privileged_connect = Off
oci8.max_persistent = -1
oci8.persistent_timeout = -1
oci8.ping_interval = 60
oci8.connection_class =
oci8.events = Off
oci8.statement_cache_size = 20
[PostgreSQL]
pgsql.allow_persistent = On
pgsql.auto_reset_persistent = Off
pgsql.max_persistent = -1
pgsql.max_links = -1
pgsql.ignore_notice = 0
pgsql.log_notice = 0
[bcmath]
bcmath.scale = 0
[browscap]
[Session]
session.save_handler = files
session.save_path = "/var/lib/php/sessions"
session.use_strict_mode = 0
session.use_cookies = 1
session.use_only_cookies = 1
session.name = PHPSESSID
session.auto_start = 0
session.cookie_lifetime = 0
session.cookie_path = /
session.cookie_domain =
session.cookie_httponly =
session.cookie_samesite =
session.serialize_handler = php
session.gc_probability = 1
session.gc_divisor = 1000
session.gc_maxlifetime = 1440
session.referer_check =
session.cache_limiter = nocache
session.cache_expire = 180
session.use_trans_sid = 0
session.sid_length = 26
session.trans_sid_tags = "a=href,area=href,frame=src,form="
session.sid_bits_per_character = 5
[Assertion]
zend.assertions = -1
[COM]
[mbstring]
[gd]
[exif]
[Tidy]
[soap]
[sysvshm]
[ldap]
[opcache]
[curl]
[openssl]
[redis]
EOT

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
